import 'bind.dart';
import 'injector.dart';
import 'middleware.dart';
import 'routers.dart';

/// Um nível de escopo percorrido até chegar na página
/// (módulo → sub-módulos → página).
class ScopeSpec {
  const ScopeSpec({
    required this.id,
    this.bindings = const [],
    this.middlewares = const [],
    this.onInit,
    this.onDispose,
  });

  final String id;
  final List<Bind> bindings;
  final List<MGetItMiddleware> middlewares;
  final void Function(Injector i)? onInit;
  final void Function(Injector i)? onDispose;

  @override
  String toString() => 'ScopeSpec($id)';
}

/// Rota final (caminho completo) com a cadeia de escopos que ela abre.
class ResolvedRoute {
  const ResolvedRoute({
    required this.path,
    required this.scopes,
    required this.page,
  });

  final String path;
  final List<ScopeSpec> scopes;
  final MGetItPageRouter page;
}

/// Achata módulos e rotas aninhadas em um mapa `caminho -> rota`.
abstract final class RouteResolver {
  static String join(String prefix, String name) {
    var segment = name.trim();
    if (segment.isEmpty || segment == '/') {
      return prefix.isEmpty ? '/' : prefix;
    }
    if (!segment.startsWith('/')) segment = '/$segment';
    if (segment.endsWith('/')) {
      segment = segment.substring(0, segment.length - 1);
    }
    final base = prefix == '/' ? '' : prefix;
    return '$base$segment';
  }

  static Map<String, ResolvedRoute> resolve({
    List<MGetItModule> modules = const [],
    List<MGetItRouter> pages = const [],
  }) {
    final result = <String, ResolvedRoute>{};

    void add(ResolvedRoute route) {
      if (result.containsKey(route.path)) {
        throw ArgumentError('getit_modular: rota duplicada "${route.path}"');
      }
      result[route.path] = route;
    }

    void walk(MGetItRouter node, String prefix, List<ScopeSpec> chain) {
      final path = join(prefix, node.name);
      switch (node) {
        case MGetItPageRouter():
          add(ResolvedRoute(
            path: path,
            page: node,
            scopes: [
              ...chain,
              ScopeSpec(
                id: 'page:$path',
                bindings: node.bindings,
                middlewares: node.middlewares,
              ),
            ],
          ));
        case MGetItModuleRouter():
          final scope = ScopeSpec(
            id: 'module:$path',
            bindings: node.bindings,
            middlewares: node.middlewares,
            onInit: node.onInit,
            onDispose: node.onDispose,
          );
          for (final child in node.pages) {
            walk(child, path, [...chain, scope]);
          }
      }
    }

    for (final module in modules) {
      final path = join('', module.moduleRouteName);
      final scope = ScopeSpec(
        id: 'module:$path',
        bindings: module.bindings,
        middlewares: module.middlewares,
        onInit: module.onInit,
        onDispose: module.onDispose,
      );
      for (final page in module.pages) {
        walk(page, path, [scope]);
      }
    }

    for (final page in pages) {
      walk(page, '', const []);
    }
    return result;
  }
}
