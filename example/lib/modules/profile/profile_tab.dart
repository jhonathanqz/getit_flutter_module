import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../../core/services/app_config.dart';
import 'profile_controller.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return GetItModularWidget(
      name: 'profile',
      binds: [Bind.lazySingleton<ProfileController>((i) => ProfileController(i()))],
      builder: (context) {
        final controller = context.get<ProfileController>();
        final config = context.get<AppConfig>();
        final user = controller.user;
        return Scaffold(
          appBar: AppBar(title: const Text('Perfil')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CircleAvatar(
                radius: 40,
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.name,
                key: const Key('profile-name'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(user.email, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Aba aberta às'),
                subtitle: Text(TimeOfDay.fromDateTime(controller.openedAt)
                    .format(context)),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(config.storeName),
                subtitle: Text('Versão ${config.version}'),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('logout'),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
                onPressed: () {
                  controller.logout();
                  // Fecha Home e Products: tudo é descartado, exceto
                  // binds com keepAlive e os da aplicação.
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil('/Auth/Login', (_) => false);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
