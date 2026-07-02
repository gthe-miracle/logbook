import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../logbook.dart';
import '../../common/util/logger_colors.dart';
import '../screen/logbook_screen.dart';

part 'logbook_state.dart';

/// {@template Logbook}
/// Wraps your app with a slide-in log viewer overlay.
///
/// Only one [Logbook] should be mounted at a time — the configuration is
/// process-global ([Logbook.config]) and a second instance would overwrite
/// it.
/// {@endtemplate}
class Logbook extends StatefulWidget {
  /// {@macro Logbook}
  const Logbook({
    required this.child,
    LogbookConfig config = const LogbookConfig(),
    super.key,
  }) : _initialConfig = config;

  /// The configuration applied when the overlay first mounts.
  ///
  /// After mount, read or change the config at runtime via [Logbook.config].
  final LogbookConfig _initialConfig;

  /// The child widget to be displayed.
  ///
  /// Logbook will be displayed on top of this widget as an overlay.
  final Widget child;

  /// Single source of truth for the live config. Seeded from the constructor
  /// at mount; changed at runtime via [config].
  static final ValueNotifier<LogbookConfig> _configNotifier =
      ValueNotifier<LogbookConfig>(const LogbookConfig());

  /// The current Logbook configuration.
  ///
  /// The constructor sets the initial value; assign here to change it at any
  /// time and the overlay updates live, e.g.:
  /// `Logbook.config = Logbook.config.copyWith(themeMode: ThemeMode.dark);`
  static LogbookConfig get config => _configNotifier.value;

  static set config(LogbookConfig value) {
    _configNotifier.value = value;
    LogBuffer.instance.bufferLimit = value.bufferLimit;
  }

  /// Read-only listenable view of [config] for reacting to runtime changes.
  static ValueListenable<LogbookConfig> get configListenable => _configNotifier;

  /// State of the logbook widget, e.g. to open the panel programmatically:
  /// `Logbook.stateOf(context).open()`.
  static LogbookState stateOf(BuildContext context) =>
      context.findAncestorStateOfType<LogbookState>() ??
      (throw FlutterError(
        'Logbook.stateOf() was called with a context that does not contain '
        'a Logbook widget.',
      ));

  /// Sends the buffered logs to the server using the current [config].
  ///
  /// Returns true on success, false when no server URI is configured or the
  /// upload failed.
  static Future<bool> sendLogsToServer() {
    final config = _configNotifier.value;

    return LogBuffer.instance.sendLogsToServer(
      uri: config.uri,
      debugFileName: config.debugFileName,
      multipartFileFields: config.multipartFileFields,
    );
  }

  @override
  State<Logbook> createState() => _LogbookState();
}

/// State for widget [Logbook].
class _LogbookState extends LogbookState {
  /// Cached theme instances — building a ThemeData per frame is wasteful.
  static final ThemeData _lightTheme = ThemeData.light();
  static final ThemeData _darkTheme = ThemeData.dark();

  /// Provides the ambient scopes the overlay needs (text direction and
  /// Material localizations) when [Logbook] sits above `MaterialApp`
  /// instead of inside its `builder`. A no-op when they already exist, so
  /// the tree shape stays stable across `enabled` toggles either way.
  Widget _ambientScopes({required Widget child}) {
    final directed = Directionality.maybeOf(context) == null
        ? Directionality(textDirection: TextDirection.ltr, child: child)
        : child;

    return Localizations.maybeLocaleOf(context) == null
        ? Localizations(
            locale: const Locale('en'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: directed,
          )
        : directed;
  }

  Widget _panel(
    BuildContext context,
    BoxConstraints constraints,
    double width,
  ) => PositionedTransition(
    rect: _controller.drive(
      RelativeRectTween(
        begin: RelativeRect.fromLTRB(
          LogbookState._handleWidth - width,
          0,
          constraints.biggest.width - LogbookState._handleWidth,
          0,
        ),
        end: RelativeRect.fromLTRB(0, 0, constraints.biggest.width - width, 0),
      ),
    ),
    child: Theme(
      data:
          switch (Logbook.config.themeMode) {
            ThemeMode.light => _lightTheme,
            ThemeMode.dark => _darkTheme,
            _ => Theme.of(context),
          }.copyWith(
            textTheme: Theme.of(
              context,
            ).textTheme.apply(fontFamily: Logbook.config.fontFamily),
          ),
      child: SizedBox(
        width: width,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Visibility(
                visible: !_dismissed.value,
                maintainState: true,
                child: Material(
                  elevation: 0,
                  child: DefaultSelectionStyle(
                    child: ScaffoldMessenger(
                      child: HeroControllerScope.none(
                        child: Navigator(
                          pages: <Page<void>>[
                            MaterialPage<void>(
                              child: LogViewerScreen(
                                config: Logbook.config,
                                dismissed: _dismissed,
                              ),
                            ),
                          ],
                          onDidRemovePage: (page) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Align(
              child: SizedBox(
                width: LogbookState._handleWidth,
                height: 64,
                child: Material(
                  color: LoggerColors.of(context).consoleWhite,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(16),
                  ),
                  elevation: 0,
                  child: InkWell(
                    onTap: toggle,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(16),
                    ),
                    child: Center(
                      child: RotationTransition(
                        turns: _controller.drive(
                          Tween<double>(begin: 0, end: 0.5),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: LoggerColors.of(context).loggerBackground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = Logbook.config.enabled;

    // The tree shape must be identical whether the overlay is enabled or
    // not: `widget.child` stays at a stable element slot, so toggling
    // `enabled` at runtime never re-inflates (and thereby resets) the app.
    return _ambientScopes(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min<double>(400, constraints.biggest.width * 0.97);
          final interactive = enabled && !_dismissed.value;

          return GestureDetector(
            onHorizontalDragUpdate: interactive
                ? (details) => _onHorizontalDragUpdate(details, width)
                : null,
            onHorizontalDragEnd: interactive ? _onHorizontalDragEnd : null,
            child: Stack(
              alignment: Alignment.topLeft,
              children: <Widget>[
                widget.child,

                // Semi-transparent barrier behind the overlay when open
                if (interactive)
                  AnimatedModalBarrier(
                    color: _controller.drive(
                      ColorTween(
                        begin: Colors.transparent,
                        end: Colors.black.withAlpha(127),
                      ),
                    ),
                    dismissible: true,
                    semanticsLabel: 'Dismiss',
                    onDismiss: close,
                  ),

                if (enabled) _panel(context, constraints, width),
              ],
            ),
          );
        },
      ),
    );
  }
}
