import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../common/util/logger_colors.dart';
import '../logbook/log_buffer.dart';

/// {@template filter_overlay}
/// Dropdown-style overlay with one checkbox per known log prefix plus an
/// "All" row. The "All" state is derived (checked when every prefix is
/// selected), and the list live-updates as new prefixes arrive.
/// {@endtemplate}
class FilterOverlay extends StatelessWidget {
  /// {@macro filter_overlay}
  const FilterOverlay({
    required this.onSelected,
    required this.selectedFilters,
    super.key,
  });

  /// Currently selected prefixes.
  final ValueListenable<Set<String>> selectedFilters;

  /// Callback function that is called when a filter is selected.
  final void Function(String value) onSelected;

  static OverlayEntry? _currentEntry;

  /// Hides the filter overlay.
  static void hide() {
    _currentEntry
      ?..remove()
      ..dispose();
    _currentEntry = null;
  }

  /// Shows the filter overlay.
  static void show(
    BuildContext context, {
    required final ValueListenable<Set<String>> selectedFilters,
    required final void Function(String value) onSelected,
  }) {
    hide();

    final overlayEntry = OverlayEntry(
      builder: (context) => FilterOverlay(
        onSelected: onSelected,
        selectedFilters: selectedFilters,
      ),
    );

    _currentEntry = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    final colors = LoggerColors.of(context);

    return Positioned.fill(
      child: InkWell(
        onTap: hide,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(
              top: 30,
              left: 8,
              right: 60,
              bottom: 8,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.loggerBackground,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(
                  color: colors.gray.withValues(alpha: .3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 180,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      selectedFilters,
                      LogBuffer.instance,
                    ]),
                    builder: (context, child) {
                      final selected = selectedFilters.value;
                      final prefixes = LogBuffer.instance.logsPrefix.toList(
                        growable: false,
                      );
                      final allSelected =
                          prefixes.isNotEmpty &&
                          prefixes.every(selected.contains);

                      return Column(
                        spacing: 4,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FilterRow(
                            label: 'All',
                            isSelected: allSelected,
                            showDivider: false,
                            onTap: () => onSelected('All'),
                          ),
                          for (final prefix in prefixes)
                            _FilterRow(
                              label: prefix,
                              isSelected: selected.contains(prefix),
                              showDivider: true,
                              onTap: () => onSelected(prefix),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single checkbox row of the filter overlay.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.isSelected,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = LoggerColors.of(context);

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Checkbox(
          value: isSelected,
          onChanged: null,
          tristate: true,
          checkColor: colors.consoleWhite,
          fillColor: WidgetStateProperty.all(
            isSelected ? colors.brilliantAzure : Colors.transparent,
          ),
          overlayColor: WidgetStateProperty.all(colors.brilliantAzure),
          side: BorderSide(
            width: 1.5,
            color: isSelected ? colors.brilliantAzure : colors.gray,
          ),
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colors.brilliantAzure : colors.consoleWhite,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return SizedBox(
      height: 40,
      child: InkWell(
        onTap: onTap,
        child: !showDivider
            ? row
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(color: colors.gray.withValues(alpha: .3), height: .1),
                  Expanded(child: row),
                ],
              ),
      ),
    );
  }
}
