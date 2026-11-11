import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/payment_detail_screen.dart';

void main() {
  group('REF-005 Refund Detail Navigation & Parameters', () {
    test('PaymentDetailScreen requires either paymentId or historyId', () {
      expect(
        () => PaymentDetailScreen(paymentId: null, historyId: null),
        throwsAssertionError,
      );
      expect(
        const PaymentDetailScreen(paymentId: 'pay-123').paymentId,
        equals('pay-123'),
      );
      expect(
        const PaymentDetailScreen(historyId: 'rfnd-hist-456').historyId,
        equals('rfnd-hist-456'),
      );
    });

    test('app.dart registers /refunds/:id and /payments/:id routes', () {
      final appFile = File('lib/app.dart');
      expect(appFile.existsSync(), isTrue, reason: 'lib/app.dart must exist');
      final content = appFile.readAsStringSync();

      expect(
        content.contains("path: '/payments/:id'"),
        isTrue,
        reason: '/payments/:id route must be registered in app router',
      );
      expect(
        content.contains("path: '/refunds/:id'"),
        isTrue,
        reason: '/refunds/:id route must be registered in app router for historical refunds',
      );
      expect(
        content.contains("PaymentDetailScreen(historyId: state.pathParameters['id']!)"),
        isTrue,
        reason: '/refunds/:id must instantiate PaymentDetailScreen with historyId',
      );
    });

    test('my_payments_screen.dart routes to /refunds for archived refunds', () {
      final paymentsScreenFile = File('lib/screens/my_payments_screen.dart');
      expect(paymentsScreenFile.existsSync(), isTrue);
      final content = paymentsScreenFile.readAsStringSync();

      expect(
        content.contains("context.push(isHistory ? '/refunds/\$paymentId' : '/payments/\$paymentId')"),
        isTrue,
        reason: 'Archived refund cards must route to /refunds/:id',
      );
    });
  });
}
