/// Injeção de dependências (service locator MGetIt) com estrutura
/// modular: dependências registradas ao entrar na rota/módulo e descartadas
/// automaticamente ao sair.
library;

export 'src/core/m_get_it.dart';
export 'src/modular/bind.dart';
export 'src/modular/injector.dart';
export 'src/modular/lifecycle.dart';
export 'src/modular/logger.dart';
export 'src/modular/middleware.dart';
export 'src/modular/modular_container.dart' show ModularContainer, ScopeInfo;
export 'src/modular/route_resolver.dart' show ResolvedRoute, RouteResolver;
export 'src/modular/routers.dart';
export 'src/modular/widgets/getit_modular.dart';
export 'src/modular/widgets/modular_page.dart';
export 'src/modular/widgets/scoped_widgets.dart';
