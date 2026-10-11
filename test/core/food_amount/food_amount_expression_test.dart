import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/food_amount/food_amount_expression.dart';

void main() {
  for (final (text, expected) in [
    ('10+20', 30.0),
    ('10+20*3', 70.0),
    ('10+20×3', 70.0),
    ('100÷4-5', 20.0),
    ('-10 + 40', 30.0),
    ('10--20', 30.0),
    ('1,5 + .5', 2.0),
    (' 6 / 2 * 3 ', 9.0),
    ('30−10', 20.0),
    ('10 + -2 × 3', 4.0),
  ]) {
    test(
      text,
      () => expect(evaluateFoodAmount(text, arithmetic: true), expected),
    );
  }
  for (final text in [
    '',
    '10+',
    '1/0',
    '0/0',
    '(10+20)',
    'sin(1)',
    '1e3',
    '1 2',
    '1,,2',
    '2××3',
    '10/−0',
  ]) {
    test(
      'rejects $text',
      () => expect(
        () => evaluateFoodAmount(text, arithmetic: true),
        throwsFormatException,
      ),
    );
  }
  test('off accepts decimal comma but rejects expressions', () {
    expect(evaluateFoodAmount('53,5'), 53.5);
    expect(() => evaluateFoodAmount('10+20'), throwsFormatException);
  });
  test('rejects non-finite result', () {
    expect(
      () => evaluateFoodAmount('${'9' * 310}*10', arithmetic: true),
      throwsFormatException,
    );
  });
}
