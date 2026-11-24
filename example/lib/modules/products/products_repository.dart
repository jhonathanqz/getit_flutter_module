import '../../core/services/fake_api.dart';

class ProductsRepository {
  ProductsRepository(this._api);

  final FakeApi _api;

  Future<List<Product>> fetchAll() => _api.fetchProducts();
  Future<Product> fetchById(int id) => _api.fetchProduct(id);
}
