/// Decimal amounts, optionally with four arithmetic operators and unary signs.
/// No evaluation of executable code, functions or parentheses.
double evaluateFoodAmount(String input, {bool arithmetic = false}) {
  if (!arithmetic) {
    final text = input.trim();
    if (!RegExp(r'^(?:\d+(?:[.,]\d*)?|[.,]\d+)$').hasMatch(text)) {
      throw const FormatException('Invalid amount');
    }
    final result = double.parse(text.replaceAll(',', '.'));
    if (!result.isFinite) throw const FormatException('Non-finite amount');
    return result;
  }
  return _AmountParser(input).parse();
}

class _AmountParser {
  _AmountParser(this.text);
  final String text;
  int at = 0;
  void _spaces() {
    while (at < text.length && RegExp(r'\s').hasMatch(text[at])) {
      at++;
    }
  }

  bool _take(String symbols) {
    _spaces();
    if (at < text.length && symbols.contains(text[at])) {
      at++;
      return true;
    }
    return false;
  }

  double _number() {
    var sign = 1.0;
    _spaces();
    while (at < text.length && '+-−'.contains(text[at])) {
      if (text[at] != '+') sign = -sign;
      at++;
      _spaces();
    }
    final match = RegExp(
      r'(?:\d+(?:[.,]\d*)?|[.,]\d+)',
    ).matchAsPrefix(text, at);
    if (match == null) throw const FormatException('Expected number');
    at = match.end;
    return sign * double.parse(match.group(0)!.replaceAll(',', '.'));
  }

  double _term() {
    var result = _number();
    while (true) {
      if (_take('*×')) {
        result *= _number();
      } else if (_take('/÷')) {
        final divisor = _number();
        if (divisor == 0) throw const FormatException('Division by zero');
        result /= divisor;
      } else {
        return result;
      }
    }
  }

  double parse() {
    var result = _term();
    while (true) {
      if (_take('+')) {
        result += _term();
      } else if (_take('-−')) {
        result -= _term();
      } else {
        break;
      }
    }
    _spaces();
    if (at != text.length || !result.isFinite) {
      throw const FormatException('Invalid expression');
    }
    return result;
  }
}
