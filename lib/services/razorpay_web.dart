import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_stub.dart'
    if (dart.library.js_interop) 'razorpay_web_impl.dart' as impl;

/// Opens Razorpay Checkout.js in the browser. Only called on web builds —
/// mobile uses the native `razorpay_flutter` plugin via `Razorpay.open()`.
Future<void> openRazorpayCheckoutWeb({
  required Map<String, dynamic> options,
  required void Function(PaymentSuccessResponse) onSuccess,
  required void Function(PaymentFailureResponse) onError,
}) =>
    impl.openRazorpayCheckoutWeb(
      options: options,
      onSuccess: onSuccess,
      onError: onError,
    );
