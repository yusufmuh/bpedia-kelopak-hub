import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/tokens.dart';

/// Shows the dismissible result sheet used after claims, spins, orders and missions.
///
/// Buttons close the sheet first, then run their callback. The title and
/// lines are announced to screen readers. Completes when the sheet closes.
Future<void> showRewardResultSheet(
  BuildContext context, {
  required String title,
  required List<String> lines,
  String? imageAsset,
  required String primaryLabel,
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _RewardResultSheet(
      title: title,
      lines: lines,
      imageAsset: imageAsset,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    ),
  );
}

class _RewardResultSheet extends StatefulWidget {
  const _RewardResultSheet({
    required this.title,
    required this.lines,
    required this.imageAsset,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String title;
  final List<String> lines;
  final String? imageAsset;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  State<_RewardResultSheet> createState() => _RewardResultSheetState();
}

class _RewardResultSheetState extends State<_RewardResultSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final message = <String>[widget.title, ...widget.lines].join('. ');
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          message,
          Directionality.of(context),
        ),
      );
    });
  }

  void _close(VoidCallback? then) {
    Navigator.of(context).pop();
    then?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = widget.imageAsset;
    final secondary = widget.secondaryLabel;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(BpSpace.s6, 0, BpSpace.s6, BpSpace.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (image != null) ...<Widget>[
            Image.asset(
              image,
              height: 120,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            const SizedBox(height: BpSpace.s4),
          ],
          Semantics(
            header: true,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ),
          for (final line in widget.lines) ...<Widget>[
            const SizedBox(height: BpSpace.s2),
            Text(
              line,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: BpSpace.s6),
          FilledButton(
            onPressed: () => _close(widget.onPrimary),
            child: Text(widget.primaryLabel, textAlign: TextAlign.center),
          ),
          if (secondary != null) ...<Widget>[
            const SizedBox(height: BpSpace.s2),
            TextButton(
              onPressed: () => _close(widget.onSecondary),
              child: Text(secondary, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}
