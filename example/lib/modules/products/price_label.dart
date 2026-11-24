/// Criado via `Bind.factoryParam`: uma instância nova para cada preço.
class PriceLabel {
  PriceLabel(this.value, {this.currency = r'R$'});

  final double value;
  final String currency;

  String get text =>
      '$currency ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}
