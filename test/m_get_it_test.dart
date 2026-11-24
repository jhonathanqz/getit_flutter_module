import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getit_flutter_module/getit_flutter_module.dart';

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
  late MGetIt mGetIt;

  setUp(() {
    mGetIt = MGetIt.asNewInstance();
    Counter.created = 0;
  });

  group('registro e get', () {
    test('factory cria nova instância a cada get', () {
      mGetIt.registerFactory<Counter>(Counter.new);
      expect(identical(mGetIt<Counter>(), mGetIt<Counter>()), isFalse);
      expect(Counter.created, 2);
    });

    test('singleton retorna sempre a mesma instância', () {
      final instance = mGetIt.registerSingleton<Service>(ServiceImpl());
      expect(mGetIt<Service>(), same(instance));
      expect(mGetIt.get<Service>(), same(instance));
    });

    test('lazy singleton só cria no primeiro get', () {
      mGetIt.registerLazySingleton<Counter>(Counter.new);
      expect(Counter.created, 0);
      expect(mGetIt.checkLazySingletonInstanceExists<Counter>(), isFalse);
      final a = mGetIt<Counter>();
      expect(mGetIt<Counter>(), same(a));
      expect(Counter.created, 1);
    });

    test('onCreated é chamado no lazy singleton', () {
      Counter? created;
      mGetIt.registerLazySingleton<Counter>(Counter.new,
          onCreated: (c) => created = c);
      final c = mGetIt<Counter>();
      expect(created, same(c));
    });

    test('instanceName permite múltiplos registros do mesmo tipo', () {
      mGetIt.registerSingleton<String>('a', instanceName: 'a');
      mGetIt.registerSingleton<String>('b', instanceName: 'b');
      expect(mGetIt<String>(instanceName: 'a'), 'a');
      expect(mGetIt<String>(instanceName: 'b'), 'b');
    });

    test('registro duplicado lança erro, a não ser com allowReassignment', () {
      mGetIt.registerSingleton<String>('a');
      expect(() => mGetIt.registerSingleton<String>('b'), throwsArgumentError);
      mGetIt.allowReassignment = true;
      mGetIt.registerSingleton<String>('b');
      expect(mGetIt<String>(), 'b');
    });

    test('skipDoubleRegistration ignora o segundo registro', () {
      mGetIt.skipDoubleRegistration = true;
      mGetIt.registerSingleton<String>('a');
      mGetIt.registerSingleton<String>('b');
      expect(mGetIt<String>(), 'a');
    });

    test('get de tipo não registrado lança StateError e maybeGet retorna null',
        () {
      expect(() => mGetIt<Service>(), throwsStateError);
      expect(mGetIt.maybeGet<Service>(), isNull);
    });

    test('get por Type em runtime', () {
      mGetIt.registerSingleton<Service>(ServiceImpl());
      expect(mGetIt.get<Object>(type: Service), isA<ServiceImpl>());
    });

    test('factoryParam recebe e valida parâmetros', () {
      mGetIt.registerFactoryParam<Param, String, int?>((a, b) => Param(a, b));
      final p = mGetIt<Param>(param1: 'x', param2: 2);
      expect(p.a, 'x');
      expect(p.b, 2);
      expect(mGetIt<Param>(param1: 'y').b, isNull);
      expect(() => mGetIt<Param>(param1: 1), throwsArgumentError);
    });

    test('cachedFactory reutiliza instância com mesmos parâmetros', () {
      mGetIt.registerCachedFactoryParam<Param, String, int?>(
          (a, b) => Param(a, b));
      final a = mGetIt<Param>(param1: 'x');
      expect(mGetIt<Param>(param1: 'x'), same(a));
      expect(mGetIt<Param>(param1: 'y'), isNot(same(a)));
    });

    test('múltiplas implementações com getAll', () {
      mGetIt.enableRegisteringMultipleInstancesOfOneType();
      mGetIt.registerSingleton<String>('a');
      mGetIt.registerSingleton<String>('b');
      mGetIt.registerSingleton<String>('c', instanceName: 'c');
      expect(mGetIt<String>(), 'a');
      expect(mGetIt.getAll<String>(), ['a', 'b', 'c']);
    });

    test('findAll encontra por subtipo', () {
      mGetIt.registerSingleton<ServiceImpl>(ServiceImpl());
      mGetIt.registerLazySingleton<Counter>(Counter.new);
      expect(mGetIt.findAll<Service>(), hasLength(1));
      expect(mGetIt.findAll<Counter>(), isEmpty);
      expect(mGetIt.findAll<Counter>(instantiateLazySingletons: true),
          hasLength(1));
    });

    test('detecta dependência circular', () {
      mGetIt.registerLazySingleton<Service>(() => mGetIt<Service>());
      expect(() => mGetIt<Service>(), throwsStateError);
    });
  });

  group('unregister / dispose', () {
    test('unregister chama Disposable.onDispose', () async {
      final service = DisposableService();
      mGetIt.registerSingleton<DisposableService>(service);
      await mGetIt.unregister<DisposableService>();
      expect(service.disposed, isTrue);
      expect(mGetIt.isRegistered<DisposableService>(), isFalse);
    });

    test('unregister usa a função dispose do registro', () async {
      var disposed = false;
      mGetIt.registerSingleton<String>('a', dispose: (_) => disposed = true);
      await mGetIt.unregister<String>();
      expect(disposed, isTrue);
    });

    test('unregister por instância e disposingFunction customizada', () async {
      final instance = ServiceImpl();
      mGetIt.registerSingleton<Service>(instance);
      Object? disposedWith;
      await mGetIt.unregister<Service>(
        instance: instance,
        disposingFunction: (s) => disposedWith = s,
      );
      expect(disposedWith, same(instance));
    });

    test('registerSingletonIfAbsent e releaseInstance com contagem', () {
      final a = mGetIt.registerSingletonIfAbsent<Service>(ServiceImpl.new);
      final b = mGetIt.registerSingletonIfAbsent<Service>(ServiceImpl.new);
      expect(b, same(a));
      mGetIt.releaseInstance(a);
      expect(mGetIt.isRegistered<Service>(), isTrue);
      mGetIt.releaseInstance(a);
      expect(mGetIt.isRegistered<Service>(), isFalse);
    });

    test('resetLazySingleton recria na próxima chamada', () async {
      mGetIt.registerLazySingleton<Counter>(Counter.new);
      final a = mGetIt<Counter>();
      await mGetIt.resetLazySingleton<Counter>();
      expect(mGetIt<Counter>(), isNot(same(a)));
    });

    test('reset limpa tudo e chama disposes', () async {
      final service = DisposableService();
      mGetIt.registerSingleton(service);
      await mGetIt.reset();
      expect(service.disposed, isTrue);
      expect(mGetIt.isRegistered<DisposableService>(), isFalse);
    });

    test('changeTypeInstanceName', () {
      mGetIt.registerSingleton<String>('a', instanceName: 'old');
      mGetIt.changeTypeInstanceName<String>(
          instanceName: 'old', newInstanceName: 'new');
      expect(mGetIt<String>(instanceName: 'new'), 'a');
      expect(mGetIt.isRegistered<String>(instanceName: 'old'), isFalse);
    });
  });

  group('async', () {
    test('singletonAsync + allReady', () async {
      mGetIt.registerSingletonAsync<Service>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return ServiceImpl();
      });
      expect(mGetIt.allReadySync(), isFalse);
      expect(() => mGetIt<Service>(), throwsStateError);
      await mGetIt.allReady();
      expect(mGetIt<Service>(), isA<ServiceImpl>());
      expect(mGetIt.isReadySync<Service>(), isTrue);
    });

    test('dependsOn aguarda as dependências', () async {
      final order = <String>[];
      mGetIt.registerSingletonAsync<String>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        order.add('string');
        return 'dep';
      });
      mGetIt.registerSingletonWithDependencies<Service>(
        () {
          order.add('service');
          return ServiceImpl();
        },
        dependsOn: [String],
      );
      await mGetIt.isReady<Service>();
      expect(order, ['string', 'service']);
    });

    test('lazySingletonAsync e factoryAsync via getAsync', () async {
      mGetIt.registerLazySingletonAsync<Counter>(() async => Counter());
      mGetIt.registerFactoryAsync<Service>(() async => ServiceImpl());
      final a = await mGetIt.getAsync<Counter>();
      expect(await mGetIt.getAsync<Counter>(), same(a));
      expect(mGetIt<Counter>(), same(a));
      expect(await mGetIt.getAsync<Service>(),
          isNot(same(await mGetIt.getAsync<Service>())));
    });

    test('signalReady', () async {
      final s = mGetIt.registerSingleton<Signaller>(Signaller());
      expect(mGetIt.allReadySync(), isFalse);
      var done = false;
      final future = mGetIt.allReady().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      mGetIt.signalReady(s);
      await future;
      expect(done, isTrue);
      expect(() => mGetIt.signalReady(s), throwsStateError);
    });

    test('allReady com timeout lança WaitingTimeOutException', () async {
      mGetIt.registerSingleton<Signaller>(Signaller());
      await expectLater(
        mGetIt.allReady(timeout: const Duration(milliseconds: 10)),
        throwsA(isA<WaitingTimeOutException>()),
      );
    });
  });

  group('escopos', () {
    test('push/pop e shadowing', () async {
      final base = ShadowAware();
      mGetIt.registerSingleton<ShadowAware>(base);
      final disposed = <String>[];
      mGetIt.pushNewScope(
        scopeName: 'session',
        init: (g) => g.registerSingleton<ShadowAware>(ShadowAware()),
        dispose: () => disposed.add('scope'),
      );
      expect(mGetIt.currentScopeName, 'session');
      expect(mGetIt<ShadowAware>(), isNot(same(base)));
      expect(base.shadowedBy, isNotNull);

      await mGetIt.popScope();
      expect(mGetIt<ShadowAware>(), same(base));
      expect(base.left, isTrue);
      expect(disposed, ['scope']);
    });

    test('popScopesTill e dropScope', () async {
      mGetIt.pushNewScope(scopeName: 'a');
      mGetIt.pushNewScope(scopeName: 'b');
      mGetIt.pushNewScope(scopeName: 'c');
      await mGetIt.dropScope('b');
      expect(mGetIt.hasScope('b'), isFalse);
      expect(await mGetIt.popScopesTill('a'), isTrue);
      expect(mGetIt.hasScope('a'), isFalse);
      expect(() => mGetIt.popScope(), throwsStateError);
    });

    test('escopo final não aceita novos registros', () {
      mGetIt.pushNewScope(scopeName: 'final', isFinal: true);
      mGetIt.registerSingleton<String>('goes to base');
      expect(mGetIt.getAll<String>(onlyInScope: 'baseScope'), ['goes to base']);
    });

    test('onScopeChanged é notificado', () async {
      final events = <bool>[];
      mGetIt.onScopeChanged = events.add;
      mGetIt.pushNewScope();
      await mGetIt.popScope();
      expect(events, [true, false]);
    });
  });
}
