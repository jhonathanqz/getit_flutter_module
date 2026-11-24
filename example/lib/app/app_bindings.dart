import 'package:getit_flutter_module/getit_flutter_module.dart';

import '../core/services/app_config.dart';
import '../core/services/fake_api.dart';
import '../core/services/session_store.dart';

/// Dependências globais: ficam registradas durante toda a vida do app.
class AppBindings extends ApplicationBindings {
  AppBindings({required this.latency});

  final Duration latency;

  @override
  List<Bind> bindings() => [
        Bind.lazySingleton<FakeApi>((i) => FakeApi(latency: latency)),
        Bind.lazySingleton<SessionStore>((i) => SessionStore()),
        // Assíncrono: o app só fica "ready" quando terminar.
        Bind.singletonAsync<AppConfig>((i) => AppConfig.load(latency)),
      ];
}
