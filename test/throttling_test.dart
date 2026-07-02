import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/src/common/util/throttling.dart';

void main() {
  group('Throttling', () {
    test('runs the first call immediately and returns its result', () {
      fakeAsync((async) {
        final throttling = Throttling<int>(
          duration: const Duration(milliseconds: 300),
        );
        addTearDown(throttling.close);

        expect(throttling.throttle(() => 42), 42);
        expect(throttling.isBusy, isTrue);
      });
    });

    test('suppresses calls during the busy window', () {
      fakeAsync((async) {
        final throttling = Throttling<int>(
          duration: const Duration(milliseconds: 300),
        );
        addTearDown(throttling.close);

        var calls = 0;
        int run() => ++calls;

        throttling.throttle(run);
        expect(throttling.throttle(run), isNull);
        expect(calls, 1);
      });
    });

    test('runs the latest suppressed call when the window expires', () {
      fakeAsync((async) {
        final throttling = Throttling<void>(
          duration: const Duration(milliseconds: 300),
        );
        addTearDown(throttling.close);

        final ran = <String>[];
        throttling
          ..throttle(() => ran.add('leading'))
          ..throttle(() => ran.add('stale'))
          ..throttle(() => ran.add('trailing'));

        expect(ran, ['leading']);

        async.elapse(const Duration(milliseconds: 300));
        expect(ran, ['leading', 'trailing']);
      });
    });

    test('trailing execution opens a new rate window', () {
      fakeAsync((async) {
        final throttling = Throttling<void>(
          duration: const Duration(milliseconds: 300),
        );
        addTearDown(throttling.close);

        var calls = 0;
        throttling
          ..throttle(() => calls++)
          ..throttle(() => calls++);

        async.elapse(const Duration(milliseconds: 300));
        expect(calls, 2);
        expect(throttling.isBusy, isTrue);

        async.elapse(const Duration(milliseconds: 300));
        expect(throttling.isIdle, isTrue);
      });
    });

    test('becomes idle after a quiet window', () {
      fakeAsync((async) {
        final throttling = Throttling<void>(
          duration: const Duration(milliseconds: 300),
        );
        addTearDown(throttling.close);

        throttling.throttle(() {});
        async.elapse(const Duration(milliseconds: 300));

        expect(throttling.isIdle, isTrue);
      });
    });

    test('close cancels the pending trailing call', () {
      fakeAsync((async) {
        final throttling = Throttling<int>(
          duration: const Duration(milliseconds: 300),
        );

        var calls = 0;
        throttling
          ..throttle(() => ++calls)
          ..throttle(() => ++calls)
          ..close();

        async.elapse(const Duration(seconds: 1));
        expect(calls, 1);
        expect(throttling.throttle(() => ++calls), isNull);
        expect(calls, 1);
      });
    });

    test('duration setter validates the new value', () {
      final throttling = Throttling<void>();
      addTearDown(throttling.close);

      expect(
        () => throttling.duration = const Duration(seconds: -1),
        throwsA(isA<AssertionError>()),
      );
      throttling.duration = const Duration(seconds: 2);
      expect(throttling.duration, const Duration(seconds: 2));
    });
  });
}
