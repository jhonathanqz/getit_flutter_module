import 'dart:async';

import 'package:flutter/material.dart';

/// Resultado da execução de um middleware.
enum MiddlewareResult {
  /// Segue para o próximo middleware.
  next,

  /// Interrompe a abertura da rota e chama [GetItMiddleware.onFail].
  failure,

  /// Encerra a cadeia com sucesso (os próximos middlewares não rodam).
  complete,
}

/// Base dos middlewares: executados quando uma rota modular é aberta,
/// antes de a página ser considerada "pronta".
sealed class GetItMiddleware {
  const GetItMiddleware();

  /// Permite pular o middleware para determinadas rotas.
  bool executeWhen(RouteSettings? route) => true;

  /// Chamado quando o middleware retorna [MiddlewareResult.failure].
  /// O padrão é voltar para a rota anterior, se possível.
  FutureOr<void> onFail(
    RouteSettings? route,
    MiddlewareContext context,
    MiddlewareResult result,
  ) {
    if (context.canPop()) context.pop();
  }
}

/// Middleware síncrono (ex.: verificação de permissão em memória).
abstract class GetItSyncMiddleware extends GetItMiddleware {
  const GetItSyncMiddleware();

  MiddlewareResult execute(RouteSettings? route);
}

/// Middleware assíncrono (ex.: validar token na API). Enquanto executa, o
/// [loader] é entregue ao `builderAsync` da página.
abstract class GetItAsyncMiddleware extends GetItMiddleware {
  const GetItAsyncMiddleware();

  Future<MiddlewareResult> execute(RouteSettings? route);

  Widget get loader =>
      const Center(child: CircularProgressIndicator.adaptive());
}

/// Acesso seguro à navegação a partir de um middleware.
class MiddlewareContext {
  MiddlewareContext(this.context);

  final BuildContext context;

  NavigatorState get navigator => Navigator.of(context);

  bool canPop() => navigator.canPop();

  void pop<T extends Object?>([T? result]) => navigator.pop(result);

  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) =>
      navigator.pushReplacementNamed<T, TO>(
        routeName,
        result: result,
        arguments: arguments,
      );

  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) =>
      navigator.pushNamedAndRemoveUntil<T>(
        routeName,
        predicate,
        arguments: arguments,
      );

  void showSnackBar(SnackBar snackBar) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
}
