import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/retry_util.dart';

class _BoomError implements Exception {
  final String message;
  _BoomError(this.message);
  @override
  String toString() => 'BoomError($message)';
}

void main() {
  group('withRetry', () {
    test('returns the result on first success without retrying', () async {
      var calls = 0;
      final result = await withRetry(() async {
        calls++;
        return 42;
      });

      expect(result, equals(42));
      expect(calls, equals(1));
    });

    test('rethrows immediately when shouldRetry returns false', () async {
      var calls = 0;
      Object? caught;

      try {
        await withRetry<int>(
          () async {
            calls++;
            throw _BoomError('non-retriable');
          },
          attempts: 5,
          shouldRetry: (_) => false,
        );
      } catch (e) {
        caught = e;
      }

      expect(
        calls,
        equals(1),
        reason: 'must not retry when shouldRetry returns false',
      );
      expect(caught, isA<_BoomError>());
    });

    test('rethrows immediately on attempts=1', () async {
      var calls = 0;
      Object? caught;
      try {
        await withRetry<int>(() async {
          calls++;
          throw _BoomError('first try');
        }, attempts: 1);
      } catch (e) {
        caught = e;
      }

      expect(calls, equals(1));
      expect(caught, isA<_BoomError>());
    });

    test('shouldRetry can inspect error type to decide', () async {
      var calls = 0;
      Object? caught;

      try {
        await withRetry<int>(
          () async {
            calls++;
            throw StateError('always non-retriable');
          },
          attempts: 5,
          shouldRetry: (e) => e is _BoomError,
        );
      } catch (e) {
        caught = e;
      }

      expect(calls, equals(1));
      expect(caught, isA<StateError>());
    });

    test('retries only at each exponential backoff boundary', () {
      fakeAsync((time) {
        var calls = 0;
        int? result;
        withRetry<int>(() async {
          calls++;
          if (calls < 3) throw _BoomError('retry');
          return 7;
        }).then((value) => result = value);
        time.flushMicrotasks();
        expect(calls, 1);
        time.elapse(const Duration(milliseconds: 999));
        expect(calls, 1);
        time.elapse(const Duration(milliseconds: 1));
        expect(calls, 2);
        time.elapse(const Duration(milliseconds: 1999));
        expect(calls, 2);
        expect(result, isNull);
        time.elapse(const Duration(milliseconds: 1));
        expect(calls, 3);
        expect(result, 7);
        expect(time.pendingTimers, isEmpty);
      });
    });

    test('exhaustion propagates the final error without another retry', () {
      fakeAsync((time) {
        var calls = 0;
        final error = _BoomError('last attempt');
        Object? caught;
        withRetry<int>(() async {
          calls++;
          throw error;
        }, attempts: 2).catchError((Object failure) {
          caught = failure;
          return 0;
        });
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 1));
        expect(calls, 2);
        expect(caught, same(error));
        expect(time.pendingTimers, isEmpty);
      });
    });
  });
}
