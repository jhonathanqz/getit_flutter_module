import 'package:flutter/material.dart';

import '../../core/m_get_it.dart';
import '../bind.dart';
import '../logger.dart';
import '../middleware.dart';
import '../modular_container.dart';
import '../route_resolver.dart';
import '../routers.dart';
import 'modular_page.dart';

/// Builder do app: entregue as [routes] ao `MaterialApp.routes`.
/// [isReady] fica `true` quando os binds assíncronos da aplicação terminam.
typedef ModularAppBuilder = Widget Function(
  BuildContext context,
  Map<String, WidgetBuilder> routes,
  bool isReady,
);

/// Dependências que vivem durante toda a aplicação (HTTP client, storage...).
abstract class ApplicationBindings {
  List<Bind> bindings();
}

/// Widget raiz. Registra as dependências da aplicação e transforma os
/// [modules] / [pages] em rotas nomeadas que controlam automaticamente o
/// ciclo de vida das dependências.
///
/// ```dart
/// MGetItModular(
///   bindings: AppBindings(),
///   modules: [AuthModule(), HomeModule()],
///   builder: (context, routes, isReady) => MaterialApp(
///     initialRoute: '/Auth/Login',
///     routes: routes,
///   ),
/// );
/// ```
class MGetItModular extends StatefulWidget {
  const MGetItModular({
    super.key,
    required this.builder,
    this.bindings,
    this.modules = const [],
    this.pages = const [],
    this.middlewares = const [],
    this.mGetIt,
    this.logEnabled = false,
  });

  final ModularAppBuilder builder;
  final ApplicationBindings? bindings;
  final List<MGetItModule> modules;

  /// Rotas avulsas ([MGetItPageRouter]) ou agrupadas ([MGetItModuleRouter]).
  final List<MGetItRouter> pages;

  /// Middlewares executados em todas as rotas.
  final List<MGetItMiddleware> middlewares;

  /// Instância do [MGetIt] usada. Padrão: [MGetIt.I].
  final MGetIt? mGetIt;

  final bool logEnabled;

  static const String applicationScopeId = 'application';

  /// Gera rotas para uso em `onGenerateRoute` (alternativa ao mapa `routes`).
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final route = ModularContainer.instance.routes[settings.name];
    if (route == null) return null;
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => ModularPage(route: route),
    );
  }

  @override
  State<MGetItModular> createState() => _MGetItModularState();
}

class _MGetItModularState extends State<MGetItModular> {
  late final ModularContainer _container;
  late final Map<String, WidgetBuilder> _routes;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    ModularLogger.enabled = widget.logEnabled;
    _container = ModularContainer.initialize(widget.mGetIt ?? MGetIt.I)
      ..appMiddlewares = widget.middlewares
      ..routes = RouteResolver.resolve(
        modules: widget.modules,
        pages: widget.pages,
      );

    _routes = {
      for (final route in _container.routes.values)
        route.path: (_) => ModularPage(route: route),
    };

    _container.open(
      MGetItModular.applicationScopeId,
      widget.bindings?.bindings() ?? const [],
    );

    _isReady = _container.mGetIt.allReadySync();
    if (!_isReady) {
      _container.mGetIt.allReady().then((_) {
        if (mounted) setState(() => _isReady = true);
      });
    }
  }

  @override
  void dispose() {
    _container.closeAll();
    ModularContainer.shutdown();
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _routes, _isReady);
}
