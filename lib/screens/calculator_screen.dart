// lib/screens/calculator_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/gold_price_service.dart';

enum OperationType { sell, buy }

enum CostType { perGram, percent, fixed }

class CostItem {
  final String id;
  final CostType type;
  final double value; // perGram => amount per gram, percent => percent (e.g., 14 for 14%), fixed => total amount
  final String title;

  CostItem({required this.id, required this.type, required this.value, required this.title});

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'value': value,
        'title': title,
      };

  factory CostItem.fromMap(Map<String, dynamic> m) => CostItem(
        id: m['id'] ?? UniqueKey().toString(),
        type: CostType.values[(m['type'] ?? 0) as int],
        value: (m['value'] as num).toDouble(),
        title: m['title'] ?? '',
      );
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final GoldPriceService _priceService = GoldPriceService();
  Timer? _timer;

  OperationType _operation = OperationType.sell;
  String _metal = 'gold';
  String _purity = '21';
  final TextEditingController _weightController = TextEditingController(text: '1');
  final TextEditingController _impurityController = TextEditingController(text: '0');

  List<CostItem> _costs = [];
  double _result = 0.0;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _loadCosts();
    _fetchPrices();
    // auto refresh every 5 minutes
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchPrices());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPrices() async {
    final r = await _priceService.fetchLatestPrices();
    setState(() {
      _fetchError = r.error;
    });
  }

  Future<void> _loadCosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('costs') ?? [];
    setState(() {
      _costs = raw.map((s) => CostItem.fromMap(Map<String, dynamic>.from(Uri.splitQueryString(s)))).toList();
    });
  }

  Future<void> _saveCosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _costs.map((c) => Uri(queryParameters: c.toMap().map((k, v) => MapEntry(k, v.toString()))).query).toList();
    await prefs.setStringList('costs', raw);
  }

  Future<void> _addCostDialog() async {
    final titleCtl = TextEditingController();
    CostType type = CostType.perGram;
    final valueCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('إضافة تكلفة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: 'عنوان التكلفة'),
              ),
              const SizedBox(height: 8),
              DropdownButton<CostType>(
                value: type,
                items: CostType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toString().split('.').last)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => type = v);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'القيمة'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(valueCtl.text) ?? 0.0;
                final id = UniqueKey().toString();
                final c = CostItem(id: id, type: type, value: v, title: titleCtl.text);
                setState(() {
                  _costs.add(c);
                });
                _saveCosts();
                Navigator.of(context).pop();
              },
              child: const Text('حفظ'),
            )
          ],
        ),
      ),
    );
  }

  void _removeCost(String id) {
    setState(() {
      _costs.removeWhere((c) => c.id == id);
    });
    _saveCosts();
  }

  double _getPricePerGram() {
    final latest = _priceService.latest;
    if (latest == null || latest.rates.isEmpty) return 0.0;
    if (_metal == 'gold') {
      final key = _purity;
      return latest.rates[key] ?? 0.0;
    } else {
      // silver
      final silver925 = latest.rates['silver925'];
      if (silver925 == null) return 0.0;
      final purityNum = int.tryParse(_purity) ?? 925;
      return silver925 / 925.0 * purityNum;
    }
  }

  void _calculate() {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final pricePerGram = _getPricePerGram();
    if (pricePerGram == 0.0) {
      setState(() {
        _result = 0.0;
      });
      return;
    }

    double perGramCosts = 0.0;
    double fixedSum = 0.0;
    double percentTotal = 0.0; // sum of percent entries

    for (final c in _costs) {
      if (c.type == CostType.perGram) perGramCosts += c.value;
      if (c.type == CostType.fixed) fixedSum += c.value;
      if (c.type == CostType.percent) percentTotal += c.value;
    }

    if (_operation == OperationType.sell) {
      // VAT% × تكاليف الجرام × الوزن
      final vatAmount = (percentTotal / 100.0) * (perGramCosts * weight);
      final total = (pricePerGram * weight) + (perGramCosts * weight) + fixedSum + vatAmount;
      setState(() {
        _result = total;
      });
    } else {
      // buying from customer: subtract impurity discount
      final impurityPercent = double.tryParse(_impurityController.text) ?? 0.0;
      final gross = pricePerGram * weight;
      final discount = gross * impurityPercent / 100.0;
      final total = gross - discount;
      setState(() {
        _result = total;
      });
    }
  }

  Widget _priceCard() {
    final latest = _priceService.latest;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('السعر اللحظي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(_priceService.lastUpdatedAgo(), style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            if (latest == null) const Text('...') else if (latest.error != null)
              Column(
                children: [
                  Text('تعذر جلب السعر، اضغط للمحاولة مجدداً', style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _fetchPrices, child: const Text('تحديث'))
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('عيار 21: ${latest.rates['21']?.toStringAsFixed(2) ?? '-'} ج'),
                  Text('عيار 24: ${latest.rates['24']?.toStringAsFixed(2) ?? '-'} ج'),
                  Text('عيار 18: ${latest.rates['18']?.toStringAsFixed(2) ?? '-'} ج'),
                  Text('عيار 14: ${latest.rates['14']?.toStringAsFixed(2) ?? '-'} ج'),
                  Text('فضة 925: ${latest.rates['silver925']?.toStringAsFixed(2) ?? '-'} ج'),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _fetchPrices, child: const Text('تحديث'))
                ],
              )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حاسبة الصاغة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('shop_id');
                Navigator.of(context).pushReplacementNamed('/login');
              },
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              _priceCard(),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<OperationType>(
                              value: _operation,
                              isExpanded: true,
                              items: OperationType.values
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e == OperationType.sell ? 'بيع لزبون' : 'شراء من زبون')))
                                  .toList(),
                              onChanged: (v) => setState(() => _operation = v ?? OperationType.sell),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _metal,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: 'gold', child: Text('ذهب')),
                                const DropdownMenuItem(value: 'silver', child: Text('فضة')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _metal = v;
                                  _purity = v == 'gold' ? '21' : '925';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _purity,
                              isExpanded: true,
                              items: (_metal == 'gold'
                                      ? ['24', '21', '18', '14']
                                      : ['999', '925', '800'])
                                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                  .toList(),
                              onChanged: (v) => setState(() => _purity = v ?? _purity),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'الوزن (جرام)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_operation == OperationType.buy)
                        TextField(
                          controller: _impurityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'خصم الشوائب (%)'),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(onPressed: _addCostDialog, child: const Text('إضافة تكلفة')),
                          const SizedBox(width: 8),
                          ElevatedButton(onPressed: _calculate, child: const Text('حساب')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _costs
                            .map((c) => Chip(
                                  label: Text('${c.title} : ${c.type == CostType.percent ? '${c.value}% ' : c.value.toStringAsFixed(2)}'),
                                  onDeleted: () => _removeCost(c.id),
                                ))
                            .toList(),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Card(
                    color: const Color(0xFF121212),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('النتيجة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text('${_result.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, color: Color(0xFFD4AF37))),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
