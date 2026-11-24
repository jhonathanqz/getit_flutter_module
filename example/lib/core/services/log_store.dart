import 'package:flutter/foundation.dart';

/// Guarda as últimas mensagens do [ModularLogger] para exibir no inspector.
class LogStore extends ValueNotifier<List<String>> {
  LogStore._() : super(const []);

  static final instance = LogStore._();

  void add(String message) {
    final next = [...value, message];
    value = next.length > 60 ? next.sublist(next.length - 60) : next;
  }
}
