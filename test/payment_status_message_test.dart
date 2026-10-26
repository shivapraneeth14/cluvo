import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/event_detail_screen.dart';

void main() {
  group('paymentStatusMessage', () {
    test('never reports a captured payment as failed', () {
      final msg = paymentStatusMessage(
        status: 'success',
        failureReason: null,
        refundStatus: null,
      );
      expect(msg, isNot(contains('Payment failed')));
      expect(msg, contains('confirming'));
    });

    test('treats a pending payment as awaiting confirmation, not failure', () {
      final msg = paymentStatusMessage(
        status: 'pending',
        failureReason: null,
        refundStatus: null,
      );
      expect(msg, isNot(contains('Payment failed')));
      expect(msg, contains('not received confirmation'));
    });

    test('treats a missing payment row as awaiting confirmation', () {
      final msg = paymentStatusMessage(
        status: null,
        failureReason: null,
        refundStatus: null,
      );
      expect(msg, isNot(contains('Payment failed')));
    });

    test('surfaces refunded payments', () {
      final msg = paymentStatusMessage(
        status: 'refunded',
        failureReason: null,
        refundStatus: 'processed',
      );
      expect(msg, contains('refunded'));
    });

    test('explains an event cancellation while paying', () {
      final msg = paymentStatusMessage(
        status: 'failed',
        failureReason: 'event_cancelled',
        refundStatus: null,
      );
      expect(msg, contains('cancelled'));
      expect(msg, contains('refunded automatically'));
    });

    test('explains a sold-out event while paying', () {
      final msg = paymentStatusMessage(
        status: 'failed',
        failureReason: 'capacity_full',
        refundStatus: null,
      );
      expect(msg, contains('sold out'));
    });

    test('only reports failure when the server says failed', () {
      final msg = paymentStatusMessage(
        status: 'failed',
        failureReason: 'provider_declined',
        refundStatus: null,
      );
      expect(msg, 'Payment failed. Try again.');
    });
  });
}
