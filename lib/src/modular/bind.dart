import 'dart:async';

import '../core/m_get_it.dart';
import 'injector.dart';
import 'lifecycle.dart';

typedef BindRegister<T> = T Function(Injector i);
typedef BindAsyncRegister<T> = Future<T> Function(Injector i);
typedef BindParamRegister<T, P1, P2> = T Function(Injector i, P1 p1, P2 p2);

/// Forma como o [Bind] é registrado no [MGetIt].
enum BindType {
  singleton,
  singletonAsync,
  lazySingleton,
  lazySingletonAsync,
  factory,
  factoryAsync,
  factoryParam,
}

/// Chave que identifica um bind dentro do container (tipo + tag).
typedef BindKey = (Type, String?);

/// Declaração de uma dependência que será registrada quando o
/// módulo/página/widget dono dela for aberto e removida (com dispose)
/// quando ele for fechado.
///
/// ```dart
/// Bind.lazySingleton<HomeController>((i) => HomeController(i()));
/// Bind.singletonAsync<Prefs>((i) => Prefs.load());
/// Bind.factory<Validator>((i) => Validator());
/// ```
class Bind<T extends Object> {
  Bind._({
    required this.type,
    BindRegister<T>? register,
    BindAsyncRegister<T>? registerAsync,
    this.tag,
    this.keepAlive = false,
    this.dependsOn = const [],
    this.onDispose,
  })  : _register = register,
        _registerAsync = registerAsync;

  /// Instância criada imediatamente quando o escopo é aberto.
  ///
  /// Com [dependsOn], a criação aguarda os binds assíncronos informados.
  static Bind<T> singleton<T extends Object>(
    BindRegister<T> register, {
    String? tag,
    bool keepAlive = false,
    Iterable<Type> dependsOn = const [],
    DisposingFunc<T>? onDispose,
  }) =>
      Bind<T>._(
        type: BindType.singleton,
        register: register,
        tag: tag,
        keepAlive: keepAlive,
        dependsOn: dependsOn,
        onDispose: onDispose,
      );

  /// Instância criada de forma assíncrona assim que o escopo é aberto.
  /// Use `builderAsync` na página (ou `isReady` no app) para aguardar.
  static Bind<T> singletonAsync<T extends Object>(
    BindAsyncRegister<T> register, {
    String? tag,
    bool keepAlive = false,
    Iterable<Type> dependsOn = const [],
    DisposingFunc<T>? onDispose,
  }) =>
      Bind<T>._(
        type: BindType.singletonAsync,
        registerAsync: register,
        tag: tag,
        keepAlive: keepAlive,
        dependsOn: dependsOn,
        onDispose: onDispose,
      );

  /// Instância criada no primeiro `get` e reutilizada enquanto o escopo viver.
  static Bind<T> lazySingleton<T extends Object>(
    BindRegister<T> register, {
    String? tag,
    bool keepAlive = false,
    DisposingFunc<T>? onDispose,
  }) =>
      Bind<T>._(
        type: BindType.lazySingleton,
        register: register,
        tag: tag,
        keepAlive: keepAlive,
        onDispose: onDispose,
      );

  /// Como [lazySingleton], mas criada assincronamente (use `getAsync`).
  static Bind<T> lazySingletonAsync<T extends Object>(
    BindAsyncRegister<T> register, {
    String? tag,
    bool keepAlive = false,
    DisposingFunc<T>? onDispose,
  }) =>
      Bind<T>._(
        type: BindType.lazySingletonAsync,
        registerAsync: register,
        tag: tag,
        keepAlive: keepAlive,
        onDispose: onDispose,
      );

  /// Nova instância a cada `get`. Instâncias que implementam [Disposable] /
  /// [ModularLifecycle] são descartadas quando o escopo fecha.
  static Bind<T> factory<T extends Object>(
    BindRegister<T> register, {
    String? tag,
    DisposingFunc<T>? onDispose,
  }) =>
      Bind<T>._(
        type: BindType.factory,
        register: register,
        tag: tag,
        onDispose: onDispose,
      );

  /// Nova instância (assíncrona) a cada `getAsync`.
  static Bind<T> factoryAsync<T extends Object>(
    BindAsyncRegister<T> register, {
    String? tag,
    DisposingFunc<T>? onDispose,
  }) =>
      Bind<T>._(
        type: BindType.factoryAsync,
        registerAsync: register,
        tag: tag,
        onDispose: onDispose,
      );

  /// Factory com parâmetros: `i.get<T>(param1: x, param2: y)`.
  static Bind<T> factoryParam<T extends Object, P1, P2>(
    BindParamRegister<T, P1, P2> register, {
    String? tag,
    DisposingFunc<T>? onDispose,
  }) =>
      _ParamBind<T, P1, P2>(register, tag: tag, onDispose: onDispose);

  final BindType type;
  final BindRegister<T>? _register;
  final BindAsyncRegister<T>? _registerAsync;

  /// Equivalente ao `instanceName` do [MGetIt].
  final String? tag;

  /// Quando `true`, a instância nunca é removida, mesmo saindo do escopo.
  final bool keepAlive;

  final Iterable<Type> dependsOn;

  /// Função de dispose personalizada. Quando ausente, objetos que
  /// implementam [Disposable] (ou usam [ModularLifecycle]) têm `onDispose`
  /// chamado automaticamente.
  final DisposingFunc<T>? onDispose;

  Type get bindType => T;

  BindKey get key => (T, tag);

  bool get isAsync =>
      type == BindType.singletonAsync ||
      type == BindType.lazySingletonAsync ||
      type == BindType.factoryAsync;

  bool get isFactory =>
      type == BindType.factory ||
      type == BindType.factoryAsync ||
      type == BindType.factoryParam;

  /// Indica se o bind faz o app/página esperar antes de ficar "pronto".
  bool get blocksReady =>
      type == BindType.singletonAsync ||
      (type == BindType.singleton && dependsOn.isNotEmpty);

  bool isRegisteredIn(MGetIt mGetIt) =>
      mGetIt.isRegistered<T>(instanceName: tag);

  T _afterCreate(T object, void Function(Object)? onCreated) {
    if (object is ModularLifecycle) object.onInit();
    onCreated?.call(object);
    return object;
  }

  FutureOr<dynamic> _dispose(T object) {
    if (onDispose != null) return onDispose!(object);
    if (object is Disposable) return object.onDispose();
    return null;
  }

  /// Descarta uma instância criada por este bind (usado para factories).
  FutureOr<dynamic> disposeInstance(Object object) => _dispose(object as T);

  /// Registra o bind no [mGetIt]. [onFactoryCreated] é chamado a cada
  /// instância criada por factories (para dispose posterior).
  void register(
    MGetIt mGetIt, {
    required Injector injector,
    void Function(Object instance)? onFactoryCreated,
  }) {
    T create() => _afterCreate(_register!(injector), null);
    Future<T> createAsync() async =>
        _afterCreate(await _registerAsync!(injector), null);

    switch (type) {
      case BindType.singleton:
        if (dependsOn.isEmpty) {
          mGetIt.registerSingleton<T>(
            create(),
            instanceName: tag,
            dispose: _dispose,
            signalsReady: false,
          );
        } else {
          mGetIt.registerSingletonWithDependencies<T>(
            create,
            instanceName: tag,
            dependsOn: dependsOn,
            dispose: _dispose,
            signalsReady: false,
          );
        }
      case BindType.singletonAsync:
        mGetIt.registerSingletonAsync<T>(
          createAsync,
          instanceName: tag,
          dependsOn: dependsOn.isEmpty ? null : dependsOn,
          dispose: _dispose,
          signalsReady: false,
        );
      case BindType.lazySingleton:
        mGetIt.registerLazySingleton<T>(
          create,
          instanceName: tag,
          dispose: _dispose,
        );
      case BindType.lazySingletonAsync:
        mGetIt.registerLazySingletonAsync<T>(
          createAsync,
          instanceName: tag,
          dispose: _dispose,
        );
      case BindType.factory:
        mGetIt.registerFactory<T>(
          () => _afterCreate(_register!(injector), onFactoryCreated),
          instanceName: tag,
        );
      case BindType.factoryAsync:
        mGetIt.registerFactoryAsync<T>(
          () async =>
              _afterCreate(await _registerAsync!(injector), onFactoryCreated),
          instanceName: tag,
        );
      case BindType.factoryParam:
        throw StateError('factoryParam is handled by _ParamBind');
    }
  }

  /// Remove o bind do [mGetIt], executando o dispose da instância.
  FutureOr<dynamic> unregister(MGetIt mGetIt) {
    if (!mGetIt.isRegistered<T>(instanceName: tag)) return null;
    return mGetIt.unregister<T>(instanceName: tag);
  }

  @override
  String toString() =>
      'Bind<$T>(${type.name}${tag != null ? ', tag: $tag' : ''}'
      '${keepAlive ? ', keepAlive' : ''})';
}

class _ParamBind<T extends Object, P1, P2> extends Bind<T> {
  _ParamBind(this._paramRegister, {super.tag, super.onDispose})
      : super._(type: BindType.factoryParam);

  final BindParamRegister<T, P1, P2> _paramRegister;

  @override
  void register(
    MGetIt mGetIt, {
    required Injector injector,
    void Function(Object instance)? onFactoryCreated,
  }) {
    mGetIt.registerFactoryParam<T, P1, P2>(
      (p1, p2) =>
          _afterCreate(_paramRegister(injector, p1, p2), onFactoryCreated),
      instanceName: tag,
    );
  }
}
