import 'package:flutter/foundation.dart';
import 'package:getit_modular/getit_modular.dart';

import 'auth_repository.dart';
import 'login/login_controller.dart';
import 'login/login_page.dart';
import 'register/register_controller.dart';
import 'register/register_name_page.dart';
import 'register/register_password_page.dart';

/// Rotas:
/// * `/Auth/Login`
/// * `/Auth/Register`           (sub-módulo, etapa 1)
/// * `/Auth/Register/Password`  (sub-módulo, etapa 2)
class AuthModule extends MGetItModule {
  @override
  String get moduleRouteName => '/Auth';

  /// Compartilhado por login e cadastro; descartado ao sair do módulo.
  @override
  List<Bind> get bindings => [
        Bind.lazySingleton<AuthRepository>((i) => AuthRepository(i(), i())),
      ];

  @override
  void onInit(Injector i) => debugPrint('>> entrou no módulo Auth');

  @override
  void onDispose(Injector i) => debugPrint('<< saiu do módulo Auth');

  @override
  List<MGetItRouter> get pages => [
        MGetItPageRouter(
          name: '/Login',
          bindings: [
            Bind.lazySingleton<LoginController>((i) => LoginController(i())),
          ],
          builder: (_) => const LoginPage(),
        ),
        // O RegisterController vive enquanto qualquer etapa do cadastro
        // estiver aberta: os dados digitados passam de uma tela para outra.
        MGetItModuleRouter(
          name: '/Register',
          bindings: [
            Bind.lazySingleton<RegisterController>(
              (i) => RegisterController(i()),
            ),
          ],
          pages: [
            MGetItPageRouter(
                name: '/', builder: (_) => const RegisterNamePage()),
            MGetItPageRouter(
              name: '/Password',
              builder: (_) => const RegisterPasswordPage(),
            ),
          ],
        ),
      ];
}
