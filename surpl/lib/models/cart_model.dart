import 'package:flutter/foundation.dart';
import 'item_model.dart';

class CartItem {
  final Item item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});
}

class CartModel extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => Map.unmodifiable(_items);

  int get itemCount => _items.values.fold(0, (sum, ci) => sum + ci.quantity);

  double get totalPrice =>
      _items.values.fold(0, (sum, ci) => sum + ci.item.price * ci.quantity);

  double get totalSaved =>
      _items.values.fold(0, (sum, ci) => sum + ci.item.savedAmount * ci.quantity);

  int quantityOf(String itemId) => _items[itemId]?.quantity ?? 0;

  void addItem(Item item) {
    if (_items.containsKey(item.id)) {
      _items[item.id]!.quantity++;
    } else {
      _items[item.id] = CartItem(item: item);
    }
    notifyListeners();
  }

  void removeItem(Item item) {
    if (!_items.containsKey(item.id)) return;
    if (_items[item.id]!.quantity <= 1) {
      _items.remove(item.id);
    } else {
      _items[item.id]!.quantity--;
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
