import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../cart/cart_controller.dart';
import '../cart/cart_page.dart';
import '../profile/profile_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _productsNavigator = GlobalKey<NavigatorState>();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cart = context.get<CartController>();
    return Scaffold(
      body: Stack(
        children: [
          // A aba de produtos tem navegação própria (lista -> detalhe) e é
          // mantida viva; as outras abas são montadas só quando visíveis.
          Offstage(
            offstage: _index != 0,
            child: TickerMode(
              enabled: _index == 0,
              child: GetItRouteOutlet(
                navigatorKey: _productsNavigator,
                initialRoute: '/Products',
              ),
            ),
          ),
          if (_index == 1) const CartPage(),
          if (_index == 2) const ProfileTab(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: cart,
        builder: (context, _) => NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              label: 'Produtos',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: cart.count > 0,
                label: Text('${cart.count}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              label: 'Carrinho',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
