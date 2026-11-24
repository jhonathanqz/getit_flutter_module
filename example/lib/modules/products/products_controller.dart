import 'package:getit_modular/getit_modular.dart';

import '../../core/services/fake_api.dart';

/// Criado com `Bind.singletonAsync`: a página espera a lista carregar.
class ProductsController with ModularLifecycle {
  ProductsController(this.products);

  final List<Product> products;
}
