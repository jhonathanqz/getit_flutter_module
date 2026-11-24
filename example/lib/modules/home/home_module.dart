import 'package:getit_flutter_module/getit_flutter_module.dart';

import '../../core/middlewares/auth_guard.dart';
import '../cart/cart_controller.dart';
import '../products/price_label.dart';
import 'home_page.dart';

/// `/Home`: protegida pelo [AuthGuard]. Hospeda as abas.
class HomeModule extends MGetItModule {
  @override
  String get moduleRouteName => '/Home';

  @override
  List<MGetItMiddleware> get middlewares => const [AuthGuard()];

  @override
  List<Bind> get bindings => [
        Bind.lazySingleton<CartController>((i) => CartController()),
        // Factory com parâmetros: context.get<PriceLabel>(param1: 10.5)
        Bind.factoryParam<PriceLabel, double, String?>(
          (i, value, currency) =>
              PriceLabel(value, currency: currency ?? r'R$'),
        ),
      ];

  @override
  List<MGetItRouter> get pages => [
        MGetItPageRouter(name: '/', builder: (_) => const HomePage()),
      ];
}
