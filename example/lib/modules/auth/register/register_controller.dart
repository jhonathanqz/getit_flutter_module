import 'package:flutter/material.dart';
import 'package:getit_modular/getit_modular.dart';

import '../auth_repository.dart';

/// Estado do cadastro, compartilhado entre as duas etapas do sub-módulo
/// `/Auth/Register`.
class RegisterController extends ChangeNotifier with ModularLifecycle {
  RegisterController(this._repository);

  final AuthRepository _repository;

  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;

  bool get stepOneValid =>
      name.text.trim().isNotEmpty && email.text.contains('@');

  Future<void> submit() async {
    loading = true;
    notifyListeners();
    try {
      await _repository.register(
        name.text.trim(),
        email.text.trim(),
        password.text,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void onDispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    dispose();
  }
}
