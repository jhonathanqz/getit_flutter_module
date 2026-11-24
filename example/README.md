# getit_modular — app de exemplo

Uma loja simples ("Mercadinho Modular") que usa os recursos do `getit_modular`.

## Rodando

```powershell
flutter run          # Chrome, Windows, Android, iOS...
flutter test         # testes de fluxo completo (login, cadastro, catálogo, logout)
```

O login de demonstração já vem preenchido: `dev@getit.dev` / `123456`. Senhas com menos de 4 caracteres geram erro.

Toque no botão **"N escopos"** para abrir o inspector. Ele mostra, ao vivo, os escopos abertos, os binds de cada um e o log de registro e dispose.

## Rotas e escopos

```
application                      FakeApi, SessionStore, AppConfig (async → splash)
├── /Auth                        AuthRepository
│   ├── /Auth/Login              LoginController
│   └── /Auth/Register           RegisterController (compartilhado pelas 2 etapas)
│       ├── /Auth/Register
│       └── /Auth/Register/Password
├── /Home            [AuthGuard] CartController, PriceLabel (factoryParam)
│   └── /Home                    abas: Produtos (MGetItRouteOutlet) | Carrinho | Perfil (MGetItModularWidget)
└── /Products        [CatalogPermissionMiddleware async]
    │                            ProductsRepository, RecentlyViewed (keepAlive)
    ├── /Products                ProductsController (singletonAsync + builderAsync)
    └── /Products/Detail         ProductDetailController (usa arguments)
```

## Roteiro para ver o dispose acontecendo

1. **Login → Entrar**: o módulo `/Auth` inteiro sai e `/Home` + `/Products` entram.
2. **Abrir um produto**: o sub-módulo `/Products/Detail` entra. **Voltar**: ele é descartado.
3. **Aba Perfil**: o `ProfileController` existe só enquanto a aba está visível.
4. **Sair**: Home e Products são descartados. `RecentlyViewed` (`keepAlive`) e os binds da aplicação continuam.

## Estrutura

```
lib/
├── app/            MGetItModular, AppBindings, splash
├── core/           serviços (API fake, sessão, config), middlewares, inspector
└── modules/
    ├── auth/       login + sub-módulo de cadastro
    ├── home/       shell com abas + AuthGuard
    ├── products/   catálogo, detalhe, middleware async, keepAlive
    ├── cart/       carrinho (bind do módulo Home)
    └── profile/    aba com MGetItModularWidget
```
