import 'package:flutter/widgets.dart';

import '../logger.dart';
import '../middleware.dart';
import '../modular_container.dart';
import '../route_resolver.dart';

/// Hospeda uma página modular: abre os escopos (módulo → sub-módulos →
/// página) ao entrar na rota, executa os middlewares, aguarda os binds
/// assíncronos e fecha os escopos (com dispose) ao sair.
class ModularPage extends StatefulWidget {
  const ModularPage({super.key, required this.route});

  final ResolvedRoute route;

  @override
  State<ModularPage> createState() => _ModularPageState();
}

class _ModularPageState extends State<ModularPage> {
  late final ModularContainer _container;
  final List<ScopeSpec> _openedScopes = [];
  bool _initialized = false;
  bool _ready = false;
  Widget? _loader;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final settings = ModalRoute.of(context)?.settings;
    _container = ModularContainer.instance;
    _container.arguments = settings?.arguments;
    _openScopes();

    _ready = !_mustWait();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare(settings));
  }

  void _openScopes() {
    final injector = _container.injector;
    try {
      for (final scope in widget.route.scopes) {
        final created = _container.open(scope.id, scope.bindings);
        _openedScopes.add(scope);
        if (created) scope.onInit?.call(injector);
      }
    } catch (_) {
      _closeScopes();
      rethrow;
    }
  }

  List<MGetItMiddleware> get _middlewares => [
        ..._container.appMiddlewares,
        for (final scope in widget.route.scopes) ...scope.middlewares,
      ];

  bool _mustWait() {
    if (widget.route.page.builderAsync == null) return false;
    final hasAsyncMiddleware =
        _middlewares.any((m) => m is MGetItAsyncMiddleware);
    return hasAsyncMiddleware || !_container.mGetIt.allReadySync();
  }

  Future<void> _prepare(RouteSettings? settings) async {
    if (!mounted) return;
    try {
      for (final middleware in _middlewares) {
        if (!middleware.executeWhen(settings)) continue;

        final MiddlewareResult result;
        switch (middleware) {
          case MGetItSyncMiddleware():
            result = middleware.execute(settings);
          case MGetItAsyncMiddleware():
            setState(() => _loader = middleware.loader);
            result = await middleware.execute(settings);
            if (!mounted) return;
            setState(() => _loader = null);
        }

        if (result == MiddlewareResult.failure) {
          ModularLogger.middlewareFailed(
            middleware.runtimeType.toString(),
            widget.route.path,
          );
          await middleware.onFail(settings, MiddlewareContext(context), result);
          return;
        }
        if (result == MiddlewareResult.complete) break;
      }

      await _container.mGetIt.allReady();
      if (mounted && !_ready) setState(() => _ready = true);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'getit_modular',
        context: ErrorDescription('while preparing ${widget.route.path}'),
      ));
    }
  }

  void _closeScopes() {
    final injector = _container.injector;
    for (final scope in _openedScopes.reversed) {
      _container.close(
        scope.id,
        beforeDispose: () => scope.onDispose?.call(injector),
      );
    }
    _openedScopes.clear();
  }

  @override
  void dispose() {
    _closeScopes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.route.page;
    if (page.builder != null) return page.builder!(context);
    return page.builderAsync!(context, _ready, _loader);
  }
}
