import 'package:getit_modular/getit_modular.dart';

import '../../core/middlewares/auth_guard.dart';
import '../cart/cart_controller.dart';
import '../products/price_label.dart';
import 'home_page.dart';

/// `/Home`: protegida pelo [AuthGuard]. Hospeda as abas.
class HomeModule extends GetItModule {
  @override
  String get moduleRouteName => '/Home';

  @override
  List<GetItMiddleware> get middlewares => const [AuthGuard()];

  @override
  List<Bind> get bindings => [
        Bind.lazySingleton<CartController>((i) => CartController()),
        // Factory com parâmetros: context.get<PriceLabel>(param1: 10.5)
        Bind.factoryParam<PriceLabel, double, String?>(
          (i, value, currency) => PriceLabel(value, currency: currency ?? r'R$'),
        ),
      ];

  @override
  List<GetItRouter> get pages => [
        GetItPageRouter(name: '/', builder: (_) => const HomePage()),
      ];
}
