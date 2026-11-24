import 'package:flutter/widgets.dart';

import '../core/get_it.dart';
import 'modular_container.dart';

/// Fachada de acesso às instâncias registradas.
///
/// Dentro dos binds é recebido como parâmetro (`(i) => Repo(i())`); fora
/// deles use [Injector.I] ou a extensão `context.get<T>()`.
class Injector {
  const Injector(this.getIt);

  /// Injector ligado ao container modular ativo (ou ao [GetIt.I]).
  static Injector get I =>
      Injector(ModularContainer.maybeInstance?.getIt ?? GetIt.I);

  final GetIt getIt;

  T get<T extends Object>({String? tag, dynamic param1, dynamic param2}) =>
      getIt.get<T>(instanceName: tag, param1: param1, param2: param2);

  T? maybeGet<T extends Object>({String? tag}) =>
      getIt.maybeGet<T>(instanceName: tag);

  Future<T> getAsync<T extends Object>({
    String? tag,
    dynamic param1,
    dynamic param2,
  }) =>
      getIt.getAsync<T>(instanceName: tag, param1: param1, param2: param2);

  Iterable<T> getAll<T extends Object>() => getIt.getAll<T>();

  bool isRegistered<T extends Object>({String? tag}) =>
      getIt.isRegistered<T>(instanceName: tag);

  Future<void> allReady({Duration? timeout}) =>
      getIt.allReady(timeout: timeout);

  Future<void> isReady<T extends Object>({String? tag, Duration? timeout}) =>
      getIt.isReady<T>(instanceName: tag, timeout: timeout);

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
