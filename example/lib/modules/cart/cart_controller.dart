import 'package:flutter/foundation.dart';
import 'package:getit_modular/getit_modular.dart';

import '../../core/services/fake_api.dart';

/// Carrinho: registrado no módulo Home, vive enquanto o usuário está logado
/// e é descartado no logout.
class CartController extends ChangeNotifier with ModularLifecycle {
  final Map<Product, int> _items = {};

  Map<Product, int> get items => Map.unmodifiable(_items);
  int get count => _items.values.fold(0, (a, b) => a + b);
  double get total =>
      _items.entries.fold(0, (sum, e) => sum + e.key.price * e.value);

  void add(Product product) {
    _items.update(product, (q) => q + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  void remove(Product product) {
    final quantity = (_items[product] ?? 0) - 1;
    if (quantity <= 0) {
      _items.remove(product);
    } else {
      _items[product] = quantity;
    }
    notifyListeners();
  }

  @override
  void onDispose() => dispose();
}
