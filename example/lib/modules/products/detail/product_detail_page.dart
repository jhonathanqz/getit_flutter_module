import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../../home/price_text.dart';
import 'product_detail_controller.dart';

class ProductDetailPage extends GetItView<ProductDetailController> {
  const ProductDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final product = controller.product;
        return Scaffold(
          appBar: AppBar(title: Text(product?.name ?? 'Carregando...')),
          body: product == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      product.emoji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 96),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      product.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    PriceText(
                      product.price,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(product.description, textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      key: const Key('add-to-cart'),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Adicionar ao carrinho'),
                      onPressed: () {
                        controller.addToCart();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${product.name} adicionado')),
                        );
                      },
                    ),
                  ],
                ),
        );
      },
    );
  }
}
