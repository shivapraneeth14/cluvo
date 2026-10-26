import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils.dart';

Map<String, dynamic> _registration({bool deleted = false, String? status}) {
  return {
    'id': 'reg-1',
    'event_id': 'evt-1',
    'status': status ?? (deleted ? 'cancelled' : 'confirmed'),
    'deleted_at': deleted ? '2026-10-20T10:00:00Z' : null,
  };
}

Map<String, dynamic> _event({String status = 'published', num price = 50000}) {
  return {'id': 'evt-1', 'title': 'Event', 'status': status, 'price': price};
}

Map<String, dynamic> _payment({
  String status = 'success',
  String? refundStatus,
  String? refundClaimState,
  num? refundedAmount,
}) {
  return {
    'id': 'pay-1',
    'status': status,
    'refund_status': refundStatus,
    'refund_claim_state': refundClaimState ?? 'none',
    'refunded_amount': refundedAmount,
  };
}

bool _hidden(
  Map<String, dynamic> registration, {
  Map<String, dynamic>? payment,
  Map<String, dynamic>? event,
}) {
  return isAbandonedCheckout(
    registration: registration,
    payment: payment,
    event: event ?? _event(),
  );
}

void main() {
  group('isAbandonedCheckout hides only money-less checkouts', () {
    test('a live registration is never hidden', () {
      expect(_hidden(_registration(), payment: _payment()), isFalse);
    });

    test('an organizer-cancelled event is never hidden', () {
      expect(
        _hidden(
          _registration(deleted: true),
          event: _event(status: 'cancelled'),
        ),
        isFalse,
      );
    });

    test('a captured payment keeps the cancelled booking visible', () {
      expect(
        _hidden(_registration(deleted: true), payment: _payment()),
        isFalse,
      );
    });

    test('a refunded payment keeps the cancelled booking visible', () {
      expect(
        _hidden(
          _registration(deleted: true),
          payment: _payment(status: 'refunded', refundStatus: 'processed'),
        ),
        isFalse,
      );
    });

    test('a refund in flight keeps the booking visible', () {
      for (final refundStatus in ['requested', 'pending', 'queued']) {
        expect(
          _hidden(
            _registration(deleted: true),
            payment: _payment(refundStatus: refundStatus),
          ),
          isFalse,
          reason: 'refund_status=$refundStatus must not hide history',
        );
      }
    });

    test('a claimed refund (before refund_status is written) stays visible', () {
      expect(
        _hidden(
          _registration(deleted: true),
          payment: _payment(
            status: 'success',
            refundClaimState: 'claimed',
          ),
        ),
        isFalse,
      );
    });

    test('a failed refund stays visible for support follow-up', () {
      expect(
        _hidden(
          _registration(deleted: true),
          payment: _payment(refundStatus: 'failed'),
        ),
        isFalse,
      );
    });

    test('a recorded refunded_amount keeps the booking visible', () {
      expect(
        _hidden(
          _registration(deleted: true),
          payment: _payment(status: 'failed', refundedAmount: 50000),
        ),
        isFalse,
      );
    });

    test('a failed payment is an abandoned checkout', () {
      expect(
        _hidden(_registration(deleted: true), payment: _payment(status: 'failed')),
        isTrue,
      );
    });

    test('a pending payment is an abandoned checkout', () {
      expect(
        _hidden(_registration(deleted: true), payment: _payment(status: 'pending')),
        isTrue,
      );
    });

    test('a cancelled free-event booking stays visible', () {
      expect(
        _hidden(
          _registration(deleted: true),
          event: _event(price: 0),
        ),
        isFalse,
      );
    });

    test('a paid event with no payment row is an abandoned checkout', () {
      expect(
        _hidden(_registration(deleted: true), event: _event(price: 50000)),
        isTrue,
      );
    });
  });

  group('paymentHasMoneyTrail', () {
    test('is false without a payment row', () {
      expect(paymentHasMoneyTrail(null), isFalse);
    });

    test('is false for a checkout that never captured money', () {
      expect(paymentHasMoneyTrail(_payment(status: 'failed')), isFalse);
      expect(paymentHasMoneyTrail(_payment(status: 'pending')), isFalse);
    });

    test('is true for captured money or any refund field', () {
      expect(paymentHasMoneyTrail(_payment()), isTrue);
      expect(
        paymentHasMoneyTrail(_payment(refundClaimState: 'issued')),
        isTrue,
      );
      expect(
        paymentHasMoneyTrail(_payment(status: 'failed', refundStatus: 'failed')),
        isTrue,
      );
    });
  });

  group('embeddedPayment', () {
    test('reads the object shape', () {
      expect(embeddedPayment({'payments': _payment()})?['id'], 'pay-1');
    });

    test('reads the array shape', () {
      expect(embeddedPayment({'payments': [_payment()]})?['id'], 'pay-1');
    });

    test('returns null when absent or empty', () {
      expect(embeddedPayment({'payments': null}), isNull);
      expect(embeddedPayment({'payments': []}), isNull);
      expect(embeddedPayment({}), isNull);
    });
  });
}
