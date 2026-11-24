import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import 'register_controller.dart';

class RegisterPasswordPage extends MGetItView<RegisterController> {
  const RegisterPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mesma instância usada na etapa 1 (bind do sub-módulo).
    final controller = this.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta (2/2)')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Olá, ${controller.name.text}! Defina uma senha para '
              '${controller.email.text}.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('register-password'),
              controller: controller.password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('register-submit'),
              onPressed: controller.loading
                  ? null
                  : () async {
                      await controller.submit();
                      if (context.mounted) {
                        // Sai de todo o módulo Auth: os binds são descartados.
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/Home', (_) => false);
                      }
                    },
              child: const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }
}
