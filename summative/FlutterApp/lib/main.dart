import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Update this once the API is deployed on Render, e.g.
// "https://life-expectancy-api-xxxx.onrender.com"
const String apiBaseUrl = "https://life-expectancy-api.onrender.com";

void main() {
  runApp(const LifeExpectancyApp());
}

class LifeExpectancyApp extends StatelessWidget {
  const LifeExpectancyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Expectancy Predictor',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const PredictionPage(),
    );
  }
}

class FieldSpec {
  final String key;
  final String label;
  final double min;
  final double max;
  final bool isInt;

  const FieldSpec(
    this.key,
    this.label,
    this.min,
    this.max, {
    this.isInt = false,
  });
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();

  final List<FieldSpec> _numericFields = const [
    FieldSpec('year', 'Year', 2000, 2030, isInt: true),
    FieldSpec(
      'adult_mortality',
      'Adult mortality (per 1000, ages 15-60)',
      0,
      800,
    ),
    FieldSpec(
      'infant_deaths',
      'Infant deaths (per 1000 population)',
      0,
      2000,
      isInt: true,
    ),
    FieldSpec('alcohol', 'Alcohol consumption (litres per capita)', 0, 20),
    FieldSpec(
      'percentage_expenditure',
      'Health expenditure (% of GDP per capita)',
      0,
      20000,
    ),
    FieldSpec('hepatitis_b', 'Hepatitis B immunization coverage (%)', 0, 100),
    FieldSpec(
      'measles',
      'Measles cases (per 1000 population)',
      0,
      220000,
      isInt: true,
    ),
    FieldSpec('bmi', 'Average BMI', 0, 90),
    FieldSpec(
      'under_five_deaths',
      'Under-five deaths (per 1000 population)',
      0,
      2600,
      isInt: true,
    ),
    FieldSpec('polio', 'Polio immunization coverage (%)', 0, 100),
    FieldSpec('total_expenditure', 'Government health expenditure (%)', 0, 20),
    FieldSpec('diphtheria', 'Diphtheria immunization coverage (%)', 0, 100),
    FieldSpec(
      'hiv_aids',
      'HIV/AIDS deaths (per 1000 live births, ages 0-4)',
      0,
      60,
    ),
    FieldSpec('gdp', 'GDP per capita (USD)', 0, 120000),
    FieldSpec(
      'thinness_1_19_years',
      'Thinness prevalence, ages 10-19 (%)',
      0,
      30,
    ),
    FieldSpec('thinness_5_9_years', 'Thinness prevalence, ages 5-9 (%)', 0, 30),
    FieldSpec(
      'income_composition_of_resources',
      'Income composition of resources (0-1)',
      0,
      1,
    ),
    FieldSpec('schooling', 'Average years of schooling', 0, 21),
  ];

  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _statusController = TextEditingController();

  String? _resultText;
  bool _isError = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (final field in _numericFields) {
      _controllers[field.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _resultText = null;
      _isError = false;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _resultText = 'Please fix the highlighted fields before predicting.';
        _isError = true;
      });
      return;
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> body = {
      'status': _titleCase(_statusController.text.trim()),
    };
    for (final field in _numericFields) {
      final raw = _controllers[field.key]!.text;
      body[field.key] = field.isInt ? int.parse(raw) : double.parse(raw);
    }

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _resultText =
              'Predicted life expectancy: ${data['predicted_life_expectancy']} years';
          _isError = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _resultText =
              'The API rejected the request: ${data['detail'] ?? response.body}';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _resultText =
            'Could not reach the API. Check your connection and try again.';
        _isError = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Expectancy Predictor'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the health and socioeconomic indicators for a country-year '
                  'to predict life expectancy.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _statusController,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    helperText: 'Type: Developing or Developed',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = _titleCase((value ?? '').trim());
                    if (v.isEmpty) return 'This field is required';
                    if (v != 'Developing' && v != 'Developed') {
                      return 'Must be "Developing" or "Developed"';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                ..._numericFields.map(_buildNumberField),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Predict', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
                if (_resultText != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isError
                          ? Colors.red.shade50
                          : Colors.teal.shade50,
                      border: Border.all(
                        color: _isError
                            ? Colors.red.shade200
                            : Colors.teal.shade200,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _resultText!,
                      style: TextStyle(
                        fontSize: 16,
                        color: _isError
                            ? Colors.red.shade900
                            : Colors.teal.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Widget _buildNumberField(FieldSpec field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[field.key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: field.label,
          helperText: 'Range: ${field.min} - ${field.max}',
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required';
          }
          final parsed = double.tryParse(value);
          if (parsed == null) {
            return 'Enter a valid number';
          }
          if (parsed < field.min || parsed > field.max) {
            return 'Must be between ${field.min} and ${field.max}';
          }
          if (field.isInt && parsed != parsed.roundToDouble()) {
            return 'Must be a whole number';
          }
          return null;
        },
      ),
    );
  }
}
