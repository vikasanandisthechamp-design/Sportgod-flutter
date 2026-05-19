import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class Throttle {
  final Duration cooldown;
  DateTime? _lastCall;

  Throttle({this.cooldown = const Duration(seconds: 1)});

  bool call(void Function() action) {
    final now = DateTime.now();
    if (_lastCall != null && now.difference(_lastCall!) < cooldown) {
      return false;
    }
    _lastCall = now;
    action();
    return true;
  }
}
