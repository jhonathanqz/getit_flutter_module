import 'package:flutter/foundation.dart';

import '../../core/services/fake_api.dart';

/// Registrado com `keepAlive: true`: sobrevive ao logout e continua
/// disponível quando o usuário volta ao catálogo.
class RecentlyViewed extends ChangeNotifier {
  final List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);

  void add(Product product) {
    _items
      ..remove(product)
      ..insert(0, product);
    if (_items.length > 5) _items.removeLast();
    notifyListeners();
  }
}
