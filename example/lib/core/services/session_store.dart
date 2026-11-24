import 'package:flutter/foundation.dart';

import 'fake_api.dart';

/// Sessão do usuário: vive durante toda a aplicação.
class SessionStore extends ChangeNotifier {
  User? _user;

  User? get user => _user;
  bool get isLogged => _user != null;

  void login(User user) {
    _user = user;
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
