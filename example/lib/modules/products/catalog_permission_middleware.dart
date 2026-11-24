import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../../core/services/fake_api.dart';

/// Middleware assíncrono: consulta a API antes de liberar o catálogo.
/// Enquanto executa, o [loader] é entregue ao `builderAsync` da página.
class CatalogPermissionMiddleware extends GetItAsyncMiddleware {
  const CatalogPermissionMiddleware();

  @override
  bool executeWhen(RouteSettings? route) => route?.name == '/Products';

  @override
  Future<MiddlewareResult> execute(RouteSettings? route) async {
    final allowed = await Injector.I.get<FakeApi>().canSeeCatalog();
    return allowed ? MiddlewareResult.next : MiddlewareResult.failure;
  }

  @override
  Widget get loader => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verificando permissões...'),
          ],
        ),
      );
}
