/// API fake com latência configurável, para simular chamadas de rede.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.emoji,
  });

  final int id;
  final String name;
  final double price;
  final String description;
  final String emoji;
}

class User {
  const User({required this.name, required this.email});

  final String name;
  final String email;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class FakeApi {
  FakeApi({this.latency = const Duration(milliseconds: 700)});

  final Duration latency;

  static const _products = [
    Product(
        id: 1,
        name: 'Café especial',
        price: 32.9,
        emoji: '☕',
        description: 'Grãos 100% arábica torrados na semana.'),
    Product(
        id: 2,
        name: 'Pão de queijo',
        price: 18.5,
        emoji: '🧀',
        description: 'Pacote com 20 unidades, direto de Minas.'),
    Product(
        id: 3,
        name: 'Açaí',
        price: 24.0,
        emoji: '🍇',
        description: 'Pote de 500 ml com granola e banana.'),
    Product(
        id: 4,
        name: 'Brigadeiro',
        price: 3.5,
        emoji: '🍫',
        description: 'Brigadeiro gourmet de chocolate belga.'),
    Product(
        id: 5,
        name: 'Coxinha',
        price: 7.0,
        emoji: '🍗',
        description: 'Coxinha de frango com catupiry.'),
    Product(
        id: 6,
        name: 'Guaraná',
        price: 6.5,
        emoji: '🥤',
        description: 'Lata de 350 ml bem gelada.'),
  ];

  Future<void> _wait() => Future<void>.delayed(latency);

  Future<User> login(String email, String password) async {
    await _wait();
    if (password.length < 4) {
      throw AuthException('Senha inválida (mínimo 4 caracteres)');
    }
    return User(name: email.split('@').first, email: email);
  }

  Future<User> register(String name, String email, String password) async {
    await _wait();
    return User(name: name, email: email);
  }

  Future<List<Product>> fetchProducts() async {
    await _wait();
    return _products;
  }

  Future<Product> fetchProduct(int id) async {
    await _wait();
    return _products.firstWhere((p) => p.id == id);
  }

  Future<bool> canSeeCatalog() async {
    await _wait();
    return true;
  }
}
