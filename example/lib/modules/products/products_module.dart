import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import 'catalog_permission_middleware.dart';
import 'detail/product_detail_controller.dart';
import 'detail/product_detail_page.dart';
import 'products_controller.dart';
import 'products_page.dart';
import 'products_repository.dart';
import 'recently_viewed.dart';

/// Rotas (abertas dentro do `GetItRouteOutlet` da Home):
/// * `/Products`         lista (bind assíncrono + middleware assíncrono)
/// * `/Products/Detail`  sub-módulo com argumentos
class ProductsModule extends GetItModule {
  @override
  String get moduleRouteName => '/Products';

  @override
  List<GetItMiddleware> get middlewares => const [CatalogPermissionMiddleware()];

  @override
  List<Bind> get bindings => [
        Bind.lazySingleton<ProductsRepository>((i) => ProductsRepository(i())),
        Bind.lazySingleton<RecentlyViewed>(
          (i) => RecentlyViewed(),
          keepAlive: true,
        ),
      ];

  @override
  List<GetItRouter> get pages => [
        GetItPageRouter(
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
        GetItModuleRouter(
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
            GetItPageRouter(name: '/', builder: (_) => const ProductDetailPage()),
          ],
        ),
      ];
}
