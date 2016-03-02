@TestOn('browser')
import 'dart:async';

import 'package:rendering_loop/rendering_loop.dart';
import 'package:test/test.dart';

main() {
  group('RenderingLoop', () {
    RenderingLoop loop;

    setUp(() {
      loop = new RenderingLoop();
    });

    test('run single task and check if they proceed in phases', () async {
      final result = [];

      task() async {
        result.add('null');
        await loop.enter(Phase.update);
        result.add('update');
        await loop.enter(Phase.read);
        result.add('read');
        await loop.enter(Phase.wrapUp);
        result.add('wrapUp');
      }

      await task();

      expect(result, ['null', 'update', 'read', 'wrapUp']);
    });

    test('run two tasks and check if they proceed in phases', () async {
      final result = [];

      task1() async {
        result.add('1: null');
        await loop.enter(Phase.update);
        result.add('1: update');
        await loop.enter(Phase.read);
        result.add('1: read');
      }

      task2() async {
        result.add('2: null');
        await loop.enter(Phase.read);
        result.add('2: read');
        await loop.enter(Phase.wrapUp);
        result.add('2: wrapUp');
      }

      await Future.wait([task1(), task2()]);

      expect(result, [
        '1: null',
        '2: null',
        '1: update',
        '2: read',
        '1: read',
        '2: wrapUp'
      ]);
    });

    test('run three tasks and check if they proceed in phases', () async {
      final result = [];

      task1() async {
        result.add('1: null');
        await loop.enter(Phase.update);
        result.add('1: update');
        await loop.enter(Phase.read);
        result.add('1: read');
      }

      task2() async {
        result.add('2: null');
        await loop.enter(Phase.read);
        result.add('2: read');
        await loop.enter(Phase.wrapUp);
        result.add('2: wrapUp');
      }

      task3() async {
        result.add('3: null');
        await loop.enter(Phase.update);
        result.add('3: update');
        await loop.enter(Phase.read);
        result.add('3: read');
        await loop.enter(Phase.wrapUp);
        result.add('3: wrapUp');
      }

      await Future.wait([task1(), task2(), task3()]);

      expect(result, [
        '1: null',
        '2: null',
        '3: null',
        '1: update',
        '3: update',
        '2: read',
        '1: read',
        '3: read',
        '2: wrapUp',
        '3: wrapUp'
      ]);
    });

    test('async function in a phase should work in the phase', () async {
      final result = [];

      task1() async {
        result.add('1: null');
        await loop.enter(Phase.update);
        result.add('1: update');
        await loop.enter(Phase.read);
        result.add('1: read');
      }

      asyncFunc() async {
        result.add('2: read - async function');
      }

      task2() async {
        result.add('2: null');
        await loop.enter(Phase.read);
        result.add('2: read');
        await asyncFunc();
        await loop.enter(Phase.wrapUp);
        result.add('2: wrapUp');
      }

      await Future.wait([task1(), task2()]);

      expect(result, [
        '1: null',
        '2: null',
        '1: update',
        '2: read',
        '1: read',
        '2: read - async function',
        '2: wrapUp'
      ]);
    });

    test('should process a phase already passed in the next frame', () async {
      final result = [];

      task1() async {
        result.add('1: null');
        await loop.enter(Phase.update);
        result.add('1: update');
        await loop.enter(Phase.read);
        result.add('1: read');
      }

      task2() async {
        result.add('2: null');
        await loop.enter(Phase.read);
        result.add('2: read');
        await loop.enter(Phase.update);
        result.add('2: update');
      }

      await Future.wait([task1(), task2()]);

      expect(result, [
        '1: null',
        '2: null',
        '1: update',
        '2: read',
        '1: read',
        '2: update'
      ]);
    });

    test('should notify phase stream only once per entrance', () async {
      final result = [];

      loop.enter(Phase.update);
      loop.enter(Phase.update);
      loop.enter(Phase.update);

      loop.onPhase(Phase.update).listen((_) => result.add('notified'));
      await loop.enter(Phase.wrapUp);

      expect(result, hasLength(1));
    });

    test('should notify phase stream every time a phase enters', () async {
      final result = [];

      loop.onPhase(Phase.update).listen((_) => result.add('notified'));

      await loop.enter(Phase.update);
      await loop.enter(Phase.wrapUp);

      await loop.enter(Phase.update);
      await loop.enter(Phase.wrapUp);

      await loop.enter(Phase.update);
      await loop.enter(Phase.wrapUp);

      expect(result, hasLength(3));
    });
  });
}
