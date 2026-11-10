import 'dart:async';

/// Throttling status
enum ThrottlingStatus {
  /// Ready to accept new events
  idle,

  /// Waiting for the end of the pause
  busy;

  new();

  /// Ready to accept new events
  bool get isIdle => this == ThrottlingStatus.idle;

  /// Waiting for the end of the pause
  bool get isBusy => this == ThrottlingStatus.busy;

  @override
  String toString() => switch (this) {
    ThrottlingStatus.idle => 'idle',
    ThrottlingStatus.busy => 'busy',
  };
}

/// Throttling
/// Have method [throttle]
final class Throttling<T> extends Stream<ThrottlingStatus>
    implements Sink<T Function()> {
  /// Throttling
  /// Have method [throttle]
  /// Must be closed with [close] method
  new({Duration duration = const Duration(seconds: 1)})
    : assert(!duration.isNegative, 'Duration must be positive'),
      _duration = duration {
    _stateSC.sink.add(ThrottlingStatus.idle);
  }
  Duration _duration;

  /// Get current duration
  Duration get duration => _duration;

  /// Set new duration
  set duration(Duration value) {
    assert(!value.isNegative, 'Duration must be positive');
    _duration = value;
  }

  /// Timer
  Timer? _timer;

  /// The most recent function suppressed during the busy window, executed
  /// once (trailing edge) when the window expires.
  T Function()? _pending;

  /// Is ready to accept new events
  bool get isIdle => switch (_timer?.isActive) {
    true => false,
    _ => true,
  };

  /// Waiting for the end of the pause
  bool get isBusy => !isIdle;

  /// State controller
  final StreamController<ThrottlingStatus> _stateSC =
      StreamController<ThrottlingStatus>.broadcast(sync: true);

  /// Limits the maximum number of times a given
  /// event handler can be called over time.
  ///
  /// Runs [func] immediately when idle. Calls made during the busy window
  /// are coalesced: the latest one runs once when the window expires
  /// (trailing edge), so the final state is never silently dropped.
  ///
  /// Returns the result of the function, or null when the call was deferred
  /// to the trailing edge (its result is discarded).
  T? throttle(T Function() func) {
    if (_stateSC.isClosed) return null;
    if (!isIdle) {
      _pending = func;
      return null;
    }
    _startWindow();
    return func();
  }

  void _startWindow() {
    _timer = Timer(_duration, _onWindowExpired);
    _stateSC.sink.add(ThrottlingStatus.busy);
  }

  void _onWindowExpired() {
    _timer = null;
    if (_stateSC.isClosed) return;

    final pending = _pending;
    _pending = null;
    if (pending != null) {
      // Trailing edge: run the coalesced call and open a new window so the
      // configured rate still holds.
      _startWindow();
      pending();
    } else {
      _stateSC.sink.add(ThrottlingStatus.idle);
    }
  }

  @override
  StreamSubscription<ThrottlingStatus> listen(
    void Function(ThrottlingStatus status)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stateSC.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  /// Shortcut for [throttle] method
  @override
  T? add(T Function() data) => throttle(data);

  @override
  void close() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _stateSC.close().ignore();
  }
}
