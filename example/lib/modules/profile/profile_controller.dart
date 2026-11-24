import 'package:flutter/foundation.dart';
import 'package:getit_modular/getit_modular.dart';

import '../../core/services/fake_api.dart';
import '../../core/services/session_store.dart';

/// Registrado via [GetItModularWidget]: existe apenas enquanto a aba de
/// perfil está visível.
class ProfileController with ModularLifecycle {
  ProfileController(this._session);

  final SessionStore _session;
  late final DateTime openedAt;

  User get user => _session.user!;

  @override
  void onInit() {
    openedAt = DateTime.now();
    debugPrint('ProfileController criado');
  }

  @override
  void onDispose() => debugPrint('ProfileController descartado');

  void logout() => _session.logout();
}
