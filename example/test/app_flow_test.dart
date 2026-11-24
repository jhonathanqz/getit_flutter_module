import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getit_modular/getit_modular.dart';
import 'package:getit_modular_example/app/app_widget.dart';
import 'package:getit_modular_example/core/services/app_config.dart';
import 'package:getit_modular_example/modules/auth/auth_repository.dart';
import 'package:getit_modular_example/modules/auth/login/login_controller.dart';
import 'package:getit_modular_example/modules/auth/register/register_controller.dart';
import 'package:getit_modular_example/modules/cart/cart_controller.dart';
import 'package:getit_modular_example/modules/products/detail/product_detail_controller.dart';
import 'package:getit_modular_example/modules/products/products_controller.dart';
import 'package:getit_modular_example/modules/products/recently_viewed.dart';
import 'package:getit_modular_example/modules/profile/profile_controller.dart';

const latency = Duration(milliseconds: 50);

MGetIt get mGetIt => MGetIt.I;

Future<void> settle(WidgetTester tester) async {
  // Avança o relógio fake para concluir as chamadas da API fake.
  for (var i = 0; i < 6; i++) {
    await tester.pump(latency);
  }
  await tester.pumpAndSettle();
}

Future<void> startApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(500, 900));
  await tester.pumpWidget(const App(latency: latency, showInspector: false));
  expect(find.text('Carregando configurações...'), findsOneWidget);
  await settle(tester);
}

void main() {
  tearDown(() async {
    await MGetIt.I.reset();
  });

  testWidgets(
      'splash -> login -> catálogo -> detalhe -> carrinho -> perfil -> logout',
      (tester) async {
    await startApp(tester);

    // Splash concluído: config da aplicação pronta, login aberto.
    expect(mGetIt.isRegistered<AppConfig>(), isTrue);
    expect(find.text('Mercadinho Modular'), findsOneWidget);
    expect(mGetIt.isRegistered<LoginController>(), isTrue);
    expect(mGetIt.isRegistered<AuthRepository>(), isTrue);

    // Login: sai do módulo Auth, entra na Home + Products.
    await tester.tap(find.byKey(const Key('login-submit')));
    await settle(tester);
    expect(find.text('Olá, dev'), findsOneWidget);
    expect(mGetIt.isRegistered<LoginController>(), isFalse);
    expect(mGetIt.isRegistered<AuthRepository>(), isFalse);
    expect(mGetIt.isRegistered<CartController>(), isTrue);
    expect(mGetIt.isRegistered<ProductsController>(), isTrue);

    // Detalhe recebe o id via arguments.
    await tester.tap(find.byKey(const Key('product-2')));
    await settle(tester);
    expect(find.text('Pão de queijo'), findsWidgets);
    expect(mGetIt<ProductDetailController>().id, 2);
    await tester.tap(find.byKey(const Key('add-to-cart')));
    await tester.pumpAndSettle();
    expect(mGetIt<CartController>().count, 1);

    // Volta para a lista: o sub-módulo de detalhe é descartado.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(mGetIt.isRegistered<ProductDetailController>(), isFalse);
    expect(find.text('Vistos recentemente:'), findsOneWidget);

    // Carrinho (factoryParam PriceLabel formata os valores).
    await tester.tap(find.text('Carrinho'));
    await tester.pumpAndSettle();
    expect(find.text(r'1 × R$ 18,50'), findsOneWidget);

    // Perfil: binds do MGetItModularWidget só existem com a aba visível.
    expect(mGetIt.isRegistered<ProfileController>(), isFalse);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(mGetIt.isRegistered<ProfileController>(), isTrue);
    expect(find.byKey(const Key('profile-name')), findsOneWidget);
    await tester.tap(find.text('Produtos'));
    await tester.pumpAndSettle();
    expect(mGetIt.isRegistered<ProfileController>(), isFalse);

    // Logout: Home e Products descartados; keepAlive e app continuam.
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await settle(tester);
    expect(find.text('Entrar'), findsOneWidget);
    expect(mGetIt.isRegistered<CartController>(), isFalse);
    expect(mGetIt.isRegistered<ProductsController>(), isFalse);
    expect(mGetIt.isRegistered<ProfileController>(), isFalse);
    expect(mGetIt.isRegistered<RecentlyViewed>(), isTrue);
    expect(mGetIt<RecentlyViewed>().items.single.name, 'Pão de queijo');
    expect(mGetIt.isRegistered<AppConfig>(), isTrue);

    expect(
      ModularContainer.instance.openScopes.keys,
      ['application', 'module:/Auth', 'page:/Auth/Login'],
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cadastro em duas etapas compartilha o controller do sub-módulo',
      (tester) async {
    await startApp(tester);

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    final step1 = mGetIt<RegisterController>();
    await tester.enterText(find.byKey(const Key('register-name')), 'Maria');
    await tester.enterText(
        find.byKey(const Key('register-email')), 'maria@x.com');
    await tester.pump();
    await tester.tap(find.byKey(const Key('register-next')));
    await tester.pumpAndSettle();

    expect(mGetIt<RegisterController>(), same(step1));
    expect(find.textContaining('Olá, Maria!'), findsOneWidget);

    // Voltar da etapa 2 para a 1 mantém o sub-módulo vivo.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(mGetIt<RegisterController>(), same(step1));
    await tester.tap(find.byKey(const Key('register-next')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('register-password')), 'secret');
    await tester.tap(find.byKey(const Key('register-submit')));
    await settle(tester);

    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(mGetIt.isRegistered<RegisterController>(), isFalse);
    expect(mGetIt.isRegistered<AuthRepository>(), isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('login com senha inválida mostra erro e continua no módulo',
      (tester) async {
    await startApp(tester);
    await tester.enterText(find.byKey(const Key('login-password')), '1');
    await tester.tap(find.byKey(const Key('login-submit')));
    await settle(tester);
    expect(find.textContaining('Senha inválida'), findsOneWidget);
    expect(mGetIt.isRegistered<LoginController>(), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
