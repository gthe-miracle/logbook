part of 'logbook.dart';

/// {@template logbook_state}
/// State of the [Logbook] overlay, obtainable via [Logbook.stateOf].
///
/// Exposes [open], [close] and [toggle] to control the panel
/// programmatically.
/// {@endtemplate}
abstract class LogbookState extends State<Logbook>
    with SingleTickerProviderStateMixin {
  /// {@macro logbook_state}
  LogbookState();

  /// Animation controller driving the slide-in panel.
  late final AnimationController _controller;

  /// Whether the panel is fully closed. Also passed to the viewer so it can
  /// pause log consumption while hidden.
  late final ValueNotifier<bool> _dismissed;

  /// Width of the always-visible handle at the panel edge.
  static const double _handleWidth = 16;

  /// Whether the panel is currently open (or opening).
  bool get isOpen => !_dismissed.value;

  /// Opens the log viewer panel.
  void open() => _controller.forward();

  /// Closes the log viewer panel.
  void close() => _controller.reverse();

  /// Toggles the log viewer panel.
  void toggle() => _controller.toggle();

  /// Updates the panel position while the user drags it horizontally.
  void _onHorizontalDragUpdate(DragUpdateDetails details, double width) {
    if (_dismissed.value) return;

    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final delta = details.delta.dx * (isRtl ? -1 : 1);
    _controller.value = (_controller.value + delta / width).clamp(0.0, 1.0);
  }

  /// Settles the panel open or closed when the drag ends.
  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dismissed.value) return;

    final velocity = details.primaryVelocity ?? 0;
    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;

    if ((isRtl ? -velocity : velocity) > 300 || _controller.value > 0.5) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  /// Keeps [_dismissed] in sync with the animation status.
  void _onStatusChanged(AnimationStatus status) => switch (status) {
    _ when !mounted => null,
    AnimationStatus.dismissed => () {
      if (_dismissed.value) return;
      setState(() => _dismissed.value = true);
    }(),
    _ => () {
      if (!_dismissed.value) return;
      setState(() => _dismissed.value = false);
    }(),
  };

  /* #region Lifecycle */
  @override
  void initState() {
    super.initState();
    // The constructor config is the initial value; runtime changes go
    // through Logbook.config and are reflected here via _onConfigChanged.
    // Skipped when equal so a remount does not re-notify listeners.
    if (Logbook.config != widget._initialConfig) {
      Logbook.config = widget._initialConfig;
    } else {
      LogBuffer.instance.bufferLimit = widget._initialConfig.bufferLimit;
    }
    Logbook._configNotifier.addListener(_onConfigChanged);
    _dismissed = ValueNotifier(true);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener(_onStatusChanged);
  }

  /// Rebuilds the overlay when the config changes at runtime.
  void _onConfigChanged() {
    if (!mounted) return;
    // Disabling the overlay snaps the panel shut so a later re-enable does
    // not surprise the user with an already-open panel.
    if (!Logbook.config.enabled && !_dismissed.value) _controller.value = 0;
    setState(() {});
  }

  @override
  void dispose() {
    Logbook._configNotifier.removeListener(_onConfigChanged);
    _controller
      ..removeStatusListener(_onStatusChanged)
      ..dispose();
    _dismissed.dispose();

    super.dispose();
  }

  /* #endregion */
}
