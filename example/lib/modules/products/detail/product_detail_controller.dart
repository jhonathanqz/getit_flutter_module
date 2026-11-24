import 'package:flutter/foundation.dart';
import 'package:getit_modular/getit_modular.dart';

import '../../../core/services/fake_api.dart';
import '../../cart/cart_controller.dart';
import '../products_repository.dart';
import '../recently_viewed.dart';

class ProductDetailController extends ChangeNotifier with ModularLifecycle {
  ProductDetailController({
    required this.id,
    required ProductsRepository repository,
    required RecentlyViewed recentlyViewed,
    required CartController cart,
  })  : _repository = repository,
        _recentlyViewed = recentlyViewed,
        _cart = cart;

  final int id;
  final ProductsRepository _repository;
  final RecentlyViewed _recentlyViewed;
  final CartController _cart;

  Product? product;

  @override
  void onInit() => _load();

  Future<void> _load() async {
    product = await _repository.fetchById(id);
    _recentlyViewed.add(product!);
    if (!_disposed) notifyListeners();
  }

  void addToCart() => _cart.add(product!);

  bool _disposed = false;

  @override
  void onDispose() {
    debugPrint('ProductDetailController($id) descartado');
    _disposed = true;
    dispose();
  }
}
