import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../core/services/log_store.dart';
import '../core/widgets/scope_inspector.dart';
import '../modules/auth/auth_module.dart';
import '../modules/home/home_module.dart';
import '../modules/products/products_module.dart';
import 'app_bindings.dart';
import 'splash_page.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    this.latency = const Duration(milliseconds: 700),
    this.showInspector = true,
  });

  /// Latência simulada da API fake (os testes usam um valor menor).
  final Duration latency;
  final bool showInspector;

  @override
  Widget build(BuildContext context) {
    ModularLogger.output = (message) {
      debugPrint(message);
      LogStore.instance.add(message);
    };

    return GetItModular(
      logEnabled: true,
      bindings: AppBindings(latency: latency),
      modules: [AuthModule(), HomeModule(), ProductsModule()],
      builder: (context, routes, isReady) => MaterialApp(
        title: 'getit_modular',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2E5BFF),
          useMaterial3: true,
        ),
        initialRoute: '/Auth/Login',
        routes: routes,
        builder: (context, child) {
          // Enquanto os binds assíncronos do app carregam, mostra o splash.
          if (!isReady) return const SplashPage();
          return Stack(
            children: [
              child!,
              if (showInspector)
                const Positioned(
                  right: 16,
                  bottom: 96,
                  child: SafeArea(child: ScopeInspector()),
                ),
            ],
          );
        },
      ),
    );
  }
}
