import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/payment.dart';
import 'package:mobile/utils.dart';

void main() {
  group('platform fee math (fee-on-top)', () {
    test('defaults to ₹20 + 18% GST = ₹23.60', () {
      expect(gstForPlatformFee(kDefaultPlatformFeePaise), 360);
      expect(platformFeeTotal(null), 2360);
      expect(platformFeeTotal(kDefaultPlatformFeePaise), 2360);
    });

    test('an explicitly configured ₹0 fee charges no fee', () {
      expect(platformFeeTotal(0), 0);
    });

    test('custom fee amount computes GST on the fee only', () {
      expect(gstForPlatformFee(5000), 900);
      expect(platformFeeTotal(5000), 5900);
    });

    test('charge = ticket + fee, organizer keeps exactly the ticket', () {
      const ticket = 100000; // ₹1000
      final fee = platformFeeTotal(null); // 2360
      final charge = ticket + fee; // ₹1023.60

      expect(charge, 102360);
      // The invariant confirm_payment and the dashboard rely on:
      // amount = platform_fee + organizer_share.
      expect(charge - fee, ticket);
    });

    test('coupon discount applies to the ticket, fee stays flat', () {
      const price = 100000; // ₹1000
      const discount = 10000; // 10% off coupon
      final ticket = price - discount; // ₹900 to the organizer
      final charge = ticket + platformFeeTotal(null);

      expect(ticket, 90000);
      expect(charge, 92360); // buyer pays ₹900 + ₹23.60
    });

    test('self-cancel math: ticket refunded, fee kept', () {
      const amount = 102360; // what the buyer paid
      final fee = platformFeeTotal(null);
      final refund = amount - fee;

      expect(refund, 100000); // full ticket back to buyer
      expect(fee, 2360); // ₹23.60 stays with the platform
    });
  });

  group('formatRupees', () {
    test('keeps paise only when the value is not whole', () {
      expect(formatRupees(102360), '₹1023.60');
      expect(formatRupees(2360), '₹23.60');
      expect(formatRupees(100000), '₹1000');
      expect(formatRupees(0), '₹0');
    });
  });

  group('Payment.fromMap', () {
    test('parses the persisted fee split', () {
      final payment = Payment.fromMap({
        'id': 'pay-1',
        'registration_id': 'reg-1',
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
      // amount = platform fee + organizer share (dashboard invariant)
      expect(payment.amount, payment.platformFee! + payment.organizerShare!);
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
