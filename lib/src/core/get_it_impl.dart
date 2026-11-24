// ignore_for_file: avoid_print
part of 'get_it.dart';

const _baseScopeName = 'baseScope';

bool get _isDebugMode {
  var debug = false;
  assert(() {
    debug = true;
    return true;
  }());
  return debug;
}

void _debugOutput(Object message) {
  if (!GetIt.noDebugOutput && _isDebugMode) {
    print(message);
  }
}

void _throwIf(bool condition, Object error) {
  if (condition) throw error;
}

void _throwIfNot(bool condition, Object error) {
  if (!condition) throw error;
}

class _ObjectRegistration<T extends Object, P1, P2>
    implements ObjectRegistration<T> {
  _ObjectRegistration(
    this._getIt,
    this.registrationType, {
    required this.scope,
    this.instanceName,
    this.creationFunction,
    this.asyncCreationFunction,
    this.creationFunctionParam,
    this.asyncCreationFunctionParam,
    T? instance,
    required this.isAsync,
    this.disposeFunction,
    this.onCreatedCallback,
    required this.shouldSignalReady,
    this.useWeakReference = false,
  }) {
    if (instance != null) {
      _setInstance(instance);
    }
  }

  final _GetItImplementation _getIt;
  final _Scope scope;

  @override
  final ObjectRegistrationType registrationType;

  @override
  String? instanceName;

  @override
  final bool isAsync;

  final FactoryFunc<T>? creationFunction;
  final FactoryFuncAsync<T>? asyncCreationFunction;
  final FactoryFuncParam<T, P1, P2>? creationFunctionParam;
  final FactoryFuncParamAsync<T, P1, P2>? asyncCreationFunctionParam;
  final DisposingFunc<T>? disposeFunction;
  final void Function(T instance)? onCreatedCallback;
  final bool shouldSignalReady;
  final bool useWeakReference;

  T? _instance;
  WeakReference<T>? _weakInstance;
  P1? _lastParam1;
  P2? _lastParam2;
  bool _creationInProgress = false;

  Completer<void> readyCompleter = Completer<void>();
  Future<T>? pendingResult;
  int referenceCount = 0;

  /// Tipos que estão aguardando esta instância ficar pronta.
  final List<Type> objectsWaiting = [];

  bool get _usesWeak =>
      useWeakReference ||
      registrationType == ObjectRegistrationType.cachedFactory;

  @override
  T? get instance => _usesWeak ? _weakInstance?.target : _instance;

  void _setInstance(T? value) {
    if (_usesWeak) {
      _weakInstance = value == null ? null : WeakReference(value);
    } else {
      _instance = value;
    }
  }

  @override
  bool get acceptsParams =>
      creationFunctionParam != null || asyncCreationFunctionParam != null;

  @override
  Type get registeredWithType => T;

  @override
  bool get isReady => readyCompleter.isCompleted;

  @override
  bool get isNamedRegistration => instanceName != null;

  @override
  String get debugName => '$instanceName : $registeredWithType';

  @override
  bool get canBeWaitedFor =>
      shouldSignalReady || pendingResult != null || isAsync;

  bool isSubtypeOf<S>() => <T>[] is List<S>;

  void _markReady() {
    if (!readyCompleter.isCompleted) {
      readyCompleter.complete();
    }
    objectsWaiting.clear();
  }

  void _notifyShadowed(T newInstance) {
    final shadowed = _getIt._findLowerRegistration(this)?.instance;
    if (shadowed is ShadowChangeHandlers) {
      shadowed.onGetShadowed(newInstance);
    }
  }

  void _notifyLeaveShadow() {
    final current = instance;
    if (current == null) return;
    final shadowed = _getIt._findLowerRegistration(this)?.instance;
    if (shadowed is ShadowChangeHandlers) {
      shadowed.onLeaveShadow(current);
    }
  }

  void _validateFactoryParams(dynamic param1, dynamic param2) {
    if (param1 != null || <P1?>[] is! List<P1>) {
      if (param1 is! P1) {
        throw ArgumentError(
          "GetIt: Cannot use parameter value of type '${param1.runtimeType}' "
          "as type '$P1' for factory of type '$T'.",
        );
      }
    }
    if (param2 != null || <P2?>[] is! List<P2>) {
      if (param2 is! P2) {
        throw ArgumentError(
          "GetIt: Cannot use parameter value of type '${param2.runtimeType}' "
          "as type '$P2' for factory of type '$T'.",
        );
      }
    }
  }

  Never _throwCircular() {
    final named = instanceName != null ? ' (instanceName: "$instanceName")' : '';
    throw StateError(
      'GetIt: Circular dependency detected while creating $T$named.',
    );
  }

  R _guardCreation<R>(R Function() create) {
    if (_creationInProgress) _throwCircular();
    _creationInProgress = true;
    try {
      return create();
    } finally {
      _creationInProgress = false;
    }
  }

  T _createSync(dynamic param1, dynamic param2) {
    if (creationFunctionParam != null) {
      _validateFactoryParams(param1, param2);
      _lastParam1 = param1 as P1?;
      _lastParam2 = param2 as P2?;
      return creationFunctionParam!(param1 as P1, param2 as P2);
    }
    return creationFunction!();
  }

  Future<T> _createAsync(dynamic param1, dynamic param2) {
    if (asyncCreationFunctionParam != null) {
      _validateFactoryParams(param1, param2);
      _lastParam1 = param1 as P1?;
      _lastParam2 = param2 as P2?;
      return asyncCreationFunctionParam!(param1 as P1, param2 as P2);
    }
    return asyncCreationFunction!();
  }

  bool _sameParams(dynamic param1, dynamic param2) =>
      param1 == _lastParam1 && param2 == _lastParam2;

  T getObject(dynamic param1, dynamic param2) {
    assert(
      acceptsParams || (param1 == null && param2 == null),
      'You passed parameters when accessing $T, but it is not registered '
      'with a param factory. Parameters would be ignored.',
    );

    if (isAsync || pendingResult != null) {
      _throwIf(
        registrationType == ObjectRegistrationType.alwaysNew ||
            registrationType == ObjectRegistrationType.cachedFactory,
        StateError(
          'GetIt: $T is registered as an async factory, use getAsync<$T>() instead.',
        ),
      );
      final current = instance;
      _throwIf(
        current == null || !isReady && !shouldSignalReady,
        StateError(
          'GetIt: You tried to access an instance of $T that is not ready yet',
        ),
      );
      return current!;
    }

    try {
      switch (registrationType) {
        case ObjectRegistrationType.alwaysNew:
          return _createSync(param1, param2);
        case ObjectRegistrationType.cachedFactory:
          final cached = instance;
          if (cached != null && _sameParams(param1, param2)) return cached;
          final created = _guardCreation(() => _createSync(param1, param2));
          _setInstance(created);
          return created;
        case ObjectRegistrationType.constant:
          return instance!;
        case ObjectRegistrationType.lazy:
          final existing = instance;
          if (existing != null) return existing;
          if (useWeakReference && readyCompleter.isCompleted) {
            readyCompleter = Completer<void>();
          }
          final created = _guardCreation(() => creationFunction!());
          _setInstance(created);
          _markReady();
          onCreatedCallback?.call(created);
          _notifyShadowed(created);
          return created;
      }
    } catch (e, s) {
      _debugOutput('GetIt: Error while creating $T\n$e\n$s');
      rethrow;
    }
  }

  Future<R> getObjectAsync<R>(dynamic param1, dynamic param2) {
    assert(
      acceptsParams || (param1 == null && param2 == null),
      'You passed parameters when accessing $T, but it is not registered '
      'with a param factory. Parameters would be ignored.',
    );

    // Registros síncronos também podem ser obtidos via getAsync.
    if (!isAsync && pendingResult == null) {
      return Future<R>.value(getObject(param1, param2) as R);
    }

    switch (registrationType) {
      case ObjectRegistrationType.alwaysNew:
        return _createAsync(param1, param2) as Future<R>;
      case ObjectRegistrationType.cachedFactory:
        final cached = instance;
        if (cached != null && _sameParams(param1, param2)) {
          return Future<R>.value(cached as R);
        }
        return _guardCreation(() => _createAsync(param1, param2)).then((value) {
          _setInstance(value);
          return value as R;
        });
      case ObjectRegistrationType.constant:
        final current = instance;
        if (current != null && (isReady || shouldSignalReady)) {
          return Future<R>.value(current as R);
        }
        return pendingResult!.then((value) => value as R);
      case ObjectRegistrationType.lazy:
        final current = instance;
        if (current != null) return Future<R>.value(current as R);
        if (pendingResult != null) {
          return pendingResult!.then((value) => value as R);
        }
        if (useWeakReference && readyCompleter.isCompleted) {
          readyCompleter = Completer<void>();
        }
        final future = _guardCreation(() => asyncCreationFunction!());
        pendingResult = future.then((created) {
          _setInstance(created);
          pendingResult = null;
          if (!shouldSignalReady) _markReady();
          onCreatedCallback?.call(created);
          _notifyShadowed(created);
          return created;
        });
        return pendingResult!.then((value) => value as R);
    }
  }

  FutureOr<void> dispose({FutureOr Function(T)? overrideDispose}) {
    final current = instance;
    if (current == null) return null;
    if (overrideDispose != null) return overrideDispose(current);
    if (disposeFunction != null) return disposeFunction!(current);
    if (current is Disposable) return current.onDispose();
    return null;
  }

  /// Usado pelo `unregister`, permitindo receber a função de dispose sem tipo.
  FutureOr<void> disposeWithDynamic(Function? overrideDispose) {
    if (overrideDispose == null) return dispose();
    return dispose(overrideDispose: (T value) => Function.apply(overrideDispose, [value]));
  }

  void resetInstance() {
    _setInstance(null);
    pendingResult = null;
    readyCompleter = Completer<void>();
  }

  @override
  String toString() =>
      'ObjectRegistration<$T>(type: $registrationType, name: $instanceName, '
      'ready: $isReady)';
}

class _TypeRegistration {
  final List<_ObjectRegistration> registrations = [];
  final LinkedHashMap<String, _ObjectRegistration> namedRegistrations =
      LinkedHashMap();

  bool get isEmpty => registrations.isEmpty && namedRegistrations.isEmpty;

  Iterable<_ObjectRegistration> get all =>
      [...registrations, ...namedRegistrations.values];

  _ObjectRegistration? find(String? name) =>
      name != null ? namedRegistrations[name] : registrations.firstOrNull;

  void remove(_ObjectRegistration registration) {
    if (registration.instanceName != null) {
      namedRegistrations.remove(registration.instanceName);
    } else {
      registrations.remove(registration);
    }
  }
}

class _Scope {
  _Scope({required this.name, this.disposeFunc});

  final String name;
  final ScopeDisposeFunc? disposeFunc;
  bool isFinal = false;
  bool isPopping = false;

  final LinkedHashMap<Type, _TypeRegistration> typeRegistrations =
      LinkedHashMap();

  /// Ordem de registro (usada para dispose em ordem reversa).
  final List<_ObjectRegistration> ordered = [];

  Iterable<_ObjectRegistration> get allRegistrations => ordered;

  void add(Type type, _ObjectRegistration registration) {
    final typeRegistration =
        typeRegistrations.putIfAbsent(type, _TypeRegistration.new);
    if (registration.instanceName != null) {
      typeRegistration.namedRegistrations[registration.instanceName!] =
          registration;
    } else {
      typeRegistration.registrations.add(registration);
    }
    ordered.add(registration);
  }

  void remove(Type type, _ObjectRegistration registration) {
    final typeRegistration = typeRegistrations[type];
    if (typeRegistration == null) return;
    typeRegistration.remove(registration);
    if (typeRegistration.isEmpty) typeRegistrations.remove(type);
    ordered.remove(registration);
  }

  Future<void> reset({required bool dispose}) async {
    if (dispose) {
      for (final registration in ordered.reversed.toList()) {
        registration._notifyLeaveShadow();
        await registration.dispose();
      }
    }
    typeRegistrations.clear();
    ordered.clear();
  }

  Future<void> runDispose() async {
    await disposeFunc?.call();
  }
}

class _GetItImplementation implements GetIt {
  _GetItImplementation() {
    _scopes.add(_Scope(name: _baseScopeName));
  }

  final List<_Scope> _scopes = [];

  _Scope get _currentScope => _scopes.last;

  @override
  void Function(bool pushed)? onScopeChanged;

  @override
  bool debugEventsEnabled = false;

  @override
  bool allowReassignment = false;

  @override
  bool skipDoubleRegistration = false;

  @override
  bool skipUnregisterIfNotRegistered = false;

  @override
  bool allowRegisterMultipleImplementationsOfoneType = false;

  @override
  void enableRegisteringMultipleInstancesOfOneType() {
    allowRegisterMultipleImplementationsOfoneType = true;
  }

  void _postEvent(String kind, Map<String, Object?> data) {
    if (debugEventsEnabled) {
      developer.postEvent('ext.get_it.$kind', data);
    }
  }

  // ---------------------------------------------------------------------------
  // Busca de registros
  // ---------------------------------------------------------------------------

  _ObjectRegistration? _findRegistrationOrNull(
    String? instanceName,
    Type type, {
    int? startScopeIndex,
  }) {
    for (var i = startScopeIndex ?? _scopes.length - 1; i >= 0; i--) {
      final registration = _scopes[i].typeRegistrations[type]?.find(instanceName);
      if (registration != null) return registration;
    }
    return null;
  }

  _ObjectRegistration? _findByInstanceOrNull(Object instance) {
    for (final scope in _scopes.reversed) {
      for (final registration in scope.allRegistrations) {
        if (identical(registration.instance, instance)) return registration;
      }
    }
    return null;
  }

  /// Encontra o registro de mesmo tipo/nome no escopo abaixo de [registration].
  _ObjectRegistration? _findLowerRegistration(_ObjectRegistration registration) {
    final scopeIndex = _scopes.indexOf(registration.scope);
    if (scopeIndex <= 0) return null;
    return _findRegistrationOrNull(
      registration.instanceName,
      registration.registeredWithType,
      startScopeIndex: scopeIndex - 1,
    );
  }

  _ObjectRegistration _findRegistration<T extends Object>({
    Object? instance,
    String? instanceName,
    Type? type,
  }) {
    final registration = instance != null
        ? _findByInstanceOrNull(instance)
        : _findRegistrationOrNull(instanceName, type ?? T);
    if (registration == null) {
      final lookup = instance != null
          ? 'This instance of type ${instance.runtimeType}'
          : 'Object/factory with ${instanceName != null ? 'name $instanceName and ' : ''}'
              'type ${type ?? T}';
      throw StateError(
        'GetIt: $lookup is not registered inside GetIt.\n'
        '(Did you accidentally do GetIt sl=GetIt.instance(); instead of '
        'GetIt sl=GetIt.instance;\nDid you forget to register it?)',
      );
    }
    return registration;
  }

  // ---------------------------------------------------------------------------
  // Recuperação
  // ---------------------------------------------------------------------------

  @override
  T get<T extends Object>({
    dynamic param1,
    dynamic param2,
    String? instanceName,
    Type? type,
  }) {
    final registration =
        _findRegistration<T>(instanceName: instanceName, type: type);
    final object = registration.getObject(param1, param2);
    _postEvent('get', {'type': '${type ?? T}', 'instanceName': instanceName});
    return object as T;
  }

  @override
  T? maybeGet<T extends Object>({
    dynamic param1,
    dynamic param2,
    String? instanceName,
    Type? type,
  }) {
    final registration = _findRegistrationOrNull(instanceName, type ?? T);
    if (registration == null) return null;
    return registration.getObject(param1, param2) as T;
  }

  @override
  T call<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) =>
      get<T>(
        instanceName: instanceName,
        param1: param1,
        param2: param2,
        type: type,
      );

  @override
  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    final registration =
        _findRegistration<T>(instanceName: instanceName, type: type);
    return registration.getObjectAsync<T>(param1, param2);
  }

  Iterable<_ObjectRegistration> _registrationsForGetAll<T extends Object>({
    required bool fromAllScopes,
    String? onlyInScope,
  }) {
    final result = <_ObjectRegistration>[];
    if (onlyInScope != null) {
      final scope = _scopes.where((s) => s.name == onlyInScope).firstOrNull;
      _throwIf(
        scope == null,
        StateError('GetIt: Scope with name $onlyInScope does not exist'),
      );
      result.addAll(scope!.typeRegistrations[T]?.all ?? const []);
    } else if (fromAllScopes) {
      for (final scope in _scopes.reversed) {
        result.addAll(scope.typeRegistrations[T]?.all ?? const []);
      }
    } else {
      for (final scope in _scopes.reversed) {
        final regs = scope.typeRegistrations[T];
        if (regs != null && !regs.isEmpty) {
          result.addAll(regs.all);
          break;
        }
      }
    }
    _throwIf(
      result.isEmpty,
      StateError('GetIt: No Objects/factories with type $T are registered inside GetIt.'),
    );
    return result;
  }

  @override
  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
    String? onlyInScope,
  }) {
    return _registrationsForGetAll<T>(
      fromAllScopes: fromAllScopes,
      onlyInScope: onlyInScope,
    ).map((r) => r.getObject(param1, param2) as T).toList();
  }

  @override
  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
    String? onlyInScope,
  }) {
    final registrations = _registrationsForGetAll<T>(
      fromAllScopes: fromAllScopes,
      onlyInScope: onlyInScope,
    );
    return Future.wait(
      registrations.map((r) => r.getObjectAsync<T>(param1, param2)),
    );
  }

  @override
  List<T> findAll<T extends Object>({
    bool includeSubtypes = true,
    bool inAllScopes = false,
    String? onlyInScope,
    bool includeMatchedByRegistrationType = true,
    bool includeMatchedByInstance = true,
    bool instantiateLazySingletons = false,
    bool callFactories = false,
  }) {
    final Iterable<_Scope> scopes;
    if (onlyInScope != null) {
      scopes = _scopes.where((s) => s.name == onlyInScope);
      _throwIf(
        scopes.isEmpty,
        StateError('GetIt: Scope with name $onlyInScope does not exist'),
      );
    } else if (inAllScopes) {
      scopes = _scopes.reversed;
    } else {
      scopes = [_currentScope];
    }

    final result = <T>[];
    final seen = HashSet<Object>.identity();
    void add(Object? object) {
      if (object is T && seen.add(object)) result.add(object);
    }

    for (final scope in scopes) {
      for (final registration in scope.allRegistrations) {
        final current = registration.instance;
        final typeMatches = includeMatchedByRegistrationType &&
            (includeSubtypes
                ? registration.isSubtypeOf<T>()
                : registration.registeredWithType == T);
        final instanceMatches = includeMatchedByInstance &&
            current != null &&
            (includeSubtypes ? current is T : current.runtimeType == T);

        if (!typeMatches && !instanceMatches) continue;

        if (current != null) {
          add(current);
          continue;
        }
        if (!typeMatches || registration.isAsync) continue;
        switch (registration.registrationType) {
          case ObjectRegistrationType.lazy:
            if (instantiateLazySingletons) add(registration.getObject(null, null));
          case ObjectRegistrationType.alwaysNew:
          case ObjectRegistrationType.cachedFactory:
            if (callFactories && !registration.acceptsParams) {
              add(registration.getObject(null, null));
            }
          case ObjectRegistrationType.constant:
            break;
        }
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Registro
  // ---------------------------------------------------------------------------

  @override
  void registerFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) =>
      _register<T, void, void>(
        type: ObjectRegistrationType.alwaysNew,
        instanceName: instanceName,
        factoryFunc: factoryFunc,
        isAsync: false,
        shouldSignalReady: false,
      );

  @override
  void registerCachedFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) =>
      _register<T, void, void>(
        type: ObjectRegistrationType.cachedFactory,
        instanceName: instanceName,
        factoryFunc: factoryFunc,
        isAsync: false,
        shouldSignalReady: false,
      );

  @override
  void registerFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) =>
      _register<T, P1, P2>(
        type: ObjectRegistrationType.alwaysNew,
        instanceName: instanceName,
        factoryFuncParam: factoryFunc,
        isAsync: false,
        shouldSignalReady: false,
      );

  @override
  void registerCachedFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) =>
      _register<T, P1, P2>(
        type: ObjectRegistrationType.cachedFactory,
        instanceName: instanceName,
        factoryFuncParam: factoryFunc,
        isAsync: false,
        shouldSignalReady: false,
      );

  @override
  void registerFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  }) =>
      _register<T, void, void>(
        type: ObjectRegistrationType.alwaysNew,
        instanceName: instanceName,
        factoryFuncAsync: factoryFunc,
        isAsync: true,
        shouldSignalReady: false,
      );

  @override
  void registerCachedFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  }) =>
      _register<T, void, void>(
        type: ObjectRegistrationType.cachedFactory,
        instanceName: instanceName,
        factoryFuncAsync: factoryFunc,
        isAsync: true,
        shouldSignalReady: false,
      );

  @override
  void registerFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  }) =>
      _register<T, P1?, P2?>(
        type: ObjectRegistrationType.alwaysNew,
        instanceName: instanceName,
        factoryFuncParamAsync: factoryFunc,
        isAsync: true,
        shouldSignalReady: false,
      );

  @override
  void registerCachedFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  }) =>
      _register<T, P1?, P2?>(
        type: ObjectRegistrationType.cachedFactory,
        instanceName: instanceName,
        factoryFuncParamAsync: factoryFunc,
        isAsync: true,
        shouldSignalReady: false,
      );

  @override
  T registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      type: ObjectRegistrationType.constant,
      instanceName: instanceName,
      instance: instance,
      isAsync: false,
      shouldSignalReady: signalsReady ?? instance is WillSignalReady,
      disposeFunc: dispose,
    );
    return instance;
  }

  @override
  T registerSingletonIfAbsent<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  }) {
    final existing = _findRegistrationOrNull(instanceName, T);
    if (existing != null) {
      _throwIf(
        existing.registrationType != ObjectRegistrationType.constant ||
            existing.isAsync,
        StateError(
          'GetIt: registerSingletonIfAbsent found an existing registration of '
          '$T that is not a (sync) singleton.',
        ),
      );
      existing.referenceCount++;
      return existing.instance! as T;
    }
    return registerSingleton<T>(
      factoryFunc(),
      instanceName: instanceName,
      dispose: dispose,
    );
  }

  @override
  void releaseInstance(Object instance) {
    final registration = _findRegistration<Object>(instance: instance);
    if (registration.referenceCount < 1) {
      unregister<Object>(instance: instance);
    } else {
      registration.referenceCount--;
    }
  }

  @override
  void registerSingletonWithDependencies<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    required Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) =>
      _register<T, void, void>(
        type: ObjectRegistrationType.constant,
        instanceName: instanceName,
        factoryFunc: factoryFunc,
        isAsync: false,
        dependsOn: dependsOn,
        shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
        disposeFunc: dispose,
      );

  @override
  void registerSingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
  }) =>
      _register<T, void, void>(
        type: ObjectRegistrationType.constant,
        instanceName: instanceName,
        factoryFuncAsync: factoryFunc,
        isAsync: true,
        dependsOn: dependsOn,
        shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
        disposeFunc: dispose,
        onCreatedFunc: onCreated,
      );

  @override
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
    bool useWeakReference = false,
  }) =>
      _register<T, void, void>(
        type: ObjectRegistrationType.lazy,
        instanceName: instanceName,
        factoryFunc: factoryFunc,
        isAsync: false,
        shouldSignalReady: false,
        disposeFunc: dispose,
        onCreatedFunc: onCreated,
        useWeakReference: useWeakReference,
      );

  @override
  void registerLazySingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
    bool useWeakReference = false,
  }) =>
      _register<T, void, void>(
        type: ObjectRegistrationType.lazy,
        instanceName: instanceName,
        factoryFuncAsync: factoryFunc,
        isAsync: true,
        shouldSignalReady: false,
        disposeFunc: dispose,
        onCreatedFunc: onCreated,
        useWeakReference: useWeakReference,
      );

  _Scope _registrationScope() {
    var i = _scopes.length - 1;
    var scope = _scopes[i];
    while (scope.isFinal && i > 0) {
      i--;
      scope = _scopes[i];
    }
    _throwIf(
      scope.isFinal,
      StateError(
        'GetIt: The scope has already been finalized, you cannot register '
        'objects in it.',
      ),
    );
    return scope;
  }

  void _register<T extends Object, P1, P2>({
    required ObjectRegistrationType type,
    FactoryFunc<T>? factoryFunc,
    FactoryFuncParam<T, P1, P2>? factoryFuncParam,
    FactoryFuncAsync<T>? factoryFuncAsync,
    FactoryFuncParamAsync<T, P1, P2>? factoryFuncParamAsync,
    T? instance,
    required String? instanceName,
    required bool isAsync,
    Iterable<Type>? dependsOn,
    required bool shouldSignalReady,
    DisposingFunc<T>? disposeFunc,
    void Function(T instance)? onCreatedFunc,
    bool useWeakReference = false,
  }) {
    _throwIf(
      T == Object,
      ArgumentError(
        'GetIt: You have to provide type. Did you accidentally do '
        '`var sl=GetIt.instance();` instead of `var sl=GetIt.instance;`',
      ),
    );

    final scope = _registrationScope();
    final existingTypeRegistration = scope.typeRegistrations[T];

    if (instanceName != null) {
      final existing = existingTypeRegistration?.namedRegistrations[instanceName];
      if (existing != null) {
        if (skipDoubleRegistration && !allowReassignment) return;
        _throwIfNot(
          allowReassignment,
          ArgumentError(
            'GetIt: Object/factory with name $instanceName and type $T is '
            'already registered inside GetIt.',
          ),
        );
        scope.remove(T, existing);
      }
    } else if (existingTypeRegistration != null &&
        existingTypeRegistration.registrations.isNotEmpty) {
      if (!allowRegisterMultipleImplementationsOfoneType) {
        if (skipDoubleRegistration && !allowReassignment) return;
        _throwIfNot(
          allowReassignment,
          ArgumentError('GetIt: Type $T is already registered inside GetIt.'),
        );
        for (final old in existingTypeRegistration.registrations.toList()) {
          scope.remove(T, old);
        }
      }
    }

    final registration = _ObjectRegistration<T, P1, P2>(
      this,
      type,
      scope: scope,
      instanceName: instanceName,
      creationFunction: factoryFunc,
      creationFunctionParam: factoryFuncParam,
      asyncCreationFunction: factoryFuncAsync,
      asyncCreationFunctionParam: factoryFuncParamAsync,
      instance: instance,
      isAsync: isAsync,
      disposeFunction: disposeFunc,
      onCreatedCallback: onCreatedFunc,
      shouldSignalReady: shouldSignalReady,
      useWeakReference: useWeakReference,
    );

    scope.add(T, registration);
    _postEvent('register', {
      'type': '$T',
      'instanceName': instanceName,
      'registrationType': type.name,
    });

    // Singleton síncrono simples.
    if (instance != null) {
      if (!shouldSignalReady) registration._markReady();
      registration._notifyShadowed(instance);
      return;
    }

    // Só singletons com criação "eager" (constant) daqui em diante.
    if (type != ObjectRegistrationType.constant) return;

    final Future<void> dependenciesReady;
    if (dependsOn != null && dependsOn.isNotEmpty) {
      final waitFor = <Future<void>>[];
      for (final dependency in dependsOn) {
        Type dependencyType = dependency;
        String? dependencyName;
        if (dependency is InitDependency) {
          dependencyType = dependency.type;
          dependencyName = dependency.instanceName;
        }
        final dependencyRegistration =
            _findRegistrationOrNull(dependencyName, dependencyType);
        _throwIf(
          dependencyRegistration == null,
          ArgumentError(
            'GetIt: Dependent Type $dependency is not registered in GetIt',
          ),
        );
        _throwIfNot(
          dependencyRegistration!.canBeWaitedFor,
          ArgumentError(
            'GetIt: Dependent Type $dependency is not an async Singleton',
          ),
        );
        dependencyRegistration.objectsWaiting.add(T);
        waitFor.add(dependencyRegistration.readyCompleter.future);
      }
      dependenciesReady = Future.wait(waitFor);
    } else {
      dependenciesReady = Future<void>.value();
    }

    final Future<T> creation = dependenciesReady.then((_) {
      if (isAsync) return factoryFuncAsync!();
      return factoryFunc!();
    });

    registration.pendingResult = creation.then((created) {
      // O registro pode ter sido removido enquanto a criação estava pendente.
      registration._setInstance(created);
      onCreatedFunc?.call(created);
      registration._notifyShadowed(created);
      if (!shouldSignalReady) registration._markReady();
      return created;
    });

    registration.pendingResult!.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _debugOutput('GetIt: Error while creating $T: $error');
        if (!registration.readyCompleter.isCompleted) {
          registration.readyCompleter.completeError(error, stackTrace);
          registration.readyCompleter.future.ignore();
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Consulta / manutenção
  // ---------------------------------------------------------------------------

  @override
  ObjectRegistration? findFirstObjectRegistration<T extends Object>({
    Object? instance,
    String? instanceName,
  }) {
    if (instance != null) return _findByInstanceOrNull(instance);
    return _findRegistrationOrNull(instanceName, T);
  }

  @override
  bool isRegistered<T extends Object>({
    Object? instance,
    String? instanceName,
    Type? type,
  }) {
    if (instance != null) return _findByInstanceOrNull(instance) != null;
    return _findRegistrationOrNull(instanceName, type ?? T) != null;
  }

  @override
  void changeTypeInstanceName<T extends Object>({
    String? instanceName,
    required String newInstanceName,
    T? instance,
  }) {
    final registration = _findRegistration<T>(
      instance: instance,
      instanceName: instanceName,
    );
    final type = registration.registeredWithType;
    _throwIf(
      registration.scope.typeRegistrations[type]?.namedRegistrations
              .containsKey(newInstanceName) ??
          false,
      StateError(
        'GetIt: There is already an instance of type $type registered with '
        'the name $newInstanceName',
      ),
    );
    registration.scope.remove(type, registration);
    registration.instanceName = newInstanceName;
    registration.scope.add(type, registration);
  }

  @override
  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
    bool ignoreReferenceCount = false,
  }) {
    final registration = instance != null
        ? _findByInstanceOrNull(instance)
        : _findRegistrationOrNull(instanceName, T);

    if (registration == null) {
      if (skipUnregisterIfNotRegistered) return null;
      throw ArgumentError(
        'GetIt: No object with name $instanceName and type $T is registered '
        'inside GetIt.',
      );
    }

    if (registration.referenceCount > 0 && !ignoreReferenceCount) {
      registration.referenceCount--;
      return null;
    }

    _throwIf(
      registration.objectsWaiting.isNotEmpty,
      StateError(
        'GetIt: There are still other objects waiting for this instance so '
        'signal ready: ${registration.objectsWaiting}',
      ),
    );

    registration._notifyLeaveShadow();
    registration.scope.remove(registration.registeredWithType, registration);
    _postEvent('unregister', {
      'type': '${registration.registeredWithType}',
      'instanceName': registration.instanceName,
    });

    if (!registration.readyCompleter.isCompleted) {
      registration.readyCompleter.complete();
    }

    return registration.disposeWithDynamic(disposingFunction);
  }

  @override
  FutureOr resetLazySingleton<T extends Object>({
    T? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  }) {
    final registration =
        _findRegistration<T>(instance: instance, instanceName: instanceName);
    _throwIfNot(
      registration.registrationType == ObjectRegistrationType.lazy,
      StateError('GetIt: There is no lazy singleton of type $T registered.'),
    );
    final result = registration.disposeWithDynamic(disposingFunction);
    if (result is Future) {
      return result.then((_) => registration.resetInstance());
    }
    registration.resetInstance();
    return null;
  }

  @override
  Future<void> resetLazySingletons({
    bool dispose = true,
    bool inAllScopes = false,
    String? onlyInScope,
  }) async {
    final Iterable<_Scope> scopes;
    if (onlyInScope != null) {
      scopes = _scopes.where((s) => s.name == onlyInScope);
      _throwIf(
        scopes.isEmpty,
        StateError('GetIt: Scope with name $onlyInScope does not exist'),
      );
    } else if (inAllScopes) {
      scopes = _scopes.reversed;
    } else {
      scopes = [_currentScope];
    }
    for (final scope in scopes.toList()) {
      for (final registration in scope.allRegistrations.toList()) {
        if (registration.registrationType != ObjectRegistrationType.lazy) {
          continue;
        }
        if (dispose) await registration.dispose();
        registration.resetInstance();
      }
    }
  }

  @override
  bool checkLazySingletonInstanceExists<T extends Object>({
    String? instanceName,
  }) {
    final registration = _findRegistration<T>(instanceName: instanceName);
    _throwIfNot(
      registration.registrationType == ObjectRegistrationType.lazy,
      StateError('GetIt: $T is not a lazy singleton.'),
    );
    return registration.instance != null;
  }

  @override
  Future<void> reset({bool dispose = true}) async {
    for (final scope in _scopes.reversed.toList()) {
      if (dispose) await scope.runDispose();
      await scope.reset(dispose: dispose);
    }
    _scopes
      ..clear()
      ..add(_Scope(name: _baseScopeName));
  }

  @override
  Future<void> resetScope({bool dispose = true}) async {
    if (dispose) await _currentScope.runDispose();
    await _currentScope.reset(dispose: dispose);
  }

  // ---------------------------------------------------------------------------
  // Escopos
  // ---------------------------------------------------------------------------

  void _checkScopeName(String? scopeName) {
    _throwIf(
      scopeName != null && hasScope(scopeName),
      ArgumentError('GetIt: You already have used the scope name $scopeName'),
    );
    _throwIf(
      _currentScope.isPopping,
      StateError('GetIt: You cannot push a new scope while popping one.'),
    );
  }

  @override
  void pushNewScope({
    void Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal = false,
  }) {
    _checkScopeName(scopeName);
    final scope = _Scope(
      name: scopeName ?? 'scope_${_scopes.length}',
      disposeFunc: dispose,
    );
    _scopes.add(scope);
    try {
      init?.call(this);
    } finally {
      scope.isFinal = isFinal;
    }
    onScopeChanged?.call(true);
  }

  @override
  Future<void> pushNewScopeAsync({
    Future<void> Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
  }) async {
    _checkScopeName(scopeName);
    _scopes.add(
      _Scope(name: scopeName ?? 'scope_${_scopes.length}', disposeFunc: dispose),
    );
    await init?.call(this);
    onScopeChanged?.call(true);
  }

  Future<void> _disposeScope(_Scope scope) async {
    scope.isPopping = true;
    await scope.runDispose();
    await scope.reset(dispose: true);
  }

  @override
  Future<void> popScope() async {
    _throwIf(
      _scopes.length == 1,
      StateError("GetIt: You are already on the base scope. you can't pop this one"),
    );
    final scope = _currentScope;
    await _disposeScope(scope);
    _scopes.remove(scope);
    onScopeChanged?.call(false);
  }

  @override
  Future<bool> popScopesTill(String name, {bool inclusive = true}) async {
    _throwIf(
      name == _baseScopeName && inclusive,
      StateError("GetIt: You can't pop the base scope"),
    );
    if (!hasScope(name)) return false;
    String? popped;
    do {
      popped = _currentScope.name;
      if (popped == name && !inclusive) break;
      await popScope();
    } while (popped != name);
    return true;
  }

  @override
  Future<void> dropScope(String scopeName) async {
    if (currentScopeName == scopeName) return popScope();
    _throwIf(
      scopeName == _baseScopeName,
      StateError("GetIt: You can't drop the base scope"),
    );
    final scope = _scopes.where((s) => s.name == scopeName).firstOrNull;
    _throwIf(
      scope == null,
      ArgumentError('GetIt: Scope $scopeName not found'),
    );
    await _disposeScope(scope!);
    _scopes.remove(scope);
  }

  @override
  bool hasScope(String scopeName) => _scopes.any((s) => s.name == scopeName);

  @override
  String? get currentScopeName => _currentScope.name;

  // ---------------------------------------------------------------------------
  // Prontidão (async / signalReady)
  // ---------------------------------------------------------------------------

  Iterable<_ObjectRegistration> get _allRegistrations =>
      _scopes.expand((s) => s.allRegistrations);

  bool _isPending(_ObjectRegistration r, bool ignorePendingAsyncCreation) {
    if (r.isReady) return false;
    if (r.shouldSignalReady) return true;
    return !ignorePendingAsyncCreation && r.pendingResult != null;
  }

  @override
  Future<void> allReady({
    Duration? timeout,
    bool ignorePendingAsyncCreation = false,
  }) {
    final futures = _allRegistrations
        .where((r) => _isPending(r, ignorePendingAsyncCreation))
        .map((r) => r.readyCompleter.future)
        .toList();
    final all = Future.wait(futures);
    if (timeout == null) return all;
    return all.timeout(timeout, onTimeout: () => throw _timeoutException());
  }

  WaitingTimeOutException _timeoutException() {
    final waitable = _allRegistrations.where((r) => r.canBeWaitedFor);
    final areWaitedBy = <String, List<String>>{
      for (final r in waitable.where((r) => r.objectsWaiting.isNotEmpty))
        r.debugName: r.objectsWaiting.map((t) => '$t').toList(),
    };
    return WaitingTimeOutException(
      areWaitedBy,
      waitable.where((r) => !r.isReady).map((r) => r.debugName).toList(),
      waitable.where((r) => r.isReady).map((r) => r.debugName).toList(),
    );
  }

  @override
  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  }) {
    final registration =
        _findRegistration<T>(instance: instance, instanceName: instanceName);
    _throwIfNot(
      registration.canBeWaitedFor,
      ArgumentError(
        'GetIt: You only can use this function on async Singletons or '
        'Singletons that have been marked with "signalsReady" or that they '
        'depend on others',
      ),
    );
    if (callee != null) registration.objectsWaiting.add(callee.runtimeType);

    Future<void> future;
    if (registration.registrationType == ObjectRegistrationType.lazy &&
        registration.isAsync &&
        registration.instance == null &&
        registration.pendingResult == null) {
      // Lazy async ainda não criado: dispara a criação.
      future = registration.getObjectAsync<Object>(null, null).then((_) {});
    } else if (registration.pendingResult != null &&
        !registration.shouldSignalReady) {
      future = registration.pendingResult!;
    } else {
      future = registration.readyCompleter.future;
    }
    if (timeout == null) return future;
    return future.timeout(timeout, onTimeout: () => throw _timeoutException());
  }

  @override
  bool isReadySync<T extends Object>({Object? instance, String? instanceName}) {
    final registration =
        _findRegistration<T>(instance: instance, instanceName: instanceName);
    _throwIfNot(
      registration.canBeWaitedFor,
      ArgumentError(
        'GetIt: You only can use this function on async Singletons or '
        'Singletons that have been marked with "signalsReady" or that they '
        'depend on others',
      ),
    );
    return registration.isReady;
  }

  @override
  bool allReadySync([bool ignorePendingAsyncCreation = false]) =>
      !_allRegistrations.any((r) => _isPending(r, ignorePendingAsyncCreation));

  @override
  void signalReady(Object? instance) {
    if (instance == null) {
      final notReady = _allRegistrations
          .where((r) => r.shouldSignalReady && !r.isReady)
          .map((r) => r.debugName)
          .toList();
      _throwIf(
        notReady.isNotEmpty,
        StateError(
          'GetIt: Registered types/names $notReady should signal ready but '
          'are not ready',
        ),
      );
      return;
    }
    final registration = _findByInstanceOrNull(instance);
    _throwIf(
      registration == null,
      ArgumentError(
        'GetIt: This instance of type ${instance.runtimeType} is not available in GetIt',
      ),
    );
    _throwIfNot(
      registration!.shouldSignalReady,
      ArgumentError(
        'GetIt: This instance of type ${instance.runtimeType} is not supposed '
        'to signal ready.',
      ),
    );
    _throwIf(
      registration.isReady,
      StateError(
        'GetIt: This instance of type ${instance.runtimeType} was already '
        'signalled',
      ),
    );
    registration._markReady();
  }
}
