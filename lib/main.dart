import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const BirdleApp());
}

class BirdleApp extends StatelessWidget {
  const BirdleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF467B68);
    return MaterialApp(
      title: 'Birdle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        scaffoldBackgroundColor: const Color(0xFFF7F7F2),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFFF7F7F2),
          foregroundColor: Color(0xFF26332D),
        ),
      ),
      home: const GamePage(),
    );
  }
}

enum LetterResult { empty, hit, partial, miss }

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const int wordLength = 5;
  static const int maxAttempts = 10;
  static const Color hitColor = Color(0xFF467B68);
  static const Color partialColor = Color(0xFFD6A746);
  static const Color missColor = Color(0xFF777C80);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final Random _random = Random();

  List<String> _dictionary = const [];
  final List<String> _guesses = [];
  String _answer = '';
  bool _loading = true;
  String? _loadError;
  bool _finished = false;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _loadDictionary();
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDictionary() async {
    try {
      final raw = await rootBundle.loadString('assets/words.txt');
      final words = raw
          .split(RegExp(r'\s+'))
          .map((word) => word.trim().toLowerCase())
          .where((word) => RegExp(r'^[а-яё]{5}$').hasMatch(word))
          .toSet()
          .toList()
        ..sort();

      if (words.isEmpty) {
        throw const FormatException('В словаре нет подходящих слов.');
      }

      if (!mounted) return;
      setState(() {
        _dictionary = words;
        _answer = words[_random.nextInt(words.length)];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Не удалось загрузить assets/words.txt. '
            'Проверьте файл словаря и pubspec.yaml.';
      });
    }
  }

  int get _attemptsMade => _guesses.length;

  int get _hintCount {
    if (_attemptsMade < 4 || _finished) return 0;
    return min(3, ((_attemptsMade - 4) ~/ 2) + 1);
  }

  List<LetterResult> _evaluate(String guess) {
    final result = List<LetterResult>.filled(wordLength, LetterResult.miss);
    final remaining = <String, int>{};

    for (var i = 0; i < wordLength; i++) {
      if (guess[i] == _answer[i]) {
        result[i] = LetterResult.hit;
      } else {
        remaining[_answer[i]] = (remaining[_answer[i]] ?? 0) + 1;
      }
    }

    for (var i = 0; i < wordLength; i++) {
      if (result[i] == LetterResult.hit) continue;
      final count = remaining[guess[i]] ?? 0;
      if (count > 0) {
        result[i] = LetterResult.partial;
        remaining[guess[i]] = count - 1;
      }
    }
    return result;
  }

  void _submitGuess() {
    if (_loading || _loadError != null || _finished) return;
    final guess = _controller.text.trim().toLowerCase();

    if (!RegExp(r'^[а-яё]{5}$').hasMatch(guess)) {
      _showMessage('Введите русское слово из 5 букв.');
      return;
    }
    if (!_dictionary.contains(guess)) {
      _showMessage('Такого слова нет в словаре.');
      return;
    }

    setState(() {
      _guesses.add(guess);
      _controller.clear();
      if (guess == _answer) {
        _won = true;
        _finished = true;
      } else if (_guesses.length >= maxAttempts) {
        _finished = true;
      }
    });

    if (_won) {
      _showMessage('Победа! Вы угадали слово.');
    } else if (_finished) {
      _showMessage('Попытки закончились. Ответ: ${_answer.toUpperCase()}');
    } else {
      _inputFocus.requestFocus();
    }
  }

  void _newGame() {
    if (_dictionary.isEmpty) return;
    setState(() {
      _answer = _dictionary[_random.nextInt(_dictionary.length)];
      _guesses.clear();
      _controller.clear();
      _finished = false;
      _won = false;
    });
    _inputFocus.requestFocus();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Color _colorFor(LetterResult result) {
    switch (result) {
      case LetterResult.hit:
        return hitColor;
      case LetterResult.partial:
        return partialColor;
      case LetterResult.miss:
        return missColor;
      case LetterResult.empty:
        return Colors.white;
    }
  }

  Widget _tile(String letter, LetterResult result, double size) {
    final filled = letter.isNotEmpty;
    final color = _colorFor(result);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: result == LetterResult.empty
              ? (filled ? hitColor.withOpacity(0.65) : const Color(0xFFD2D7D2))
              : color,
          width: 1.5,
        ),
      ),
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.43,
          fontWeight: FontWeight.w700,
          color: result == LetterResult.hit ||
                  result == LetterResult.miss ||
                  result == LetterResult.partial
              ? Colors.white
              : const Color(0xFF26332D),
        ),
      ),
    );
  }

  Widget _board(double maxWidth) {
    const gap = 5.0;
    final cellSize = min(48.0, (maxWidth - gap * (wordLength - 1)) / wordLength);
    final rows = <Widget>[];

    for (var row = 0; row < maxAttempts; row++) {
      final isSubmitted = row < _guesses.length;
      final isCurrent = row == _guesses.length && !_finished;
      final guess = isSubmitted
          ? _guesses[row]
          : isCurrent
              ? _controller.text.toLowerCase()
              : '';
      final feedback = isSubmitted
          ? _evaluate(guess)
          : List<LetterResult>.filled(wordLength, LetterResult.empty);

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < wordLength; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: gap / 2),
                  child: _tile(
                    i < guess.length ? guess[i] : '',
                    feedback[i],
                    cellSize,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hints = [
      for (var i = 0; i < _hintCount && i < _answer.length; i++)
        '${i + 1}-я буква — «${_answer[i].toUpperCase()}»',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BIRDLE'),
        actions: [
          IconButton(
            tooltip: 'Новая игра',
            onPressed: _loading || _loadError != null ? null : _newGame,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Column(
                children: [
                  const Text(
                    'Угадайте слово из 5 букв',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _loading
                        ? 'Загружаем словарь…'
                        : _loadError ??
                            (_won
                                ? 'Победа!'
                                : _finished
                                    ? 'Загаданное слово: ${_answer.toUpperCase()}'
                                    : 'Попытка ${_attemptsMade + 1} из $maxAttempts'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _loadError != null
                          ? Colors.red.shade700
                          : _won
                              ? hitColor
                              : const Color(0xFF59635D),
                    ),
                  ),
                  if (hints.isNotEmpty && !_finished)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Подсказка: ${hints.join(' · ')}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9B6B10),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: Center(child: _board(constraints.maxWidth)),
                        );
                      },
                    ),
                  ),
                  if (!_finished && !_loading && _loadError == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _inputFocus,
                              autofocus: false,
                              maxLength: wordLength,
                              textCapitalization: TextCapitalization.none,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[а-яА-ЯёЁ]'),
                                ),
                                LengthLimitingTextInputFormatter(wordLength),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Введите слово',
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _submitGuess(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _submitGuess,
                              child: const Icon(Icons.arrow_forward),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_finished)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        onPressed: _newGame,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Играть снова'),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'Зелёный — буква на месте · жёлтый — есть в слове · серый — нет в слове',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF69736D)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
