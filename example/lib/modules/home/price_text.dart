import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../products/price_label.dart';

class PriceText extends StatelessWidget {
  const PriceText(this.value, {super.key, this.style, this.textAlign});

  final double value;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
        context.get<PriceLabel>(param1: value).text,
        style: style,
        textAlign: textAlign,
      );
}
