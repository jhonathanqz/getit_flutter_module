import 'package:flutter/material.dart';
import 'package:getit_flutter_module/getit_flutter_module.dart';

import '../auth_repository.dart';

class LoginController extends ChangeNotifier with ModularLifecycle {
  LoginController(this._repository);

  final AuthRepository _repository;

  final email = TextEditingController(text: 'dev@getit.dev');
  final password = TextEditingController(text: '123456');

  bool loading = false;
  String? error;

  Future<bool> login() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _repository.login(email.text.trim(), password.text);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void onDispose() {
    // Chamado automaticamente quando a rota /Auth/Login é fechada.
    email.dispose();
    password.dispose();
    dispose();
  }
}
