import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/menu_item_model.dart';
import '../../models/coupon_model.dart';

// ---------------------------------------------------------------------------
// Split Payment Model
// Represents a single payment method and the amount charged via that method.
// ---------------------------------------------------------------------------
class SplitPayment {
  final String method; // 'cash', 'card', 'upi'
  final double amount;

  const SplitPayment({required this.method, required this.amount});

  SplitPayment copyWith({String? method, double? amount}) {
    return SplitPayment(method: method ?? this.method, amount: amount ?? this.amount);
  }
}

class CartItem {
  final MenuItem menuItem;
  final int quantity;

  CartItem({required this.menuItem, this.quantity = 1});

  double get total => menuItem.price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      menuItem: menuItem,
      quantity: quantity ?? this.quantity,
    );
  }
}

// ---------------------------------------------------------------------------
// CartState
// All new split-payment fields are OPTIONAL with safe defaults so that
// existing code that reads CartState is completely unaffected.
// ---------------------------------------------------------------------------
class CartState {
  final List<CartItem> items;
  final CouponModel? appliedCoupon;
  final double taxRate; // 0.05 for 5%
  final String paymentMethod; // 'cash', 'card', 'upi'  (used when split is OFF)

  // Split payment – new, backward-compatible fields
  final bool isSplitPayment;
  final List<SplitPayment> splitPayments;

  CartState({
    this.items = const [],
    this.appliedCoupon,
    this.taxRate = 0.0,
    this.paymentMethod = 'cash',
    // Defaults keep the old build working without any changes
    this.isSplitPayment = false,
    this.splitPayments = const [],
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discountAmount => appliedCoupon?.calculateDiscount(subtotal, items) ?? 0.0;
  double get taxAmount => (subtotal - discountAmount) * taxRate;
  double get total => (subtotal - discountAmount) + taxAmount;

  /// The label stored in the DB / shown in history.
  /// - Split mode: "cash:100.00|upi:99.00"  (exact amounts encoded, sorted by method)
  /// - Normal mode: unchanged original paymentMethod value (e.g. "cash", "upi")
  String get effectivePaymentLabel {
    if (!isSplitPayment || splitPayments.isEmpty) return paymentMethod;
    final sorted = [...splitPayments]..sort((a, b) => a.method.compareTo(b.method));
    return sorted.map((s) => '${s.method}:${s.amount.toStringAsFixed(2)}').join('|');
  }

  /// Human-friendly display label (used in history/invoice UI)
  /// e.g. "CASH + UPI" from "cash:100.00|upi:99.00"
  String get displayPaymentLabel {
    if (!isSplitPayment || splitPayments.isEmpty) return paymentMethod.toUpperCase();
    final sorted = [...splitPayments]..sort((a, b) => a.method.compareTo(b.method));
    return sorted.map((s) => s.method.toUpperCase()).join(' + ');
  }

  /// Sum of all entered split amounts
  double get splitTotal => splitPayments.fold(0, (sum, s) => sum + s.amount);

  /// Whether the split amounts exactly match the grand total
  bool get isSplitValid =>
      isSplitPayment &&
      splitPayments.length >= 2 &&
      (splitTotal - total).abs() < 0.01;

  CartState copyWith({
    List<CartItem>? items,
    CouponModel? appliedCoupon,
    bool clearCoupon = false,
    double? taxRate,
    String? paymentMethod,
    // Optional split params – not passed by existing callers, so they stay unchanged
    bool? isSplitPayment,
    List<SplitPayment>? splitPayments,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      taxRate: taxRate ?? this.taxRate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSplitPayment: isSplitPayment ?? this.isSplitPayment,
      splitPayments: splitPayments ?? this.splitPayments,
    );
  }
}

// ---------------------------------------------------------------------------
// CartNotifier
// All existing methods are UNCHANGED. New split-payment helpers are additive.
// ---------------------------------------------------------------------------
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => CartState();

  void addItem(MenuItem item) {
    final existingIndex = state.items.indexWhere((i) => i.menuItem.id == item.id);
    if (existingIndex >= 0) {
      final newItems = state.items.map((i) {
        if (i.menuItem.id == item.id) return i.copyWith(quantity: i.quantity + 1);
        return i;
      }).toList();
      state = state.copyWith(items: newItems);
    } else {
      state = state.copyWith(items: [...state.items, CartItem(menuItem: item)]);
    }
  }

  void decrementItem(String itemId) {
    final existingIndex = state.items.indexWhere((i) => i.menuItem.id == itemId);
    if (existingIndex >= 0) {
      final item = state.items[existingIndex];
      if (item.quantity > 1) {
        final newItems = state.items.map((i) {
          if (i.menuItem.id == itemId) return i.copyWith(quantity: i.quantity - 1);
          return i;
        }).toList();
        state = state.copyWith(items: newItems);
      } else {
        removeItem(itemId);
      }
    }
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((i) => i.menuItem.id != itemId).toList(),
    );
  }

  void clearCart() => state = CartState();

  void applyCoupon(CouponModel coupon) => state = state.copyWith(appliedCoupon: coupon);

  void removeCoupon() => state = state.copyWith(clearCoupon: true);

  void setTaxRate(double rate) => state = state.copyWith(taxRate: rate);

  void setPaymentMethod(String method) => state = state.copyWith(paymentMethod: method);

  // -------------------------------------------------------------------------
  // Split payment helpers (NEW – do not affect existing callers)
  // -------------------------------------------------------------------------

  /// Enable split mode with a default two-method split (cash + upi)
  void enableSplitPayment() {
    state = state.copyWith(
      isSplitPayment: true,
      splitPayments: const [
        SplitPayment(method: 'cash', amount: 0),
        SplitPayment(method: 'upi', amount: 0),
      ],
    );
  }

  /// Disable split mode, revert to single paymentMethod
  void disableSplitPayment() {
    state = state.copyWith(isSplitPayment: false, splitPayments: []);
  }

  /// Replace the full list of split payments (used by the split UI widget)
  void setSplitPayments(List<SplitPayment> payments) {
    state = state.copyWith(splitPayments: payments);
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
