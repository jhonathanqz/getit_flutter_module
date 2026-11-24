import '../../core/services/fake_api.dart';
import '../../core/services/session_store.dart';

class AuthRepository {
  AuthRepository(this._api, this._session);

  final FakeApi _api;
  final SessionStore _session;

  Future<void> login(String email, String password) async {
    _session.login(await _api.login(email, password));
  }

  Future<void> register(String name, String email, String password) async {
    _session.login(await _api.register(name, email, password));
  }
}
