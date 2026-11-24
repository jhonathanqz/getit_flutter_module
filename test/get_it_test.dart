import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getit_modular/getit_modular.dart';

abstract class Service {}

class ServiceImpl implements Service {}

class Counter {
  static int created = 0;
  Counter() {
    created++;
  }
}

class DisposableService with Disposable {
  bool disposed = false;
  @override
  FutureOr onDispose() => disposed = true;
}

class Signaller implements WillSignalReady {}

class ShadowAware with ShadowChangeHandlers {
  Object? shadowedBy;
  bool left = false;
  @override
  void onGetShadowed(Object shadowing) => shadowedBy = shadowing;
  @override
  void onLeaveShadow(Object shadowing) => left = true;
}

class Param {
  Param(this.a, this.b);
  final String a;
  final int? b;
}

void main() {
  late GetIt getIt;

  setUp(() {
    getIt = GetIt.asNewInstance();
    Counter.created = 0;
  });

  group('registro e get', () {
    test('factory cria nova instância a cada get', () {
      getIt.registerFactory<Counter>(Counter.new);
      expect(identical(getIt<Counter>(), getIt<Counter>()), isFalse);
      expect(Counter.created, 2);
    });

    test('singleton retorna sempre a mesma instância', () {
      final instance = getIt.registerSingleton<Service>(ServiceImpl());
      expect(getIt<Service>(), same(instance));
      expect(getIt.get<Service>(), same(instance));
    });

    test('lazy singleton só cria no primeiro get', () {
      getIt.registerLazySingleton<Counter>(Counter.new);
      expect(Counter.created, 0);
      expect(getIt.checkLazySingletonInstanceExists<Counter>(), isFalse);
      final a = getIt<Counter>();
      expect(getIt<Counter>(), same(a));
      expect(Counter.created, 1);
    });

    test('onCreated é chamado no lazy singleton', () {
      Counter? created;
      getIt.registerLazySingleton<Counter>(Counter.new, onCreated: (c) => created = c);
      final c = getIt<Counter>();
      expect(created, same(c));
    });

    test('instanceName permite múltiplos registros do mesmo tipo', () {
      getIt.registerSingleton<String>('a', instanceName: 'a');
      getIt.registerSingleton<String>('b', instanceName: 'b');
      expect(getIt<String>(instanceName: 'a'), 'a');
      expect(getIt<String>(instanceName: 'b'), 'b');
    });

    test('registro duplicado lança erro, a não ser com allowReassignment', () {
      getIt.registerSingleton<String>('a');
      expect(() => getIt.registerSingleton<String>('b'), throwsArgumentError);
      getIt.allowReassignment = true;
      getIt.registerSingleton<String>('b');
      expect(getIt<String>(), 'b');
    });

    test('skipDoubleRegistration ignora o segundo registro', () {
      getIt.skipDoubleRegistration = true;
      getIt.registerSingleton<String>('a');
      getIt.registerSingleton<String>('b');
      expect(getIt<String>(), 'a');
    });

    test('get de tipo não registrado lança StateError e maybeGet retorna null', () {
      expect(() => getIt<Service>(), throwsStateError);
      expect(getIt.maybeGet<Service>(), isNull);
    });

    test('get por Type em runtime', () {
      getIt.registerSingleton<Service>(ServiceImpl());
      expect(getIt.get<Object>(type: Service), isA<ServiceImpl>());
    });

    test('factoryParam recebe e valida parâmetros', () {
      getIt.registerFactoryParam<Param, String, int?>((a, b) => Param(a, b));
      final p = getIt<Param>(param1: 'x', param2: 2);
      expect(p.a, 'x');
      expect(p.b, 2);
      expect(getIt<Param>(param1: 'y').b, isNull);
      expect(() => getIt<Param>(param1: 1), throwsArgumentError);
    });

    test('cachedFactory reutiliza instância com mesmos parâmetros', () {
      getIt.registerCachedFactoryParam<Param, String, int?>((a, b) => Param(a, b));
      final a = getIt<Param>(param1: 'x');
      expect(getIt<Param>(param1: 'x'), same(a));
      expect(getIt<Param>(param1: 'y'), isNot(same(a)));
    });

    test('múltiplas implementações com getAll', () {
      getIt.enableRegisteringMultipleInstancesOfOneType();
      getIt.registerSingleton<String>('a');
      getIt.registerSingleton<String>('b');
      getIt.registerSingleton<String>('c', instanceName: 'c');
      expect(getIt<String>(), 'a');
      expect(getIt.getAll<String>(), ['a', 'b', 'c']);
    });

    test('findAll encontra por subtipo', () {
      getIt.registerSingleton<ServiceImpl>(ServiceImpl());
      getIt.registerLazySingleton<Counter>(Counter.new);
      expect(getIt.findAll<Service>(), hasLength(1));
      expect(getIt.findAll<Counter>(), isEmpty);
      expect(getIt.findAll<Counter>(instantiateLazySingletons: true), hasLength(1));
    });

    test('detecta dependência circular', () {
      getIt.registerLazySingleton<Service>(() => getIt<Service>());
      expect(() => getIt<Service>(), throwsStateError);
    });
  });

  group('unregister / dispose', () {
    test('unregister chama Disposable.onDispose', () async {
      final service = DisposableService();
      getIt.registerSingleton<DisposableService>(service);
      await getIt.unregister<DisposableService>();
      expect(service.disposed, isTrue);
      expect(getIt.isRegistered<DisposableService>(), isFalse);
    });

    test('unregister usa a função dispose do registro', () async {
      var disposed = false;
      getIt.registerSingleton<String>('a', dispose: (_) => disposed = true);
      await getIt.unregister<String>();
      expect(disposed, isTrue);
    });

    test('unregister por instância e disposingFunction customizada', () async {
      final instance = ServiceImpl();
      getIt.registerSingleton<Service>(instance);
      Object? disposedWith;
      await getIt.unregister<Service>(
        instance: instance,
        disposingFunction: (s) => disposedWith = s,
      );
      expect(disposedWith, same(instance));
    });

    test('registerSingletonIfAbsent e releaseInstance com contagem', () {
      final a = getIt.registerSingletonIfAbsent<Service>(ServiceImpl.new);
      final b = getIt.registerSingletonIfAbsent<Service>(ServiceImpl.new);
      expect(b, same(a));
      getIt.releaseInstance(a);
      expect(getIt.isRegistered<Service>(), isTrue);
      getIt.releaseInstance(a);
      expect(getIt.isRegistered<Service>(), isFalse);
    });

    test('resetLazySingleton recria na próxima chamada', () async {
      getIt.registerLazySingleton<Counter>(Counter.new);
      final a = getIt<Counter>();
      await getIt.resetLazySingleton<Counter>();
      expect(getIt<Counter>(), isNot(same(a)));
    });

    test('reset limpa tudo e chama disposes', () async {
      final service = DisposableService();
      getIt.registerSingleton(service);
      await getIt.reset();
      expect(service.disposed, isTrue);
      expect(getIt.isRegistered<DisposableService>(), isFalse);
    });

    test('changeTypeInstanceName', () {
      getIt.registerSingleton<String>('a', instanceName: 'old');
      getIt.changeTypeInstanceName<String>(instanceName: 'old', newInstanceName: 'new');
      expect(getIt<String>(instanceName: 'new'), 'a');
      expect(getIt.isRegistered<String>(instanceName: 'old'), isFalse);
    });
  });

  group('async', () {
    test('singletonAsync + allReady', () async {
      getIt.registerSingletonAsync<Service>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return ServiceImpl();
      });
      expect(getIt.allReadySync(), isFalse);
      expect(() => getIt<Service>(), throwsStateError);
      await getIt.allReady();
      expect(getIt<Service>(), isA<ServiceImpl>());
      expect(getIt.isReadySync<Service>(), isTrue);
    });

    test('dependsOn aguarda as dependências', () async {
      final order = <String>[];
      getIt.registerSingletonAsync<String>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        order.add('string');
        return 'dep';
      });
      getIt.registerSingletonWithDependencies<Service>(
        () {
          order.add('service');
          return ServiceImpl();
        },
        dependsOn: [String],
      );
      await getIt.isReady<Service>();
      expect(order, ['string', 'service']);
    });

    test('lazySingletonAsync e factoryAsync via getAsync', () async {
      getIt.registerLazySingletonAsync<Counter>(() async => Counter());
      getIt.registerFactoryAsync<Service>(() async => ServiceImpl());
      final a = await getIt.getAsync<Counter>();
      expect(await getIt.getAsync<Counter>(), same(a));
      expect(getIt<Counter>(), same(a));
      expect(await getIt.getAsync<Service>(), isNot(same(await getIt.getAsync<Service>())));
    });

    test('signalReady', () async {
      final s = getIt.registerSingleton<Signaller>(Signaller());
      expect(getIt.allReadySync(), isFalse);
      var done = false;
      final future = getIt.allReady().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      getIt.signalReady(s);
      await future;
      expect(done, isTrue);
      expect(() => getIt.signalReady(s), throwsStateError);
    });

    test('allReady com timeout lança WaitingTimeOutException', () async {
      getIt.registerSingleton<Signaller>(Signaller());
      await expectLater(
        getIt.allReady(timeout: const Duration(milliseconds: 10)),
        throwsA(isA<WaitingTimeOutException>()),
      );
    });
  });

  group('escopos', () {
    test('push/pop e shadowing', () async {
      final base = ShadowAware();
      getIt.registerSingleton<ShadowAware>(base);
      final disposed = <String>[];
      getIt.pushNewScope(
        scopeName: 'session',
        init: (g) => g.registerSingleton<ShadowAware>(ShadowAware()),
        dispose: () => disposed.add('scope'),
      );
      expect(getIt.currentScopeName, 'session');
      expect(getIt<ShadowAware>(), isNot(same(base)));
      expect(base.shadowedBy, isNotNull);

      await getIt.popScope();
      expect(getIt<ShadowAware>(), same(base));
      expect(base.left, isTrue);
      expect(disposed, ['scope']);
    });

    test('popScopesTill e dropScope', () async {
      getIt.pushNewScope(scopeName: 'a');
      getIt.pushNewScope(scopeName: 'b');
      getIt.pushNewScope(scopeName: 'c');
      await getIt.dropScope('b');
      expect(getIt.hasScope('b'), isFalse);
      expect(await getIt.popScopesTill('a'), isTrue);
      expect(getIt.hasScope('a'), isFalse);
      expect(() => getIt.popScope(), throwsStateError);
    });

    test('escopo final não aceita novos registros', () {
      getIt.pushNewScope(scopeName: 'final', isFinal: true);
      getIt.registerSingleton<String>('goes to base');
      expect(getIt.getAll<String>(onlyInScope: 'baseScope'), ['goes to base']);
    });

    test('onScopeChanged é notificado', () async {
      final events = <bool>[];
      getIt.onScopeChanged = events.add;
      getIt.pushNewScope();
      await getIt.popScope();
      expect(events, [true, false]);
    });
  });
}
