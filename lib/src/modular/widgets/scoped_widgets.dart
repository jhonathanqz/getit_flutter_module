import 'package:flutter/material.dart';

import '../bind.dart';
import '../injector.dart';
import '../modular_container.dart';
import 'modular_page.dart';

/// Registra [binds] enquanto o widget estiver montado (componente com
/// dependências próprias, ex.: um card com seu controller).
class GetItModularWidget extends StatefulWidget {
  const GetItModularWidget({
    super.key,
    required this.builder,
    this.binds = const [],
    this.name,
    this.onInit,
    this.onDispose,
  });

  final WidgetBuilder builder;
  final List<Bind> binds;

  /// Identificador do escopo. Widgets com o mesmo nome compartilham binds.
  final String? name;
  final void Function(Injector i)? onInit;
  final void Function(Injector i)? onDispose;

  @override
  State<GetItModularWidget> createState() => _GetItModularWidgetState();
}

class _GetItModularWidgetState extends State<GetItModularWidget> {
  late final ModularContainer _container;
  late final String _id;

  @override
  void initState() {
    super.initState();
    _container = ModularContainer.instance;
    _id = 'widget:${widget.name ?? identityHashCode(this)}';
    if (_container.open(_id, widget.binds)) {
      widget.onInit?.call(_container.injector);
    }
  }

  @override
  void dispose() {
    _container.close(
      _id,
      beforeDispose: () => widget.onDispose?.call(_container.injector),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Navigator aninhado que resolve as rotas modulares (ex.: abas com
/// navegação própria).
class GetItRouteOutlet extends StatelessWidget {
  const GetItRouteOutlet({
    super.key,
    required this.initialRoute,
    this.navigatorKey,
    this.notFound,
    this.observers = const [],
  });

  final String initialRoute;
  final GlobalKey<NavigatorState>? navigatorKey;
  final WidgetBuilder? notFound;
  final List<NavigatorObserver> observers;

  Route<dynamic> _generate(RouteSettings settings) {
    final route = ModularContainer.instance.routes[settings.name];
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: route != null
          ? (_) => ModularPage(route: route)
          : notFound ?? (_) => const Center(child: Text('Page not found')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      initialRoute: initialRoute,
      observers: observers,
      // Sem isso o Navigator quebra '/A/B' em ['/', '/A', '/A/B'] e empilha
      // rotas intermediárias que não existem.
      onGenerateInitialRoutes: (_, initialRoute) =>
          [_generate(RouteSettings(name: initialRoute))],
      onGenerateRoute: _generate,
    );
  }
}

/// Widget sem estado com acesso tipado a uma dependência.
///
/// ```dart
/// class HomePage extends GetItView<HomeController> {
///   const HomePage({super.key});
///   @override
///   Widget build(BuildContext context) => Text(controller.title);
/// }
/// ```
abstract class GetItView<T extends Object> extends StatelessWidget {
  const GetItView({super.key});

  T get controller => Injector.I.get<T>();
}
