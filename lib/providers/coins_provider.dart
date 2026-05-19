import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

class CoinsProvider extends ChangeNotifier {
  int _balance = 0;
  bool _loading = false;

  int get balance => _balance;
  bool get loading => _loading;

  Future<void> sync(String? token) async {
    if (token == null) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse('${Env.apiBaseUrl}/api/v1/wallet/balance'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _balance = (data['balance'] ?? data['coins'] ?? 0) as int;
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<bool> deduct(int amount, String? token) async {
    if (token == null || amount > _balance) return false;
    _balance -= amount;
    notifyListeners();
    return true;
  }

  void setBalance(int b) {
    _balance = b;
    notifyListeners();
  }
}
