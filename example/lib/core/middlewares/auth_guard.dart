import 'package:flutter/widgets.dart';
import 'package:getit_modular/getit_modular.dart';

import '../services/session_store.dart';

/// Bloqueia rotas que exigem login e redireciona para o login.
class AuthGuard extends GetItSyncMiddleware {
  const AuthGuard();

  @override
  MiddlewareResult execute(RouteSettings? route) =>
      Injector.I.get<SessionStore>().isLogged
          ? MiddlewareResult.next
          : MiddlewareResult.failure;

  @override
  void onFail(
    RouteSettings? route,
    MiddlewareContext context,
    MiddlewareResult result,
  ) {
    context.pushNamedAndRemoveUntil('/Auth/Login', (_) => false);
  }
}
