import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/env_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Premium upgrade screen with Razorpay payment.
///
/// SETUP REQUIRED (founder):
///   1. Get Razorpay Key ID from dashboard.razorpay.com
///   2. Add to .env: RAZORPAY_KEY_ID=rzp_live_...
///   3. For live payments: complete KYC at razorpay.com/activate
///   4. Backend webhook: set RAZORPAY_KEY_SECRET in Railway env vars
///
/// Current price: ₹299/year (₹149 with influencer coupon)
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const String _razorpayKeyId = Env.razorpayKeyId;

  late Razorpay _razorpay;
  final _api = ApiService();
  final _couponCtrl = TextEditingController();

  bool _loading = false;
  bool _couponLoading = false;
  int _finalPrice = 299;
  String? _couponMsg;
  String? _error;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _couponLoading = true; _couponMsg = null; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final result = await _api.validateCoupon(code, auth.accessToken);
      if (result['valid'] == true) {
        final discount = (result['discount_percent'] as num?)?.toInt() ?? 50;
        final newPrice = (299 * (100 - discount) ~/ 100);
        setState(() {
          _finalPrice = newPrice;
          _couponMsg = '✓ Coupon applied! You save ₹${299 - newPrice}';
        });
      } else {
        setState(() => _error = result['message'] as String? ?? 'Invalid coupon code');
      }
    } catch (e) {
      setState(() => _error = 'Could not validate coupon. Try again.');
    } finally {
      setState(() => _couponLoading = false);
    }
  }

  Future<void> _startPayment() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    setState(() { _loading = true; _error = null; });
    try {
      // Create order on backend → get Razorpay order ID
      final order = await _api.createPremiumOrder(
        amount: _finalPrice * 100,  // paise
        accessToken: auth.accessToken,
      );
      final orderId = order['id'] as String?;
      if (orderId == null) throw Exception('Order creation failed');

      final options = {
        'key': _razorpayKeyId,
        'amount': _finalPrice * 100,
        'name': 'SportGod AI',
        'description': 'Premium — 1 Year Subscription',
        'order_id': orderId,
        'prefill': {
          'email': auth.user?.email ?? '',
        },
        'theme': {'color': '#00E5A8'},
        'retry': {'enabled': false, 'max_count': 0},
      };
      _razorpay.open(options);
    } catch (e) {
      setState(() { _error = 'Could not initiate payment. Try again.'; _loading = false; });
    }
  }

  void _onSuccess(PaymentSuccessResponse res) async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      await _api.verifyPremiumPayment(
        paymentId: res.paymentId ?? '',
        orderId: res.orderId ?? '',
        signature: res.signature ?? '',
        accessToken: auth.accessToken,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Welcome to SportGod PRO! Enjoy unlimited access.'),
          backgroundColor: Color(0xFF00E5A8),
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Payment done but activation failed. Contact support.'; _loading = false; });
      }
    }
  }

  void _onError(PaymentFailureResponse res) {
    setState(() { _error = 'Payment cancelled or failed. Try again.'; _loading = false; });
  }

  void _onWallet(ExternalWalletResponse res) {
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C3CF7), Color(0xFF00C9FF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Text('⚡', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 10),
                  Text('SportGod PRO', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
                  )),
                ]),
                const SizedBox(height: 8),
                const Text('Everything you need to dominate cricket season', style: TextStyle(
                  fontSize: 13, color: Colors.white70,
                )),
                const SizedBox(height: 20),
                RichText(text: TextSpan(children: [
                  TextSpan(
                    text: '₹$_finalPrice',
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const TextSpan(text: '/year', style: TextStyle(fontSize: 14, color: Colors.white70)),
                ])),
                if (_finalPrice < 299) ...[
                  const SizedBox(height: 4),
                  const Text('Regular price ₹299/year', style: TextStyle(
                    fontSize: 12, color: Colors.white54, decoration: TextDecoration.lineThrough,
                  )),
                ],
              ]),
            ),

            const SizedBox(height: 20),

            // Feature list
            ..._features.map((f) => _FeatureRow(icon: f.$1, text: f.$2)),

            const SizedBox(height: 24),

            // Coupon input
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _couponCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Influencer / promo code',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _couponLoading ? null : _validateCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5A8).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF00E5A8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _couponLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Apply'),
              ),
            ]),

            if (_couponMsg != null) ...[
              const SizedBox(height: 8),
              Text(_couponMsg!, style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12)),
            ],

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],

            const SizedBox(height: 24),

            // Pay button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5A8),
                  foregroundColor: const Color(0xFF0F0F11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0F11)))
                  : Text(
                      'Pay ₹$_finalPrice with Razorpay',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Secure payment via Razorpay. Cancel anytime. '
              'By purchasing you agree to our Terms of Service.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static const _features = [
    (Icons.chat_bubble_outline_rounded, 'Unlimited AI cricket chat (SportsGPT)'),
    (Icons.analytics_outlined, 'Advanced predictions & win probability'),
    (Icons.emoji_events_outlined, 'Priority fantasy team insights'),
    (Icons.notifications_active_outlined, 'Real-time wicket & boundary alerts'),
    (Icons.bar_chart_rounded, 'Full match analytics & worm charts'),
    (Icons.workspace_premium_outlined, 'Early access to new features'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF00E5A8).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF00E5A8)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: SGColors.textPrimary))),
      ]),
    );
  }
}
