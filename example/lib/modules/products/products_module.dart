import 'package:flutter/material.dart';
import 'package:getit_flutter_module/getit_flutter_module.dart';

import 'catalog_permission_middleware.dart';
import 'detail/product_detail_controller.dart';
import 'detail/product_detail_page.dart';
import 'products_controller.dart';
import 'products_page.dart';
import 'products_repository.dart';
import 'recently_viewed.dart';

/// Rotas (abertas dentro do `MGetItRouteOutlet` da Home):
/// * `/Products`         lista (bind assíncrono + middleware assíncrono)
/// * `/Products/Detail`  sub-módulo com argumentos
class ProductsModule extends MGetItModule {
  @override
  String get moduleRouteName => '/Products';

  @override
  List<MGetItMiddleware> get middlewares =>
      const [CatalogPermissionMiddleware()];

  @override
  List<Bind> get bindings => [
        Bind.lazySingleton<ProductsRepository>((i) => ProductsRepository(i())),
        Bind.lazySingleton<RecentlyViewed>(
          (i) => RecentlyViewed(),
          keepAlive: true,
        ),
      ];

  @override
  List<MGetItRouter> get pages => [
        MGetItPageRouter(
          name: '/',
          bindings: [
            Bind.singletonAsync<ProductsController>(
              (i) async => ProductsController(
                await i.get<ProductsRepository>().fetchAll(),
              ),
            ),
          ],
          builderAsync: (context, isReady, loader) => isReady
              ? const ProductsPage()
              : Scaffold(
                  appBar: AppBar(title: const Text('Produtos')),
                  body: loader ??
                      const Center(child: CircularProgressIndicator()),
                ),
        ),
        MGetItModuleRouter(
          name: '/Detail',
          bindings: [
            // Lê o id enviado em `arguments` ao navegar.
            Bind.lazySingleton<ProductDetailController>(
              (i) => ProductDetailController(
                id: i.arguments! as int,
                repository: i(),
                recentlyViewed: i(),
                cart: i(),
              ),
            ),
          ],
          pages: [
            MGetItPageRouter(
                name: '/', builder: (_) => const ProductDetailPage()),
          ],
        ),
      ];
}
