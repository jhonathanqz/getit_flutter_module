import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../../core/services/session_store.dart';
import '../home/price_text.dart';
import 'products_controller.dart';
import 'recently_viewed.dart';

class ProductsPage extends GetItView<ProductsController> {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.get<SessionStore>().user;
    final recent = context.get<RecentlyViewed>();
    return Scaffold(
      appBar: AppBar(title: Text('Olá, ${user?.name ?? ''}')),
      body: ListView(
        children: [
          ListenableBuilder(
            listenable: recent,
            builder: (context, _) => recent.items.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Vistos recentemente:'),
                        for (final p in recent.items) Chip(label: Text(p.emoji)),
                      ],
                    ),
                  ),
          ),
          for (final product in controller.products)
            ListTile(
              key: Key('product-${product.id}'),
              leading: Text(product.emoji, style: const TextStyle(fontSize: 32)),
              title: Text(product.name),
              subtitle: PriceText(product.price),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .pushNamed('/Products/Detail', arguments: product.id),
            ),
        ],
      ),
    );
  }
}
