// lib/services/gold_price_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class PriceResult {
  final Map<String, double> rates; // keys like '21', '24', '18', '14', 'silver925'
  final DateTime fetchedAt;
  final String? error;

  PriceResult({required this.rates, required this.fetchedAt, this.error});
}

class GoldPriceService extends ChangeNotifier {
  PriceResult? _latest;
  bool _loading = false;

  PriceResult? get latest => _latest;
  bool get loading => _loading;

  // Fetch latest prices from https://market.isagha.com/prices
  Future<PriceResult> fetchLatestPrices() async {
    _loading = true;
    notifyListeners();

    final uri = Uri.parse('https://market.isagha.com/prices');
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        final result = PriceResult(rates: {}, fetchedAt: DateTime.now(), error: 'HTTP ${res.statusCode}');
        _latest = result;
        _loading = false;
        notifyListeners();
        return result;
      }

      final document = parse(res.body);
      final bodyText = document.body?.text ?? '';

      double? parseFirstMatch(RegExp re) {
        final m = re.firstMatch(bodyText);
        if (m == null) return null;
        final raw = m.group(1) ?? m.group(0) ?? '';
        final cleaned = raw.replaceAll(RegExp(r"[^0-9.,]"), '').replaceAll(',', '');
        return double.tryParse(cleaned);
      }

      // Try Arabic and English patterns for 21k
      double? price21;
      price21 ??= parseFirstMatch(RegExp(r"عيار\s*21[^0-9]*([0-9.,]+)"));
      price21 ??= parseFirstMatch(RegExp(r"21\s*(?:k|ك)?[^0-9]*([0-9.,]+)"));
      price21 ??= parseFirstMatch(RegExp(r"عيار\-?21[^0-9]*([0-9.,]+)"));

      // Silver 925
      double? silver925;
      silver925 ??= parseFirstMatch(RegExp(r"فضة\s*925[^0-9]*([0-9.,]+)"));
      silver925 ??= parseFirstMatch(RegExp(r"silver\s*925[^0-9]*([0-9.,]+)", caseSensitive: false));

      if (price21 == null && silver925 == null) {
        final result = PriceResult(rates: {}, fetchedAt: DateTime.now(), error: 'تعذر العثور على الأسعار في الصفحة');
        _latest = result;
        _loading = false;
        notifyListeners();
        return result;
      }

      final Map<String, double> rates = {};
      if (price21 != null) {
        rates['21'] = price21;
        rates['24'] = price21 / 21.0 * 24.0;
        rates['18'] = price21 / 21.0 * 18.0;
        rates['14'] = price21 / 21.0 * 14.0;
      }
      if (silver925 != null) {
        rates['silver925'] = silver925;
      }

      final result = PriceResult(rates: rates, fetchedAt: DateTime.now());
      _latest = result;
      _loading = false;
      notifyListeners();
      return result;
    } catch (e) {
      final result = PriceResult(rates: {}, fetchedAt: DateTime.now(), error: e.toString());
      _latest = result;
      _loading = false;
      notifyListeners();
      return result;
    }
  }

  String lastUpdatedAgo() {
    if (_latest == null) return '-';
    final diff = DateTime.now().difference(_latest!.fetchedAt);
    if (diff.inMinutes < 1) return 'قبل أقل من دقيقة';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}
