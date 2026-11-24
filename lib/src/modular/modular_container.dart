import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/m_get_it.dart';
import 'bind.dart';
import 'injector.dart';
import 'logger.dart';
import 'middleware.dart';
import 'route_resolver.dart';

/// Informações (somente leitura) de um escopo aberto.
class ScopeInfo {
  const ScopeInfo({
    required this.id,
    required this.references,
    required this.binds,
  });

  /// Ex.: `application`, `module:/Auth`, `page:/Auth/Login`, `widget:...`.
  final String id;
  final int references;
  final List<String> binds;

  @override
  String toString() => 'ScopeInfo($id, refs: $references, binds: $binds)';
}

/// Escopo vivo (aplicação, módulo, sub-módulo, página ou widget).
class _ScopeNode {
  _ScopeNode(this.id, this.binds);

  final String id;
  final List<Bind> binds;
  int references = 1;
}

/// Bind atualmente registrado no MGetIt e quantos escopos o fornecem.
class _ActiveBind {
  _ActiveBind(this.bind, {required this.owned});

  final Bind bind;

  /// `false` quando o tipo já estava registrado no MGetIt por fora do
  /// modular: nesse caso não fazemos o unregister.
  final bool owned;
  int providers = 1;
  final List<Object> factoryInstances = [];
}

/// Controla quais escopos estão abertos e registra/remove os [Bind]s no
/// [MGetIt] com contagem de referências:
///
/// * ao abrir um escopo, seus binds são registrados (se ainda não estiverem);
/// * ao fechar, os binds que nenhum outro escopo aberto fornece são removidos
///   e descartados (dispose automático).
class ModularContainer extends ChangeNotifier {
  ModularContainer(this.mGetIt);

  static ModularContainer? _instance;

  /// Container ativo, criado pelo widget `MGetItModular`.
  static ModularContainer get instance {
    final container = _instance;
    if (container == null) {
      throw StateError(
        'MGetItModular não foi inicializado. Envolva seu MaterialApp com o '
        'widget MGetItModular.',
      );
    }
    return container;
  }

  static ModularContainer? get maybeInstance => _instance;

  /// Cria e ativa o container global.
  static ModularContainer initialize(MGetIt mGetIt) {
    if (_instance != null) {
      throw StateError(
        'Já existe um MGetItModular ativo. Use apenas um na raiz do app.',
      );
    }
    return _instance = ModularContainer(mGetIt);
  }

  /// Desativa o container global (chamado no dispose do `MGetItModular`).
  static void shutdown() {
    _instance = null;
  }

  final MGetIt mGetIt;

  Injector get injector => Injector(mGetIt);

  /// Argumentos da última rota modular aberta.
  Object? arguments;

  /// Middlewares globais (executados em todas as rotas).
  List<MGetItMiddleware> appMiddlewares = const [];

  /// Rotas resolvidas (caminho completo -> rota).
  Map<String, ResolvedRoute> routes = const {};

  final Map<String, _ScopeNode> _scopes = {};
  final Map<BindKey, _ActiveBind> _binds = {};

  /// Ids dos escopos abertos e quantas referências cada um tem.
  Map<String, int> get openScopes =>
      {for (final s in _scopes.values) s.id: s.references};

  /// Fotografia dos escopos abertos, com os binds de cada um.
  /// Notifica os listeners (este container é um [ChangeNotifier]) sempre que
  /// um escopo abre, fecha ou muda de contagem.
  List<ScopeInfo> get scopes => [
        for (final s in _scopes.values)
          ScopeInfo(
            id: s.id,
            references: s.references,
            binds: [for (final b in s.binds) b.toString()],
          ),
      ];

  void _changed() {
    if (hasListeners) notifyListeners();
  }

  bool isOpen(String id) => _scopes.containsKey(id);

  /// Abre (ou referencia novamente) o escopo [id]. Retorna `true` quando o
  /// escopo acabou de ser criado, isto é, é a primeira entrada nele.
  bool open(String id, List<Bind> binds) {
    final existing = _scopes[id];
    if (existing != null) {
      existing.references++;
      _changed();
      return false;
    }
    _scopes[id] = _ScopeNode(id, List.unmodifiable(binds));
    ModularLogger.enterScope(id);
    for (final bind in binds) {
      _provide(bind);
    }
    _changed();
    return true;
  }

  void _provide(Bind bind) {
    final active = _binds[bind.key];
    if (active != null) {
      active.providers++;
      return;
    }
    if (bind.isRegisteredIn(mGetIt)) {
      ModularLogger.alreadyRegistered(bind);
      _binds[bind.key] = _ActiveBind(bind, owned: false);
      return;
    }
    final activeBind = _ActiveBind(bind, owned: true);
    _binds[bind.key] = activeBind;
    try {
      bind.register(
        mGetIt,
        injector: injector,
        onFactoryCreated: (instance) {
          if (instance is Disposable || bind.onDispose != null) {
            activeBind.factoryInstances.add(instance);
          }
        },
      );
      ModularLogger.registered(bind);
    } catch (_) {
      _binds.remove(bind.key);
      rethrow;
    }
  }

  /// Libera uma referência do escopo [id]. Quando não restam referências o
  /// escopo é fechado: [beforeDispose] é executado e os binds que não são
  /// usados por outros escopos são removidos do MGetIt.
  ///
  /// Retorna `true` quando o escopo foi fechado.
  bool close(String id, {VoidCallback? beforeDispose}) {
    final scope = _scopes[id];
    if (scope == null) return false;
    scope.references--;
    if (scope.references > 0) {
      _changed();
      return false;
    }

    beforeDispose?.call();
    _scopes.remove(id);
    for (final bind in scope.binds.reversed) {
      _release(bind);
    }
    ModularLogger.exitScope(id);
    _changed();
    return true;
  }

  void _release(Bind bind) {
    final active = _binds[bind.key];
    if (active == null) return;
    active.providers--;
    if (active.providers > 0) return;
    _binds.remove(bind.key);

    if (!active.owned) return;
    if (active.bind.keepAlive) {
      ModularLogger.keptAlive(active.bind);
      return;
    }

    for (final instance in active.factoryInstances.reversed) {
      _guard(() => active.bind.disposeInstance(instance));
    }
    active.factoryInstances.clear();
    _guard(() => active.bind.unregister(mGetIt));
    ModularLogger.disposed(active.bind);
  }

  void _guard(FutureOr<dynamic> Function() action) {
    void report(Object error, StackTrace stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'getit_flutter_module',
        context: ErrorDescription('while disposing a Bind'),
      ));
    }

    try {
      final result = action();
      if (result is Future) {
        result.then<void>((_) {}, onError: report);
      }
    } catch (error, stack) {
      report(error, stack);
    }
  }

  /// Fecha todos os escopos (usado ao desmontar o `MGetItModular`).
  void closeAll() {
    for (final id in _scopes.keys.toList().reversed) {
      final scope = _scopes[id]!;
      scope.references = 1;
      close(id);
    }
  }
}
