library rendering_loop;

import 'dart:async';
import 'dart:html';

/// Phases in rendering of a frame. Rendering is proceeded to phases
/// in the order listed in this `enum`.
enum Phase {
  /// DOM modifications should be performed in this phase in a frame.
  update,

  /// DOM read-access that may cause reflow need to be performed in this phase
  /// in a frame.
  read,

  /// Tasks that need to be performed after all DOM accesses should be performed
  /// in this phase.
  wrapUp
}

/// [Loop] rendering frames over and over again.
class RenderingLoop {
  /// The number of phases defined in [Phase].
  static final int _phaseCount = Phase.values.length;

  /// [Zone] used to execute a frame rendering.
  Zone _renderingZone;

  /// The current [Phase] of this [RenderingLoop].
  Phase _currentPhase = null;

  /// [List] of microtasks pending execution.
  final List<Function> _microtasks = [];

  /// Designates if there is a requested animation frame pending.
  bool _isFramePending = false;

  /// [List] of [Completer]s notifying the entering into the corresponding
  /// [Phase]s.
  List<Completer<Null>> _phaseCompleters = new List(_phaseCount);

  /// [List] of [StreamController]s for each of [Phase]. Different
  /// from [_phaseCompleters], [_phaseControllers] are created
  /// only once.
  List<StreamController<Null>> _phaseControllers = new List.generate(
      _phaseCount, (_) => new StreamController.broadcast(sync: true));

  RenderingLoop() {
    _renderingZone = Zone.current.fork(
        specification:
        new ZoneSpecification(scheduleMicrotask: _scheduleMicrotask));
  }

  /// Returns whether a frame is being rendered or not.
  bool get isRendering => _currentPhase != null;

  /// Requests the given [phase] and returns a [Future] completed
  /// when the given phase begins. The returned [Future] is a one-shot,
  /// so when the [phase] is entered again, the returned [Future] won't
  /// be completed.
  Future<Null> enter(Phase phase) {
    if (_currentPhase == null || phase.index < _currentPhase.index) {
      // If the requested phase is already passed in this frame,
      // requests another frame.
      _requestFrame();
    }
    if (_phaseCompleters[phase.index] == null) {
      final completer =
      _phaseCompleters[phase.index] = new Completer<Null>.sync();
      _phaseControllers[phase.index].addStream(completer.future.asStream());
    }
    return _phaseCompleters[phase.index].future;
  }

  /// Returns a [Stream] being notified when the given [phase] enters.
  Stream<Null> onPhase(Phase phase) => _phaseControllers[phase.index].stream;

  /// Handles rendering of a frame.
  void _frameHandler(num time) {
    _renderingZone.run(() {
      _isFramePending = false;
      for (var phaseId = 0; phaseId < _phaseCount; phaseId++) {
        _currentPhase = Phase.values[phaseId];
        while (_phaseCompleters[phaseId] != null) {
          var completer = _phaseCompleters[phaseId];
          _phaseCompleters[phaseId] = null;
          completer.complete();
          _runMicrotasks();
        }
      }
      _currentPhase = null;
    });
  }

  /// Requests an animation frame.
  void _requestFrame() {
    if (!_isFramePending) {
      _isFramePending = true;
      window.requestAnimationFrame(_frameHandler);
    }
  }

  /// Runs all microtasks queued during the curent frame.
  void _runMicrotasks() {
    for (var task in _microtasks) {
      task();
    }
    _microtasks.clear();
  }

  /// Schedules the microtasks issued in a frame being rendered.
  void _scheduleMicrotask(Zone self, ZoneDelegate parent, Zone zone, task()) {
    if (_currentPhase != null) {
      _microtasks.add(task);
    } else {
      parent.scheduleMicrotask(zone, task);
    }
  }
}

final RenderingLoop renderingLoop = new RenderingLoop();
