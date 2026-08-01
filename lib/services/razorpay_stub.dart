import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Mobile/VM placeholder — never invoked (event_detail_screen only calls this
/// on web). Exists so `dart:js_interop` never leaks into non-web builds.
Future<void> openRazorpayCheckoutWeb({
  required Map<String, dynamic> options,
  required void Function(PaymentSuccessResponse) onSuccess,
  required void Function(PaymentFailureResponse) onError,
}) {
  throw UnsupportedError('Razorpay web checkout is only available on web.');
}
