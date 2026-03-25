
class CouponModel {
  final String id;
  final String code;
  final String discountType; // 'percentage' or 'flat'
  final double value;
  final bool isActive;
  final DateTime? expiryDate;
  final double minOrderValue;
  final int? usageLimit;
  final int currentUsage;
  final List<String>? applicableItemIds;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.value,
    this.isActive = true,
    this.expiryDate,
    this.minOrderValue = 0.0,
    this.usageLimit,
    this.currentUsage = 0,
    this.applicableItemIds,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'],
      code: json['code'],
      discountType: json['discount_type'],
      value: (json['value'] as num).toDouble(),
      isActive: json['is_active'] ?? true,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date']).toLocal() : null,
      minOrderValue: (json['min_order_value'] as num? ?? 0.0).toDouble(),
      usageLimit: json['usage_limit'],
      currentUsage: json['current_usage'] ?? 0,
      applicableItemIds: json['applicable_item_ids'] != null ? List<String>.from(json['applicable_item_ids']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_type': discountType,
      'value': value,
      'is_active': isActive,
      'expiry_date': expiryDate?.toUtc().toIso8601String(),
      'min_order_value': minOrderValue,
      'usage_limit': usageLimit,
      'current_usage': currentUsage,
      'applicable_item_ids': applicableItemIds,
    };
  }

  /// Returns null if valid, otherwise returns a descriptive error message.
  String? validate(double subtotal) {
    if (!isActive) return 'This coupon is no longer active.';
    
    if (expiryDate != null && DateTime.now().isAfter(expiryDate!)) {
      return 'This coupon has expired.';
    }

    if (subtotal < minOrderValue) {
      return 'Minimum order amount of ₹${minOrderValue.toStringAsFixed(0)} required.';
    }

    if (usageLimit != null && currentUsage >= usageLimit!) {
      return 'This coupon is no longer available (usage limit reached).';
    }

    return null;
  }

  double calculateDiscount(double subtotal, List<dynamic> cartItems) {
    // If we have applicable items, calculate discount only on those items
    double eligibleSubtotal = subtotal;
    
    if (applicableItemIds != null && applicableItemIds!.isNotEmpty) {
      eligibleSubtotal = 0;
      for (var item in cartItems) {
        // We assume cartItems is a list of objects that have a menuItem property or are raw maps
        // or CartItem objects from cart_provider.dart
        String? itemId;
        double itemPrice = 0;
        int qty = 1;

        // Try to handle different item structures (from POS or Checkout)
        try {
          // If it's a CartItem (POS)
          itemId = item.menuItem.id;
          itemPrice = item.menuItem.price;
          qty = item.quantity;
        } catch (_) {
          // If it's a raw Map (from Checkout orderData or similar)
          itemId = item['id'] ?? item['menu_item_id'];
          itemPrice = (item['price'] as num).toDouble();
          qty = (item['quantity'] as num).toInt();
        }

        if (applicableItemIds!.contains(itemId)) {
          eligibleSubtotal += itemPrice * qty;
        }
      }
    }

    if (eligibleSubtotal <= 0) return 0.0;

    if (discountType == 'percentage') {
      return (eligibleSubtotal * value) / 100;
    } else {
      // For flat discount, if it's more than the eligible subtotal, cap it
      return value > eligibleSubtotal ? eligibleSubtotal : value;
    }
  }
}
