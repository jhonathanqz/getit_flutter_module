import 'package:flutter/widgets.dart';

import '../core/m_get_it.dart';
import 'modular_container.dart';

/// Fachada de acesso às instâncias registradas.
///
/// Dentro dos binds é recebido como parâmetro (`(i) => Repo(i())`); fora
/// deles use [Injector.I] ou a extensão `context.get<T>()`.
class Injector {
  const Injector(this.mGetIt);

  /// Injector ligado ao container modular ativo (ou ao [MGetIt.I]).
  static Injector get I =>
      Injector(ModularContainer.maybeInstance?.mGetIt ?? MGetIt.I);

  final MGetIt mGetIt;

  T get<T extends Object>({String? tag, dynamic param1, dynamic param2}) =>
      mGetIt.get<T>(instanceName: tag, param1: param1, param2: param2);

  T? maybeGet<T extends Object>({String? tag}) =>
      mGetIt.maybeGet<T>(instanceName: tag);

  Future<T> getAsync<T extends Object>({
    String? tag,
    dynamic param1,
    dynamic param2,
  }) =>
      mGetIt.getAsync<T>(instanceName: tag, param1: param1, param2: param2);

  Iterable<T> getAll<T extends Object>() => mGetIt.getAll<T>();

  bool isRegistered<T extends Object>({String? tag}) =>
      mGetIt.isRegistered<T>(instanceName: tag);

  Future<void> allReady({Duration? timeout}) =>
      mGetIt.allReady(timeout: timeout);

  Future<void> isReady<T extends Object>({String? tag, Duration? timeout}) =>
      mGetIt.isReady<T>(instanceName: tag, timeout: timeout);

  /// Argumentos da última rota modular aberta.
  Object? get arguments => ModularContainer.maybeInstance?.arguments;

  T call<T extends Object>({String? tag, dynamic param1, dynamic param2}) =>
      get<T>(tag: tag, param1: param1, param2: param2);
}

/// Atalhos de injeção a partir do [BuildContext].
extension InjectorContext on BuildContext {
  T get<T extends Object>({String? tag, dynamic param1, dynamic param2}) =>
      Injector.I.get<T>(tag: tag, param1: param1, param2: param2);

  Future<T> getAsync<T extends Object>({String? tag}) =>
      Injector.I.getAsync<T>(tag: tag);

  bool isRegistered<T extends Object>({String? tag}) =>
      Injector.I.isRegistered<T>(tag: tag);

  /// Argumentos da rota atual (`ModalRoute.of(context)?.settings.arguments`).
  T? arguments<T>() {
    final args = ModalRoute.of(this)?.settings.arguments;
    return args is T ? args : null;
  }
}
