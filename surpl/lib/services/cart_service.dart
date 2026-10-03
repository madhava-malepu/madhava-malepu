import 'package:flutter/material.dart';

class CartItem {
  final String bagId;
  final String merchantId;
  final String merchantName;
  final String title;
  final String image;
  final double price;
  final double originalPrice;
  final String pickupStart;
  final String pickupEnd;
  int quantity;
  int availableQuantity; // live cap, refreshed on cart open
  // 'surplus' (default, existing Surprise Bags) or 'freshFood' (Local
  // Kitchens — made-to-order, full price, 0% Surpl commission).
  final String listingType;

  CartItem({
    required this.bagId,
    required this.merchantId,
    required this.merchantName,
    required this.title,
    required this.image,
    required this.price,
    required this.originalPrice,
    required this.pickupStart,
    required this.pickupEnd,
    required this.quantity,
    required this.availableQuantity,
    this.listingType = 'surplus',
  });

  double get lineTotal => price * quantity;
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final Map<String, CartItem> _items = {}; // bagId -> item

  List<CartItem> get items => _items.values.toList();
  int get itemCount => _items.length;
  int get totalQuantity => _items.values.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _items.values.fold(0.0, (s, i) => s + i.lineTotal);
  bool get isEmpty => _items.isEmpty;

  /// Distinct merchant ids currently in the cart.
  Set<String> get merchantIds => _items.values.map((i) => i.merchantId).toSet();

  /// True if the cart already has items from a DIFFERENT restaurant than
  /// merchantId. Surpl is pickup-only, not delivery - a mixed cart would
  /// mean the customer themselves has to physically visit two different
  /// locations, so this is enforced the same way Swiggy/Zomato enforce a
  /// single-restaurant cart.
  bool hasConflictWith(String merchantId) {
    if (_items.isEmpty) return false;
    return merchantIds.length > 1 || !merchantIds.contains(merchantId);
  }

  void addItem(CartItem newItem) {
    // FIX: this previously summed the existing quantity with the new
    // one (existing.quantity + newItem.quantity), which is only correct
    // for a genuine "add N more on top" action. Neither actual caller
    // wants that: bag_detail's quantity selector already shows the
    // TOTAL desired quantity for that bag, not an increment - so tapping
    // "Book Now" a second time (e.g. after going back) was silently
    // doubling the cart quantity each time, since it kept adding on top
    // of what was already there instead of just setting it. Confirmed
    // directly from a screen recording of the bug.
    final existing = _items[newItem.bagId];
    if (existing != null) {
      final maxQty = newItem.availableQuantity;
      existing.quantity = newItem.quantity.clamp(1, maxQty == 0 ? newItem.quantity : maxQty);
      existing.availableQuantity = newItem.availableQuantity;
    } else {
      _items[newItem.bagId] = newItem;
    }
    notifyListeners();
  }

  void updateQuantity(String bagId, int quantity) {
    final item = _items[bagId];
    if (item == null) return;
    if (quantity <= 0) {
      removeItem(bagId);
      return;
    }
    final maxQty = item.availableQuantity;
    item.quantity = maxQty > 0 ? quantity.clamp(1, maxQty) : quantity;
    notifyListeners();
  }

  void removeItem(String bagId) {
    _items.remove(bagId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  CartItem? operator [](String bagId) => _items[bagId];
}
