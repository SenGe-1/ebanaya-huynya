import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const BirdleApp());
}

const fallbackWords = <String>[
  'время', 'жизнь', 'слово', 'место', 'город', 'земля', 'часть',
  'конец', 'народ', 'образ', 'мысль', 'книга', 'голос', 'право',
  'война', 'дверь', 'число', 'князь', 'улица', 'форма', 'вечер',
  'месяц', 'закон', 'берег', 'школа', 'стена', 'театр', 'смысл',
  'связь', 'наука', 'ответ', 'армия', 'совет', 'семья', 'рубль',
  'плечо', 'автор', 'гость', 'огонь', 'черта', 'глава', 'кровь',
];

class BirdleApp extends StatelessWidget {
  const BirdleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Birdle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF467B68)),
        scaffoldBackgroundColor: const Color(0xFFF7F7F2),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const wordLength = 5;
  static const maxAttempts = 6;

  List<String> _dictionary = fallbackWords;
  late String _answer;
  final List<String> _guesses = [];
  String _currentGuess = '';
  bool _finished = false;
  bool _won = false;
  bool _loadingDictionary = true;

  @override
  void initState() {
    super.initState();
    _answer = fallbackWords[Random().nextInt(fallbackWords.length)];
    _loadDictionary();
  }

  Future<void> _loadDictionary() async {
    try {
      final raw = await rootBundle.loadString('assets/words.txt');
      final words = raw
          .split(RegExp(r'\s+'))
          .map((word) => word.trim().toLowerCase())
          .where((word) => RegExp(r'^[а-яё]{5}$').hasMatch(word))
          .toSet()
          .toList();
      if (words.isNotEmpty && mounted) {
        setState(() {
          _dictionary = words;
          _answer = words[Random().nextInt(words.length)];
        });
      }
    } catch (_) {
      // The built-in starter dictionary keeps the game playable until
      // assets/words.txt is added to the project.
    } finally {
      if (mounted) setState(() => _loadingDictionary = false);
    }
  }

  void _typeLetter(String letter) {
    if (_finished || _currentGuess.length >= wordLength) return;
    setState(() => _currentGuess += letter.toLowerCase());
  }

  void _backspace() {
    if (_finished || _currentGuess.isEmpty) return;
    setState(() => _currentGuess =
        _currentGuess.substring(0, _currentGuess.length - 1));
  }

  void _submitGuess() {
    if (_finished) return;
    if (_currentGuess.length != wordLength) {
      _message('Введите слово из 5 букв');
      return;
    }
    if (!_dictionary.contains(_currentGuess)) {
      _message('Этого слова нет в словаре');
      return;
    }
    setState(() {
      _guesses.add(_currentGuess);
      _won = _currentGuess == _answer;
      _finished = _won || _guesses.length >= maxAttempts;
      _currentGuess = '';
    });
    if (_won) {
      _message('Верно! Вы угадали слово.');
    } else if (_finished) {
      _message('Попытки закончились. Ответ: $_answer');
    }
  }

  void _newGame() {
    setState(() {
      _answer = _dictionary[Random().nextInt(_dictionary.length)];
      _guesses.clear();
      _currentGuess = '';
      _finished = false;
      _won = false;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Color _tileColor(String guess, int index) {
    final letter = guess[index];
    if (_answer[index] == letter) return const Color(0xFF467B68);
    if (_answer.contains(letter)) return const Color(0xFFD6A746);
    return const Color(0xFF777C80);
  }

  Widget _tile(String? guess, int index, {bool current = false}) {
    final letter = guess != null && index < guess.length ? guess[index] : '';
    final color = guess == null
        ? Colors.white
        : current
            ? Colors.white
            : _tileColor(guess, index);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: guess == null || current
              ? const Color(0xFFD2D7D2)
              : color,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: guess == null || current ? const Color(0xFF26332D) : Colors.white,
        ),
      ),
    );
  }

  Widget _keyboardKey(String label, {VoidCallback? onTap, double flex = 1}) {
    return Expanded(
      flex: (flex * 10).round(),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          height: 45,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: _finished ? null : onTap,
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var row = 0; row < maxAttempts; row++) {
      final guess = row < _guesses.length
          ? _guesses[row]
          : row == _guesses.length
              ? _currentGuess
              : null;
      rows.add(
        Expanded(
          child: Row(
            children: List.generate(
              wordLength,
              (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _tile(
                    guess,
                    index,
                    current: row == _guesses.length && !_finished,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    const keyboardRows = [
      'йцукенгшщзхъ',
      'фывапролджэ',
      'ячсмитьбю',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Birdle — 5 букв'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Новая игра',
            onPressed: _newGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text('Угадайте русское слово за 6 попыток'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Text(
                'Зелёный — буква на месте · жёлтый — буква есть в слове',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(children: rows),
              ),
            ),
            if (_loadingDictionary)
              const Padding(
                padding: EdgeInsets.all(4),
                child: Text('Загрузка словаря…', style: TextStyle(fontSize: 12)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  for (final row in keyboardRows)
                    Row(
                      children: [
                        for (final letter in row.split(''))
                          _keyboardKey(letter, onTap: () => _typeLetter(letter)),
                      ],
                    ),
                  Row(
                    children: [
                      _keyboardKey('⌫', flex: 1.5, onTap: _backspace),
                      _keyboardKey('ВВОД', flex: 2, onTap: _submitGuess),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_finished)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton.icon(
                  onPressed: _newGame,
                  icon: const Icon(Icons.refresh),
                  label: Text(_won ? 'Сыграть ещё' : 'Попробовать снова'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
