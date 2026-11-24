import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getit_modular/getit_modular.dart';

final events = <String>[];

class AppService {}

class AuthRepository with ModularLifecycle {
  @override
  void onInit() => events.add('repo:init');
  @override
  void onDispose() => events.add('repo:dispose');
}

class LoginController with ModularLifecycle {
  LoginController(this.repository);
  final AuthRepository repository;
  @override
  void onInit() => events.add('login:init');
  @override
  void onDispose() => events.add('login:dispose');
}

class RegisterController with ModularLifecycle {
  @override
  void onDispose() => events.add('register:dispose');
}

class AsyncConfig {
  AsyncConfig(this.value);
  final String value;
}

class AppBindings extends ApplicationBindings {
  @override
  List<Bind> bindings() => [Bind.lazySingleton<AppService>((i) => AppService())];
}

class AuthModule extends GetItModule {
  @override
  String get moduleRouteName => '/Auth';

  @override
  List<Bind> get bindings => [
        Bind.lazySingleton<AuthRepository>((i) => AuthRepository()),
      ];

  @override
  void onInit(Injector i) => events.add('auth:onInit');

  @override
  void onDispose(Injector i) => events.add('auth:onDispose');

  @override
  List<GetItRouter> get pages => [
        GetItPageRouter(
          name: '/Login',
          bindings: [
            Bind.lazySingleton<LoginController>((i) => LoginController(i())),
          ],
          builder: (context) {
            context.get<LoginController>();
            return Scaffold(
              body: Column(children: [
                const Text('login'),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/Auth/Register'),
                  child: const Text('go register'),
                ),
              ]),
            );
          },
        ),
        GetItModuleRouter(
          name: '/Register',
          onInit: (_) => events.add('register-module:onInit'),
          onDispose: (_) => events.add('register-module:onDispose'),
          bindings: [
            Bind.lazySingleton<RegisterController>((i) => RegisterController()),
          ],
          pages: [
            GetItPageRouter(
              name: '/',
              builder: (context) {
                context.get<RegisterController>();
                context.get<AuthRepository>();
                return const Scaffold(body: Text('register'));
              },
            ),
          ],
        ),
      ];
}

class HomeModule extends GetItModule {
  @override
  String get moduleRouteName => '/Home';

  @override
  List<GetItRouter> get pages => [
        GetItPageRouter(
          name: '/',
          bindings: [
            Bind.singletonAsync<AsyncConfig>((i) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return AsyncConfig('loaded');
            }),
          ],
          builderAsync: (context, isReady, loader) => isReady
              ? Scaffold(body: Text(context.get<AsyncConfig>().value))
              : const Text('loading'),
        ),
        GetItPageRouter(
          name: '/Args',
          bindings: [
            Bind.factory<String>((i) => 'arg=${i.arguments}'),
          ],
          builder: (context) => Text(context.get<String>()),
        ),
      ];
}

class BlockMiddleware extends GetItSyncMiddleware {
  @override
  MiddlewareResult execute(RouteSettings? route) => MiddlewareResult.failure;
}

class SlowMiddleware extends GetItAsyncMiddleware {
  @override
  Future<MiddlewareResult> execute(RouteSettings? route) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return MiddlewareResult.next;
  }

  @override
  Widget get loader => const Text('middleware running');
}

final navigatorKey = GlobalKey<NavigatorState>();

Widget buildApp({
  String initialRoute = '/Auth/Login',
  List<GetItRouter> pages = const [],
}) {
  return GetItModular(
    bindings: AppBindings(),
    modules: [AuthModule(), HomeModule()],
    pages: pages,
    builder: (context, routes, isReady) => MaterialApp(
      navigatorKey: navigatorKey,
      initialRoute: initialRoute,
      routes: routes,
    ),
  );
}

GetIt get getIt => GetIt.I;

void main() {
  setUp(() async {
    events.clear();
    await GetIt.I.reset();
  });

  test('RouteResolver monta caminhos e cadeia de escopos', () {
    final routes = RouteResolver.resolve(modules: [AuthModule(), HomeModule()]);
    expect(
      routes.keys,
      containsAll(['/Auth/Login', '/Auth/Register', '/Home', '/Home/Args']),
    );
    expect(
      routes['/Auth/Register']!.scopes.map((s) => s.id),
      ['module:/Auth', 'module:/Auth/Register', 'page:/Auth/Register'],
    );
  });

  testWidgets('registra binds ao entrar e faz dispose ao sair do módulo',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(getIt.isRegistered<AppService>(), isTrue);
    expect(getIt.isRegistered<AuthRepository>(), isTrue);
    expect(getIt.isRegistered<LoginController>(), isTrue);
    expect(events, ['auth:onInit', 'repo:init', 'login:init']);

    // Entra no sub-módulo: o módulo /Auth continua vivo.
    await tester.tap(find.text('go register'));
    await tester.pumpAndSettle();
    expect(find.text('register'), findsOneWidget);
    expect(getIt.isRegistered<RegisterController>(), isTrue);
    expect(events, contains('register-module:onInit'));
    expect(events.where((e) => e == 'auth:onInit'), hasLength(1));

    // Volta: sub-módulo é descartado, login continua.
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(getIt.isRegistered<RegisterController>(), isFalse);
    expect(events, containsAllInOrder(['register-module:onDispose', 'register:dispose']));
    expect(getIt.isRegistered<LoginController>(), isTrue);

    // Sai do módulo Auth por completo.
    navigatorKey.currentState!.pushReplacementNamed('/Home/Args', arguments: 7);
    await tester.pumpAndSettle();
    expect(find.text('arg=7'), findsOneWidget);
    expect(getIt.isRegistered<LoginController>(), isFalse);
    expect(getIt.isRegistered<AuthRepository>(), isFalse);
    expect(
      events,
      containsAllInOrder(['login:dispose', 'auth:onDispose', 'repo:dispose']),
    );
    // Dependência da aplicação continua.
    expect(getIt.isRegistered<AppService>(), isTrue);

    final container = ModularContainer.instance;
    expect(container.openScopes.keys, ['application', 'module:/Home', 'page:/Home/Args']);
  });

  testWidgets('builderAsync espera singletonAsync', (tester) async {
    await tester.pumpWidget(buildApp(initialRoute: '/Home'));
    await tester.pump();
    expect(find.text('loading'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.text('loaded'), findsOneWidget);
  });

  testWidgets('middleware sync com falha volta para a rota anterior',
      (tester) async {
    await tester.pumpWidget(buildApp(pages: [
      GetItPageRouter(
        name: '/Blocked',
        middlewares: [BlockMiddleware()],
        bindings: [Bind.lazySingleton<RegisterController>((i) => RegisterController())],
        builder: (_) => const Text('blocked page'),
      ),
    ]));
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pushNamed('/Blocked');
    await tester.pumpAndSettle();
    expect(find.text('blocked page'), findsNothing);
    expect(find.text('login'), findsOneWidget);
    expect(getIt.isRegistered<RegisterController>(), isFalse);
  });

  testWidgets('middleware async entrega loader ao builderAsync', (tester) async {
    await tester.pumpWidget(buildApp(
      initialRoute: '/Slow',
      pages: [
        GetItPageRouter(
          name: '/Slow',
          middlewares: [SlowMiddleware()],
          builderAsync: (context, isReady, loader) =>
              isReady ? const Text('slow ready') : loader ?? const Text('wait'),
        ),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('middleware running'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();
    expect(find.text('slow ready'), findsOneWidget);
  });

  testWidgets('GetItModularWidget registra binds pelo tempo de vida do widget',
      (tester) async {
    final show = ValueNotifier(true);
    await tester.pumpWidget(buildApp(
      initialRoute: '/Widget',
      pages: [
        GetItPageRouter(
          name: '/Widget',
          builder: (_) => ValueListenableBuilder(
            valueListenable: show,
            builder: (_, visible, __) => visible
                ? GetItModularWidget(
                    binds: [Bind.lazySingleton<RegisterController>((i) => RegisterController())],
                    builder: (context) {
                      context.get<RegisterController>();
                      return const Text('card');
                    },
                  )
                : const SizedBox(),
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();
    expect(getIt.isRegistered<RegisterController>(), isTrue);
    show.value = false;
    await tester.pump();
    expect(getIt.isRegistered<RegisterController>(), isFalse);
    expect(events, contains('register:dispose'));
  });

  testWidgets('keepAlive mantém a instância depois de sair', (tester) async {
    await tester.pumpWidget(buildApp(pages: [
      GetItPageRouter(
        name: '/Keep',
        bindings: [
          Bind.lazySingleton<RegisterController>(
            (i) => RegisterController(),
            keepAlive: true,
          ),
        ],
        builder: (_) => const Text('keep'),
      ),
    ]));
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pushNamed('/Keep');
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(getIt.isRegistered<RegisterController>(), isTrue);
  });

  testWidgets('desmontar o GetItModular descarta tudo', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(getIt.isRegistered<AppService>(), isFalse);
    expect(getIt.isRegistered<AuthRepository>(), isFalse);
    expect(ModularContainer.maybeInstance, isNull);
  });

  testWidgets('GetItRouteOutlet abre só a rota inicial (sem rotas intermediárias)',
      (tester) async {
    final outletKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildApp(
      initialRoute: '/Shell',
      pages: [
        GetItPageRouter(
          name: '/Shell',
          builder: (_) => Scaffold(
            body: GetItRouteOutlet(
              navigatorKey: outletKey,
              initialRoute: '/Auth/Register',
            ),
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('register'), findsOneWidget);
    expect(outletKey.currentState!.canPop(), isFalse);
    expect(getIt.isRegistered<RegisterController>(), isTrue);
  });
}
