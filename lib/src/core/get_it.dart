// Reimplementação do service locator `get_it` (https://github.com/flutter-it/get_it)
// mantendo a mesma API pública, para servir de motor da camada modular.
//
// ignore_for_file: avoid_print
library;

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:meta/meta.dart';

part 'get_it_impl.dart';

/// Tipo de registro de um objeto/factory dentro do [GetIt].
enum ObjectRegistrationType {
  /// Factory: um novo objeto a cada chamada de [GetIt.get].
  alwaysNew,

  /// Singleton comum (instância já criada ou criada assincronamente).
  constant,

  /// Lazy singleton: criado na primeira chamada de [GetIt.get].
  lazy,

  /// Factory com cache: reutiliza a instância enquanto ela estiver viva
  /// (referência fraca) e os parâmetros forem os mesmos.
  cachedFactory,
}

/// Se uma classe implementar esta interface, ela precisa chamar
/// [GetIt.signalReady] para sinalizar que está pronta.
abstract class WillSignalReady {}

/// Implemente esta interface para ser notificado quando o objeto for
/// "sombreado" por um registro do mesmo tipo em um escopo superior.
abstract mixin class ShadowChangeHandlers {
  void onGetShadowed(Object shadowing);
  void onLeaveShadow(Object shadowing);
}

/// Objetos que implementam [Disposable] têm [onDispose] chamado
/// automaticamente ao serem removidos do [GetIt] (quando nenhuma função
/// de dispose foi informada no registro).
abstract mixin class Disposable {
  FutureOr onDispose();
}

typedef FactoryFunc<T> = T Function();
typedef FactoryFuncParam<T, P1, P2> = T Function(P1 param1, P2 param2);
typedef FactoryFuncAsync<T> = Future<T> Function();
typedef DisposingFunc<T> = FutureOr Function(T param);
typedef ScopeDisposeFunc = FutureOr Function();
typedef FactoryFuncParamAsync<T, P1, P2> = Future<T> Function(
  P1 param1,
  P2 param2,
);

/// Usado em `dependsOn` para depender de um registro nomeado.
class InitDependency implements Type {
  final Type type;
  final String? instanceName;

  InitDependency(this.type, {this.instanceName});

  @override
  String toString() => 'InitDependency(type:$type, instanceName:$instanceName)';
}

/// Lançada por [GetIt.allReady]/[GetIt.isReady] quando o `timeout` estoura.
class WaitingTimeOutException implements Exception {
  /// Para cada tipo ainda não pronto, quem está esperando por ele.
  final Map<String, List<String>> areWaitedBy;
  final List<String> notReadyYet;
  final List<String> areReady;

  WaitingTimeOutException(this.areWaitedBy, this.notReadyYet, this.areReady);

  @override
  String toString() {
    final buffer = StringBuffer(
      'GetIt: There was a timeout while waiting for an instance to signal ready\n',
    );
    buffer.writeln('The following instance types where waiting for completion');
    for (final entry in areWaitedBy.entries) {
      buffer.writeln('${entry.value} is waiting for ${entry.key}');
    }
    buffer.writeln('The following instance types have NOT signalled ready yet');
    notReadyYet.forEach(buffer.writeln);
    buffer.writeln('The following instance types HAVE signalled ready yet');
    areReady.forEach(buffer.writeln);
    return buffer.toString();
  }
}

/// Informações públicas sobre um registro.
abstract class ObjectRegistration<T extends Object> {
  ObjectRegistrationType get registrationType;
  String? get instanceName;
  bool get isAsync;
  bool get acceptsParams;
  Object? get instance;
  Type get registeredWithType;
  bool get isReady;
  bool get isNamedRegistration => instanceName != null;
  String get debugName => '$instanceName : $registeredWithType';
  bool get canBeWaitedFor;
}

/// Service locator. Use [GetIt.instance] / [GetIt.I] para a instância global
/// ou [GetIt.asNewInstance] para instâncias isoladas (ex.: testes).
abstract class GetIt {
  static final GetIt _instance = _GetItImplementation();

  /// Chamado sempre que um escopo é empilhado (`true`) ou desempilhado (`false`).
  void Function(bool pushed)? onScopeChanged;

  static GetIt get instance => _instance;

  // ignore: non_constant_identifier_names
  static GetIt get I => _instance;

  factory GetIt.asNewInstance() => _GetItImplementation();

  /// Quando `true`, nenhuma mensagem de debug é impressa.
  static bool noDebugOutput = false;

  /// Publica eventos para o DevTools (`dart:developer`).
  bool debugEventsEnabled = false;

  /// Permite sobrescrever um registro já existente.
  bool allowReassignment = false;

  /// Ignora silenciosamente registros duplicados (útil em testes).
  @visibleForTesting
  bool skipDoubleRegistration = false;

  /// Não lança erro ao tentar remover algo não registrado.
  bool skipUnregisterIfNotRegistered = false;

  /// Permite registrar várias implementações (sem nome) do mesmo tipo.
  /// [get] devolve a primeira e [getAll] devolve todas.
  void enableRegisteringMultipleInstancesOfOneType();

  @visibleForTesting
  bool allowRegisterMultipleImplementationsOfoneType = false;

  T get<T extends Object>({
    dynamic param1,
    dynamic param2,
    String? instanceName,
    Type? type,
  });

  T? maybeGet<T extends Object>({
    dynamic param1,
    dynamic param2,
    String? instanceName,
    Type? type,
  });

  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  });

  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
    String? onlyInScope,
  });

  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
    String? onlyInScope,
  });

  List<T> findAll<T extends Object>({
    bool includeSubtypes = true,
    bool inAllScopes = false,
    String? onlyInScope,
    bool includeMatchedByRegistrationType = true,
    bool includeMatchedByInstance = true,
    bool instantiateLazySingletons = false,
    bool callFactories = false,
  });

  /// Permite escrever `getIt<MyType>()` no lugar de `getIt.get<MyType>()`.
  T call<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  });

  void registerFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  });

  void registerCachedFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  });

  void registerFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  });

  void registerCachedFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  });

  void registerFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  });

  void registerCachedFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  });

  void registerFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  });

  void registerCachedFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  });

  T registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  });

  /// Registra apenas se ainda não existir; caso exista, incrementa o contador
  /// de referências. Use [releaseInstance] para decrementar.
  T registerSingletonIfAbsent<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  });

  void releaseInstance(Object instance);

  void registerSingletonWithDependencies<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    required Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  });

  void registerSingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
  });

  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
    bool useWeakReference = false,
  });

  void registerLazySingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
    bool useWeakReference = false,
  });

  ObjectRegistration? findFirstObjectRegistration<T extends Object>({
    Object? instance,
    String? instanceName,
  });

  bool isRegistered<T extends Object>({
    Object? instance,
    String? instanceName,
    Type? type,
  });

  void changeTypeInstanceName<T extends Object>({
    String? instanceName,
    required String newInstanceName,
    T? instance,
  });

  /// Remove todos os registros de todos os escopos (chamando os disposes).
  Future<void> reset({bool dispose = true});

  /// Remove todos os registros do escopo atual.
  Future<void> resetScope({bool dispose = true});

  void pushNewScope({
    void Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal = false,
  });

  Future<void> pushNewScopeAsync({
    Future<void> Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
  });

  Future<void> popScope();

  Future<bool> popScopesTill(String name, {bool inclusive = true});

  Future<void> dropScope(String scopeName);

  bool hasScope(String scopeName);

  String? get currentScopeName;

  FutureOr resetLazySingleton<T extends Object>({
    T? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  });

  Future<void> resetLazySingletons({
    bool dispose = true,
    bool inAllScopes = false,
    String? onlyInScope,
  });

  bool checkLazySingletonInstanceExists<T extends Object>({
    String? instanceName,
  });

  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
    bool ignoreReferenceCount = false,
  });

  /// Completa quando todos os singletons assíncronos/com dependências e os
  /// que precisam de [signalReady] estiverem prontos.
  Future<void> allReady({
    Duration? timeout,
    bool ignorePendingAsyncCreation = false,
  });

  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  });

  bool isReadySync<T extends Object>({Object? instance, String? instanceName});

  // ignore: avoid_positional_boolean_parameters
  bool allReadySync([bool ignorePendingAsyncCreation = false]);

  /// Sinaliza que [instance] (registrado com `signalsReady: true`) está pronto.
  void signalReady(Object? instance);
}
