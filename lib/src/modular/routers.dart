import 'package:flutter/widgets.dart';

import 'bind.dart';
import 'injector.dart';
import 'middleware.dart';

/// Builder usado quando a página precisa aguardar binds assíncronos ou
/// middlewares assíncronos. [loader] é o widget do middleware em execução.
typedef WidgetBuilderAsync = Widget Function(
  BuildContext context,
  bool isReady,
  Widget? loader,
);

/// Nó da árvore de rotas: uma página ([MGetItPageRouter]) ou um agrupamento
/// de páginas/sub-módulos ([MGetItModuleRouter]).
sealed class MGetItRouter {
  const MGetItRouter({
    required this.name,
    this.bindings = const [],
    this.middlewares = const [],
  });

  /// Segmento do caminho, ex.: `/Home`. Use `/` para a rota "índice".
  final String name;

  /// Binds com o mesmo ciclo de vida deste nó.
  final List<Bind> bindings;

  final List<MGetItMiddleware> middlewares;
}

/// Uma página. Seus [bindings] são registrados ao abrir a rota e removidos
/// (com dispose) ao sair dela.
///
/// ```dart
/// MGetItPageRouter(
///   name: '/Page',
///   bindings: [Bind.lazySingleton((i) => HomeController())],
///   builder: (context) => HomePage(controller: context.get()),
/// )
/// ```
class MGetItPageRouter extends MGetItRouter {
  const MGetItPageRouter({
    required super.name,
    this.builder,
    this.builderAsync,
    super.bindings,
    super.middlewares,
  }) : assert(
          builder != null || builderAsync != null,
          'Informe builder ou builderAsync',
        );

  final WidgetBuilder? builder;

  /// Use quando houver binds assíncronos (`singletonAsync`, `dependsOn`)
  /// ou middlewares assíncronos:
  ///
  /// ```dart
  /// builderAsync: (context, isReady, loader) => isReady
  ///     ? const ProductsPage()
  ///     : loader ?? const CircularProgressIndicator(),
  /// ```
  final WidgetBuilderAsync? builderAsync;
}

/// Agrupa páginas e sub-módulos. Seus [bindings] vivem enquanto qualquer
/// página da sub-árvore estiver aberta; [onInit]/[onDispose] marcam a
/// entrada e a saída do grupo.
class MGetItModuleRouter extends MGetItRouter {
  const MGetItModuleRouter({
    required super.name,
    required this.pages,
    super.bindings,
    super.middlewares,
    this.onInit,
    this.onDispose,
  });

  final List<MGetItRouter> pages;
  final void Function(Injector i)? onInit;
  final void Function(Injector i)? onDispose;
}

/// Módulo baseado em classe. Agrupa as rotas de uma feature com binds
/// compartilhados entre elas.
///
/// ```dart
/// class AuthModule extends MGetItModule {
///   @override
///   String get moduleRouteName => '/Auth';
///
///   @override
///   List<Bind> get bindings => [Bind.lazySingleton((i) => AuthRepository())];
///
///   @override
///   List<MGetItRouter> get pages => [
///     MGetItPageRouter(name: '/Login', builder: (_) => const LoginPage()),
///   ];
/// }
/// ```
abstract class MGetItModule {
  /// Prefixo de todas as rotas do módulo.
  String get moduleRouteName;

  /// Binds compartilhados por todas as rotas do módulo.
  List<Bind> get bindings => const [];

  List<MGetItRouter> get pages;

  List<MGetItMiddleware> get middlewares => const [];

  /// Chamado na primeira entrada em qualquer rota do módulo.
  void onInit(Injector i) {}

  /// Chamado quando a última rota do módulo é fechada, antes dos binds
  /// serem descartados.
  void onDispose(Injector i) {}
}
