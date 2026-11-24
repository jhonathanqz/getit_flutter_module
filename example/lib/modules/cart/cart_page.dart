import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../products/price_label.dart';
import 'cart_controller.dart';

class CartPage extends GetItView<CartController> {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho')),
      body: ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          if (cart.items.isEmpty) {
            return const Center(child: Text('Seu carrinho está vazio'));
          }
          return ListView(
            children: [
              for (final MapEntry(key: product, value: quantity)
                  in cart.items.entries)
                ListTile(
                  leading: Text(product.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(product.name),
                  subtitle: Text(
                    '$quantity × ${context.get<PriceLabel>(param1: product.price).text}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => cart.remove(product),
                  ),
                ),
              const Divider(),
              ListTile(
                title: const Text('Total'),
                trailing: Text(
                  context.get<PriceLabel>(param1: cart.total).text,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
