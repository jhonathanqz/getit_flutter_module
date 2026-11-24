import 'package:getit_flutter_module/getit_flutter_module.dart';

import '../../core/services/fake_api.dart';

/// Criado com `Bind.singletonAsync`: a página espera a lista carregar.
class ProductsController with ModularLifecycle {
  ProductsController(this.products);

  final List<Product> products;
}
