class Payment {
  final String id;
  final String registrationId;
  final double amount;
  final double? platformFee;
  final double? platformFeeGst;
  final double? organizerShare;
  final String currency;
  final String? couponId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String status;
  final String? refundStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Payment({
    required this.id,
    required this.registrationId,
    required this.amount,
    this.platformFee,
    this.platformFeeGst,
    this.organizerShare,
    this.currency = 'INR',
    this.couponId,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.status = 'pending',
    this.refundStatus,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
    id: map['id'] as String,
    registrationId: map['registration_id'] as String,
    amount: (map['amount'] as num).toDouble(),
    platformFee: map['platform_fee'] != null
        ? (map['platform_fee'] as num).toDouble()
        : null,
    platformFeeGst: map['platform_fee_gst'] != null
        ? (map['platform_fee_gst'] as num).toDouble()
        : null,
    organizerShare: map['organizer_share'] != null
        ? (map['organizer_share'] as num).toDouble()
        : null,
    currency: map['currency'] as String? ?? 'INR',
    couponId: map['coupon_id'] as String?,
    razorpayOrderId: map['razorpay_order_id'] as String?,
    razorpayPaymentId: map['razorpay_payment_id'] as String?,
    status: map['status'] as String? ?? 'pending',
    refundStatus: map['refund_status'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    deletedAt: map['deleted_at'] != null
        ? DateTime.parse(map['deleted_at'] as String).toLocal()
        : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'registration_id': registrationId,
    'amount': amount,
    if (platformFee != null) 'platform_fee': platformFee,
    if (platformFeeGst != null) 'platform_fee_gst': platformFeeGst,
    if (organizerShare != null) 'organizer_share': organizerShare,
    'currency': currency,
    if (couponId != null) 'coupon_id': couponId,
    if (razorpayOrderId != null) 'razorpay_order_id': razorpayOrderId,
    if (razorpayPaymentId != null) 'razorpay_payment_id': razorpayPaymentId,
    'status': status,
    if (refundStatus != null) 'refund_status': refundStatus,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
  };
}
