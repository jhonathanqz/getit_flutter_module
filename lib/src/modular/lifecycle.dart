import 'dart:async';

import '../core/get_it.dart';

/// Mixin para classes gerenciadas pelos [Bind]s:
///
/// * [onInit] é chamado logo após a instância ser criada;
/// * [onDispose] é chamado quando o escopo (rota/módulo/widget) que a
///   registrou é fechado.
///
/// ```dart
/// class HomeController with ModularLifecycle {
///   @override
///   void onInit() => load();
///
///   @override
///   void onDispose() => _subscription.cancel();
/// }
/// ```
mixin ModularLifecycle implements Disposable {
  void onInit() {}

  @override
  FutureOr onDispose() {}
}
