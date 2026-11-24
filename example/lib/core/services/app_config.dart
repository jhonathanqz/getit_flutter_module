/// Configuração carregada de forma assíncrona na inicialização do app
/// (simula leitura de storage/remote config). Enquanto não carrega, o app
/// mostra o splash (`isReady == false`).
class AppConfig {
  const AppConfig({required this.storeName, required this.version});

  final String storeName;
  final String version;

  static Future<AppConfig> load(Duration latency) async {
    await Future<void>.delayed(latency * 2);
    return const AppConfig(storeName: 'Mercadinho Modular', version: '1.0.0');
  }
}
