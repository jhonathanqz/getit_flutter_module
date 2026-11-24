## 0.1.0

Primeira versão.

### Núcleo (MGetIt)

- Service locator `MGetIt`, sem dependências externas: `registerFactory`, `registerFactoryParam`, `registerCachedFactory*`, `registerSingleton`, `registerLazySingleton`, versões assíncronas, `registerSingletonWithDependencies` e `registerSingletonIfAbsent`/`releaseInstance`.
- Prontidão: `allReady`, `isReady`, `isReadySync`, `allReadySync`, `signalReady` e `WillSignalReady`, com `WaitingTimeOutException` quando o `timeout` estoura.
- Escopos: `pushNewScope`, `pushNewScopeAsync`, `popScope`, `popScopesTill`, `dropScope`, escopos finais, `onScopeChanged` e `ShadowChangeHandlers`.
- Remoção: `unregister`, `resetLazySingleton(s)`, `resetScope`, `reset`, `Disposable`, `getAll`, `getAllAsync` e `findAll`.

### Camada modular

- `MGetItModular` (widget raiz), `ApplicationBindings`, `MGetItModule`, `MGetItModuleRouter` e `MGetItPageRouter`.
- `Bind.singleton`, `singletonAsync`, `lazySingleton`, `lazySingletonAsync`, `factory`, `factoryAsync` e `factoryParam`, com `tag`, `keepAlive`, `dependsOn` e `onDispose`.
- Escopos com contagem de referências: os binds são registrados ao entrar na rota ou no módulo e descartados automaticamente ao sair.
- `ModularLifecycle` (`onInit`/`onDispose`), `Injector`, `context.get`, `context.arguments` e `MGetItView`.
- Páginas assíncronas com `builderAsync`.
- Middlewares síncronos e assíncronos, com loader.
- `MGetItModularWidget`, `MGetItRouteOutlet` e `MGetItModular.onGenerateRoute`.
- `ModularLogger` e `ModularContainer` como `ChangeNotifier`, com a lista de escopos abertos (`scopes`).
