import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/payment.dart';
import 'package:mobile/utils.dart';

void main() {
  group('platform fee math (percent fee-on-top)', () {
    test('defaults to 6% of the ticket', () {
      expect(platformFeeTotal(10000, null), 600); // ₹100 → ₹6
      expect(platformFeeTotal(10000, 6), 600);
      expect(platformFeeTotal(0, null), 0);
    });

    test('an explicitly configured 0% fee charges no fee', () {
      expect(platformFeeTotal(10000, 0), 0);
    });

    test('custom percent computes the percent of the ticket', () {
      expect(platformFeeTotal(100000, 10), 10000);
      expect(platformFeeTotal(100000, 2.5), 2500);
    });

    test('rounds to the nearest paise', () {
      expect(platformFeeTotal(99, 6), 6); // 5.94 → 6
      expect(platformFeeTotal(101, 6), 6); // 6.06 → 6
      expect(platformFeeTotal(1, 6), 0); // 0.06 → 0
    });

    test('charge = ticket + fee, organizer keeps exactly the ticket', () {
      const ticket = 100000; // ₹1000
      final fee = platformFeeTotal(ticket, null); // 6000
      final charge = ticket + fee; // ₹1060

      expect(fee, 6000);
      expect(charge, 106000);
      // The invariant confirm_payment and the dashboard rely on:
      // amount = platform_fee + organizer_share.
      expect(charge - fee, ticket);
    });

    test('fee applies to the post-coupon ticket', () {
      const price = 100000; // ₹1000
      const discount = 10000; // 10% off coupon
      final ticket = price - discount; // ₹900 to the organizer
      final fee = platformFeeTotal(ticket, null);
      final charge = ticket + fee;

      expect(ticket, 90000);
      expect(fee, 5400); // 6% of ₹900, not of ₹1000
      expect(charge, 95400); // buyer pays ₹900 + ₹54
    });

    test('self-cancel math: ticket refunded, fee kept', () {
      const ticket = 100000;
      final fee = platformFeeTotal(ticket, null);
      final amount = ticket + fee;
      final refund = amount - fee;

      expect(refund, 100000); // full ticket back to buyer
      expect(fee, 6000); // ₹60 stays with the platform
    });
  });

  group('formatRupees', () {
    test('keeps paise only when the value is not whole', () {
      expect(formatRupees(106000), '₹1060');
      expect(formatRupees(2360), '₹23.60');
      expect(formatRupees(100000), '₹1000');
      expect(formatRupees(0), '₹0');
    });
  });

  group('Payment.fromMap', () {
    test('parses the persisted fee split (new rows: no GST)', () {
      final payment = Payment.fromMap({
        'id': 'pay-1',
        'registration_id': 'reg-1',
        'amount': 106000,
        'platform_fee': 6000,
        'platform_fee_gst': null,
        'organizer_share': 100000,
        'status': 'success',
        'created_at': '2026-10-18T10:00:00Z',
        'updated_at': '2026-10-18T10:00:00Z',
      });

      expect(payment.amount, 106000);
      expect(payment.platformFee, 6000);
      expect(payment.platformFeeGst, isNull);
      expect(payment.organizerShare, 100000);
      // amount = platform fee + organizer share (dashboard invariant)
      expect(payment.amount, payment.platformFee! + payment.organizerShare!);
    });

    test('parses historical GST-bearing rows unchanged', () {
      final payment = Payment.fromMap({
        'id': 'pay-0',
        'registration_id': 'reg-0',
        'amount': 102360,
        'platform_fee': 2360,
        'platform_fee_gst': 360,
        'organizer_share': 100000,
        'status': 'success',
        'created_at': '2026-10-07T10:00:00Z',
        'updated_at': '2026-10-07T10:00:00Z',
      });

      expect(payment.amount, 102360);
      expect(payment.platformFee, 2360);
      expect(payment.platformFeeGst, 360);
      expect(payment.organizerShare, 100000);
    });

    test('tolerates rows without the split (legacy payments)', () {
      final payment = Payment.fromMap({
        'id': 'pay-2',
        'registration_id': 'reg-2',
        'amount': 100000,
        'status': 'success',
        'created_at': '2026-10-07T10:00:00Z',
        'updated_at': '2026-10-07T10:00:00Z',
      });

      expect(payment.platformFee, isNull);
      expect(payment.platformFeeGst, isNull);
      expect(payment.organizerShare, isNull);
      expect(payment.toMap()['platform_fee'], isNull);
    });
  });
}
