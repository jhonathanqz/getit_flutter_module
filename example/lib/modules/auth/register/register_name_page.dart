import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import 'register_controller.dart';

class RegisterNamePage extends MGetItView<RegisterController> {
  const RegisterNamePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta (1/2)')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            key: const Key('register-name'),
            controller: controller.name,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('register-email'),
            controller: controller.email,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: Listenable.merge([controller.name, controller.email]),
            builder: (context, _) => FilledButton(
              key: const Key('register-next'),
              onPressed: controller.stepOneValid
                  ? () =>
                      Navigator.of(context).pushNamed('/Auth/Register/Password')
                  : null,
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }
}
