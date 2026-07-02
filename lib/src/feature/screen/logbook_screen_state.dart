part of 'logbook_screen.dart';

/// {@template log_viewer_screen_state}
/// Log viewer screen state.
/// {@endtemplate}
abstract class LogViewerScreenState extends State<LogViewerScreen> {
  /// Throttling for scroll to bottom
  late final Throttling<void> _scrollToBottomThrottling;

  /// Throttling for logs changed
  late final Throttling<void> _logsChangedThrottling;

  /// Scroll controller
  late final ScrollController _scrollController;

  /// Search focus node
  late final FocusNode _searchFocusNode;

  /// Is sending log to server
  late final ValueNotifier<bool> _isSendingLogToServer;

  /// Sending log to server enabled
  bool get _sendingLogToServerEnabled => widget.config.uri != null;

  /// Selected prefixes. Holds real prefixes only — the "All" checkbox state
  /// is derived ([_isAllSelected]), never stored.
  final ValueNotifier<Set<String>> _selectedFilter = ValueNotifier(<String>{});

  /// Whether the user has explicitly interacted with the filter
  bool _filterInteracted = false;

  /// Is search enabled
  bool _isSearchEnabled = false;

  /// Is user scrolled
  bool _isUserScrolled = false;

  /// Consumed logs count
  int _consumedLogsCount = 0;

  /// Log messages consumed from the buffer so far.
  final ValueNotifier<List<LogMessage>> _activeLogMessages = ValueNotifier(
    <LogMessage>[],
  );

  /// Search query
  String _searchQuery = '';

  /// Debounce timer for search input
  Timer? _searchDebounce;

  /// Whether the panel is currently visible (not dismissed).
  bool get _visible => !widget.dismissed.value;

  /// Whether some prefix is currently filtered out.
  bool get _isFiltering => LogBuffer.instance.logsPrefix.any(
    (p) => !_selectedFilter.value.contains(p),
  );

  /// Log messages filtered by prefix and search query.
  /// Cache the result in a local variable — do not
  /// call this getter more than once per frame.
  List<LogMessage> get _logMessages {
    var messages = _activeLogMessages.value;

    if (_isFiltering) {
      final selected = _selectedFilter.value;
      messages = messages
          .where((log) => selected.contains(log.prefix))
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final lower = _searchQuery.toLowerCase();
      messages = messages
          .where(
            (log) =>
                log.message.toLowerCase().contains(lower) ||
                log.prefix.toLowerCase().contains(lower) ||
                log.formattedTime.contains(lower),
          )
          .toList();
    }

    return messages;
  }

  /// Pulls new logs out of the buffer into [_activeLogMessages].
  void _consumeNewLogs() {
    final newLogs = LogBuffer.instance
        .logsSince(_consumedLogsCount)
        .toList(growable: false);
    _consumedLogsCount = LogBuffer.instance.totalLogsCount;

    if (newLogs.isEmpty) return;

    if (!_filterInteracted) {
      final selected = _selectedFilter.value;
      final newPrefixes = LogBuffer.instance.logsPrefix
          .where((p) => !selected.contains(p))
          .toList(growable: false);
      if (newPrefixes.isNotEmpty) {
        _selectedFilter.value = {...selected, ...newPrefixes};
      }
    }

    final combined = [..._activeLogMessages.value, ...newLogs];
    final limit = LogBuffer.instance.bufferLimit;
    _activeLogMessages.value = combined.length > limit
        ? combined.sublist(combined.length - limit)
        : combined;
  }

  /// Buffer listener — consumption is paused while the panel is hidden
  /// ([_onVisibilityChanged] catches up on open), so a closed logbook does
  /// no filtering/layout work.
  void _onLogsChangedListener() {
    if (!_visible) return;
    _logsChangedThrottling.throttle(_consumeNewLogs);
  }

  /// Reacts to the panel being opened or closed.
  void _onVisibilityChanged() {
    if (_visible) {
      _consumeNewLogs();
      _scrollToBottomListener();
    } else {
      FilterOverlay.hide();
    }
  }

  /// Method that handles the search tap
  void _onSearchTap() {
    setState(() {
      _isSearchEnabled = !_isSearchEnabled;
      if (!_isSearchEnabled) _searchQuery = '';
    });

    if (_isSearchEnabled) _searchFocusNode.requestFocus();
  }

  /// Handles search input — debounced to avoid
  /// per-keystroke rebuilds.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  /// Toggles a filter entry. `'All'` selects every prefix; deselecting the
  /// last remaining prefix snaps back to everything selected, so an empty
  /// selection is unreachable.
  void _onFilterTap(String value) {
    _filterInteracted = true;
    final prefixes = LogBuffer.instance.logsPrefix.toSet();
    final current = _selectedFilter.value;

    if (value == 'All') {
      _selectedFilter.value = prefixes;
    } else {
      final next = current.contains(value)
          ? ({...current}..remove(value))
          : {...current, value};
      _selectedFilter.value = next.isEmpty ? prefixes : next;
    }
  }

  /// Tracks whether the user scrolled away from the bottom (pauses
  /// auto-follow) or returned to it (resumes).
  bool _onScrolled(ScrollUpdateNotification notification) {
    final metrics = notification.metrics;
    // Only a user drag pauses auto-follow — programmatic auto-scroll
    // animations racing with new logs must not.
    if (notification.dragDetails != null &&
        metrics.pixels < metrics.maxScrollExtent - 100) {
      _isUserScrolled = true;
    } else if (metrics.pixels >= metrics.maxScrollExtent - 1) {
      _isUserScrolled = false;
    }
    return true;
  }

  /// Method that handles the scroll to bottom listener
  void _scrollToBottomListener() {
    if (!_visible) return;
    _scrollToBottomThrottling.throttle(() {
      if (_scrollController.hasClients && !_isUserScrolled) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Method that handles the scroll to bottom tap
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Method that handles the save and send to server tap
  Future<void> _onSaveAndSendToServerTap() async {
    if (!_sendingLogToServerEnabled) {
      l.w('Sending log to server is not enabled');

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text(
              'Sending log to server is not enabled please set server uri '
              '(optional: multipart file fields) in logbook config otherwise '
              'read logbook documentation for more information',
            ),
          ),
        );

      return;
    }

    if (_isSendingLogToServer.value) return;
    _isSendingLogToServer.value = true;

    HapticFeedback.selectionClick().ignore();

    final success = await LogBuffer.instance.sendLogsToServer(
      uri: widget.config.uri,
      debugFileName: widget.config.debugFileName,
      multipartFileFields: widget.config.multipartFileFields,
    );

    if (!mounted) return;
    _isSendingLogToServer.value = false;

    if (!success) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to send logs to the server. '
              'Check the server URI and your connection.',
            ),
          ),
        );
    }
  }

  /// Clears the on-screen list only — the underlying buffer keeps its logs,
  /// so a later server upload still contains the full history.
  void _onClearLogsTap() => _activeLogMessages.value = [];

  /* #region Lifecycle */
  @override
  void initState() {
    super.initState();

    _scrollToBottomThrottling = Throttling<void>(
      duration: const Duration(milliseconds: 500),
    );
    _logsChangedThrottling = Throttling<void>(
      duration: const Duration(milliseconds: 300),
    );

    _scrollController = ScrollController();
    _searchFocusNode = FocusNode();
    _isSendingLogToServer = ValueNotifier(false);

    LogBuffer.instance
      ..addListener(_scrollToBottomListener)
      ..addListener(_onLogsChangedListener);
    widget.dismissed.addListener(_onVisibilityChanged);

    // Seed with everything already in the buffer — logs recorded before the
    // Logbook widget mounted must be visible without waiting for a new log.
    _consumeNewLogs();
  }

  @override
  void didUpdateWidget(covariant LogViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.dismissed, widget.dismissed)) {
      oldWidget.dismissed.removeListener(_onVisibilityChanged);
      widget.dismissed.addListener(_onVisibilityChanged);
    }
  }

  @override
  void dispose() {
    FilterOverlay.hide();

    LogBuffer.instance
      ..removeListener(_onLogsChangedListener)
      ..removeListener(_scrollToBottomListener);
    widget.dismissed.removeListener(_onVisibilityChanged);

    _searchDebounce?.cancel();
    _isSendingLogToServer.dispose();
    _activeLogMessages.dispose();
    _selectedFilter.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();

    _logsChangedThrottling.close();
    _scrollToBottomThrottling.close();

    super.dispose();
  }

  /* #endregion */
}
