import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Opens Razorpay Checkout.js (https://checkout.razorpay.com/v1/checkout.js)
/// in the browser. Only used for web builds — mobile uses the native
/// `razorpay_flutter` plugin via `Razorpay.open()`.
Future<void> openRazorpayCheckoutWeb({
  required Map<String, dynamic> options,
  required void Function(PaymentSuccessResponse) onSuccess,
  required void Function(PaymentFailureResponse) onError,
}) async {
  final checkout = globalContext['RazorpayCheckout'];
  if (checkout == null) {
    throw StateError('Razorpay Checkout.js is not loaded.');
  }
  final razorpayCheckout = checkout as JSObject;

  final onSuccessJs = ((JSAny response) {
    onSuccess(PaymentSuccessResponse.fromMap(_jsObjectToMap(response as JSObject)));
  }).toJS;

  final onErrorJs = ((JSAny response) {
    final map = _jsObjectToMap(response as JSObject);
    final code = map['code'];
    final description = map['description'];
    final isCancelled = code != null &&
        code.toString().toUpperCase().contains('CANCELLED');
    onError(PaymentFailureResponse(
      isCancelled ? Razorpay.PAYMENT_CANCELLED : 1,
      description as String?,
      null,
    ));
  }).toJS;

  razorpayCheckout.callMethod<JSAny?>('open'.toJS, _mapToJs(options), onSuccessJs, onErrorJs);
}

JSObject _mapToJs(Map<String, dynamic> map) {
  final obj = JSObject();
  for (final entry in map.entries) {
    final value = entry.value;
    if (value is Map) {
      obj.setProperty(entry.key.toJS, _mapToJs(Map<String, dynamic>.from(value)));
    } else if (value is String) {
      obj.setProperty(entry.key.toJS, value.toJS);
    } else if (value is num) {
      obj.setProperty(entry.key.toJS, value.toJS);
    } else if (value is bool) {
      obj.setProperty(entry.key.toJS, value.toJS);
    } else if (value != null) {
      obj.setProperty(entry.key.toJS, value.toString().toJS);
    }
  }
  return obj;
}

Map<String, dynamic> _jsObjectToMap(JSObject obj) {
  const knownKeys = [
    'razorpay_payment_id',
    'razorpay_order_id',
    'razorpay_signature',
    'code',
    'description',
    'reason',
    'source',
  ];
  final map = <String, dynamic>{};
  for (final key in knownKeys) {
    final value = obj.getProperty<JSAny?>(key.toJS);
    if (value != null) {
      map[key] = value.dartify();
    }
  }
  return map;
}
