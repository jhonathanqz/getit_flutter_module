## 0.1.0

Primeira versão.

### Núcleo (API compatível com get_it)

- `GetIt` reimplementado, sem dependência do pacote `get_it`: `registerFactory`, `registerFactoryParam`, `registerCachedFactory*`, `registerSingleton`, `registerLazySingleton`, versões assíncronas, `registerSingletonWithDependencies` e `registerSingletonIfAbsent`/`releaseInstance`.
- Prontidão: `allReady`, `isReady`, `isReadySync`, `allReadySync`, `signalReady` e `WillSignalReady`, com `WaitingTimeOutException` quando o `timeout` estoura.
- Escopos: `pushNewScope`, `pushNewScopeAsync`, `popScope`, `popScopesTill`, `dropScope`, escopos finais, `onScopeChanged` e `ShadowChangeHandlers`.
- Remoção: `unregister`, `resetLazySingleton(s)`, `resetScope`, `reset`, `Disposable`, `getAll`, `getAllAsync` e `findAll`.

### Camada modular

- `GetItModular` (widget raiz), `ApplicationBindings`, `GetItModule`, `GetItModuleRouter` e `GetItPageRouter`.
- `Bind.singleton`, `singletonAsync`, `lazySingleton`, `lazySingletonAsync`, `factory`, `factoryAsync` e `factoryParam`, com `tag`, `keepAlive`, `dependsOn` e `onDispose`.
- Escopos com contagem de referências: os binds são registrados ao entrar na rota ou no módulo e descartados automaticamente ao sair.
- `ModularLifecycle` (`onInit`/`onDispose`), `Injector`, `context.get`, `context.arguments` e `GetItView`.
- Páginas assíncronas com `builderAsync`.
- Middlewares síncronos e assíncronos, com loader.
- `GetItModularWidget`, `GetItRouteOutlet` e `GetItModular.onGenerateRoute`.
- `ModularLogger` e `ModularContainer` como `ChangeNotifier`, com a lista de escopos abertos (`scopes`).
