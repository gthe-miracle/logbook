import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../logbook.dart';
import '../../common/util/logger_colors.dart';
import '../../common/util/prefix_palette.dart';
import '../../common/util/throttling.dart';
import 'filter_overlay.dart';

part 'logbook_screen_state.dart';

/// {@template log_viewer_screen}
/// Log viewer screen.
/// {@endtemplate}
class LogViewerScreen extends StatefulWidget {
  /// {@macro log_viewer_screen}
  const new({required this.config, required this.dismissed, super.key});

  /// {@macro logbook_config}
  final LogbookConfig config;

  /// Whether the hosting panel is closed — while true the screen pauses log
  /// consumption to keep the closed logbook free of CPU work.
  final ValueListenable<bool> dismissed;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

/// State for [LogViewerScreen].
class _LogViewerScreenState extends LogViewerScreenState {
  @override
  Widget build(BuildContext context) {
    final colors = LoggerColors.of(context);

    return Scaffold(
      backgroundColor: colors.loggerBackground,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: colors.loggerBackground,
        title: _isSearchEnabled
            ? TextField(
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search…',
                ),
                style: TextStyle(
                  color: colors.consoleWhite,
                  letterSpacing: -0.5,
                ),
              )
            : Text(
                'Debug console',
                style: TextStyle(
                  color: colors.consoleWhite,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([_selectedFilter, LogBuffer.instance]),
            builder: (context, child) => IconButton(
              tooltip: 'Filter by prefix',
              onPressed: () => FilterOverlay.show(
                context,
                selectedFilters: _selectedFilter,
                onSelected: _onFilterTap,
              ),
              icon: Icon(
                Icons.filter_list_rounded,
                color: _isFiltering
                    ? colors.brilliantAzure
                    : colors.consoleWhite,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Search',
            onPressed: _onSearchTap,
            icon: Icon(Icons.search_rounded, color: colors.consoleWhite),
          ),

          IconButton(
            tooltip: 'Clear view (logs are kept for server upload)',
            onPressed: _onClearLogsTap,
            icon: Icon(
              Icons.delete_outline_outlined,
              color: colors.consoleWhite,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_activeLogMessages, _selectedFilter]),
        builder: (context, child) {
          final filteredLogs = _logMessages;

          return NotificationListener<ScrollUpdateNotification>(
            onNotification: _onScrolled,
            child: Scrollbar(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SelectionArea(
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverList.builder(
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          final logColor = colorForPrefix(log.prefix, colors);

                          final child = Text.rich(
                            style: const TextStyle(height: kTextHeightNone),
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '[${log.prefix}]',
                                  style: TextStyle(
                                    color: logColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: '[${log.formattedTime}] ',
                                  style: TextStyle(
                                    color: colors.brilliantAzure,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: log.message,
                                  style: TextStyle(
                                    color: logColor,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 11,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (index.isEven) {
                            return ColoredBox(
                              color: colors.gray.withAlpha(30),
                              child: child,
                            );
                          }
                          return child;
                        },
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 128)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 8,
        children: [
          ValueListenableBuilder(
            valueListenable: _isSendingLogToServer,
            builder: (context, isLoading, child) => FloatingActionButton(
              heroTag: null,
              tooltip: 'Send logs to server',
              backgroundColor: colors.consoleWhite,
              onPressed: _onSaveAndSendToServerTap,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (isLoading) {
                  true => RepaintBoundary(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        color: colors.loggerBackground,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ),
                  false => Icon(
                    Icons.upload_file,
                    color: colors.loggerBackground,
                  ),
                },
              ),
            ),
          ),
          FloatingActionButton(
            heroTag: null,
            tooltip: 'Scroll to bottom',
            backgroundColor: colors.consoleWhite,
            onPressed: _scrollToBottom,
            child: Icon(
              Icons.arrow_downward_rounded,
              color: colors.loggerBackground,
            ),
          ),
        ],
      ),
    );
  }
}
