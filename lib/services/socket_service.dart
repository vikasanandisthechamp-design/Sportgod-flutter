import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/cricket_models.dart';

const _wsBaseUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'wss://sportgod-backend-production.up.railway.app',
);

enum SocketState { connecting, connected, disconnected, error }

class SocketService {
  WebSocketChannel?          _channel;
  StreamSubscription?        _sub;
  Timer?                     _reconnectTimer;
  Timer?                     _pingTimer;
  int                        _reconnectCount = 0;
  // No _maxReconnect cap — Railway kills WebSocket connections unpredictably
  // during deploys and under load.  A match lasts 6+ hours; we must reconnect
  // for the entire duration.  The 60s ceiling ensures we never go dark for
  // more than one minute regardless of how many failures have occurred.
  bool _disposed = false;

  final String matchId;

  final _ballController      = StreamController<BallEvent>.broadcast();
  final _matchController     = StreamController<CricketMatch>.broadcast();
  final _stateController     = StreamController<SocketState>.broadcast();
  final _snapshotController  = StreamController<Map<String, dynamic>>.broadcast();
  // New streams for server-push updates
  final _scorecardController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentaryController = StreamController<List<BallEvent>>.broadcast();

  Stream<BallEvent>               get ballStream      => _ballController.stream;
  Stream<CricketMatch>            get matchStream     => _matchController.stream;
  Stream<SocketState>             get stateStream     => _stateController.stream;
  Stream<Map<String, dynamic>>    get snapshotStream  => _snapshotController.stream;
  /// Emits updated scorecard data whenever backend pushes `scorecard_update`
  Stream<Map<String, dynamic>>    get scorecardStream => _scorecardController.stream;
  /// Emits a batch of ball events on `commentary_history` (e.g. after reconnect)
  Stream<List<BallEvent>>         get commentaryStream => _commentaryController.stream;

  SocketService(this.matchId);

  void connect() {
    if (_disposed) return;
    _stateController.add(SocketState.connecting);

    try {
      final uri = Uri.parse('$_wsBaseUrl/ws/matches/$matchId');
      _channel = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
      );

      _stateController.add(SocketState.connected);
      _reconnectCount = 0;

      // Keep-alive ping every 25s
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _channel?.sink.add(json.encode({'type': 'pong'}));
        } catch (_) {}
      });
    } catch (e) {
      _stateController.add(SocketState.error);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final msg = json.decode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';

      switch (type) {
        case 'snapshot':
          _snapshotController.add(msg);

        case 'ball_event':
          _ballController.add(BallEvent.fromJson(msg));

        // Backend broadcasts full scorecard on every wicket / over / score change.
        // Field is nested under 'scorecard' or directly in msg.
        case 'scorecard_update':
          final payload = (msg['scorecard'] as Map<String, dynamic>?) ?? msg;
          _scorecardController.add(payload);

        // Sent after reconnect or when the client requests history.
        // Contains an array of ball events under 'commentary' or 'balls'.
        case 'commentary_history':
          final raw = (msg['commentary'] ?? msg['balls'] ?? []) as List;
          try {
            final balls = raw
                .map((b) => BallEvent.fromJson(b as Map<String, dynamic>))
                .toList();
            if (balls.isNotEmpty) _commentaryController.add(balls);
          } catch (_) {}

        case 'ping':
          _channel?.sink.add(json.encode({'type': 'pong'}));

        // Unknown types: ignore silently — forward compatibility
        default:
          break;
      }
    } catch (_) {
      // Malformed message — ignore silently
    }
  }

  void _onError(dynamic error) {
    if (_disposed) return;
    _stateController.add(SocketState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    if (_disposed) return;
    _stateController.add(SocketState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    // Only stop if the service has been explicitly disposed — never on count alone.
    if (_disposed) return;

    // Exponential backoff: 1s → 2s → 4s → 8s → 16s → 32s → 60s (then forever at 60s).
    // Clamp the exponent at 6 to avoid integer overflow (2^6 = 64 > 60).
    final expSeconds = 1 << _reconnectCount.clamp(0, 6);   // 1,2,4,8,16,32,64
    final delaySecs  = expSeconds.clamp(1, 60);             // cap at 60s
    _reconnectCount++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySecs), connect);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    try { _channel?.sink.close(); } catch (_) {}
    _ballController.close();
    _matchController.close();
    _stateController.close();
    _snapshotController.close();
    _scorecardController.close();
    _commentaryController.close();
  }
}
