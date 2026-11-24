import 'package:flutter/foundation.dart';

import 'bind.dart';

/// Log simples do ciclo de vida dos escopos e binds.
///
/// Ative com `MGetItModular(logEnabled: true)` ou `ModularLogger.enabled = true`.
abstract final class ModularLogger {
  static bool enabled = false;

  /// Permite redirecionar o log (ex.: para testes).
  static void Function(String message) output = debugPrint;

  static void _log(String message) {
    if (enabled) output('[getit_modular] $message');
  }

  static void enterScope(String id) => _log('🚪 enter $id');
  static void exitScope(String id) => _log('👋 exit $id');
  static void registered(Bind bind) => _log('➕ register $bind');
  static void disposed(Bind bind) => _log('🗑️ dispose $bind');
  static void keptAlive(Bind bind) => _log('📌 keepAlive $bind');
  static void alreadyRegistered(Bind bind) =>
      _log('⚠️ ${bind.bindType} already registered outside modular, reusing');
  static void middlewareFailed(String middleware, String route) =>
      _log('⛔ middleware $middleware failed on $route');
}
