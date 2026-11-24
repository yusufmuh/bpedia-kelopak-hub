/// Building blocks shared by the Akun pages: page list, grouped cards,
/// navigation rows, notes, and navigation and snack bar helpers.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../widgets/widgets.dart';

/// Start of a list tile's title (padding 16 + icon 24 + gap 16); dividers and
/// inline blocks line up with it.
const double settingsTitleInset = BpSpace.s4 + BpSize.icon + BpSpace.s4;

/// Opens [page] on the app navigator with the platform page transition.
void pushAccountPage(BuildContext context, Widget page) {
  unawaited(
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (context) => page)),
  );
}

/// Replaces the visible snack bar with [message].
void showAccountSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Scrolling page body with 16 dp margins on phones and a centered column of
/// at most 560 dp on wide screens, so the whole width stays scrollable.
class AccountListView extends StatelessWidget {
  const AccountListView({super.key, required this.children});

  /// Page content, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          BpSpace.s4,
          (constraints.maxWidth - BpSize.contentMaxWidth) / 2,
        );
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side + insets.left,
            BpSpace.s4,
            side + insets.right,
            BpSpace.s8 + insets.bottom,
          ),
          children: children,
        );
      },
    );
  }
}

/// White card holding rows separated by dividers aligned with the titles.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  /// Rows, usually [SettingsNavTile] or [SwitchListTile].
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              const Divider(indent: settingsTitleInset, endIndent: BpSpace.s4),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Row that opens another page: icon, title, optional detail and a chevron.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  /// Leading icon (24 dp).
  final Widget icon;

  /// Row title.
  final String title;

  /// Current state or a short description.
  final String? subtitle;

  /// Opens the destination.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = subtitle;
    // Its own node: nothing from the neighbouring rows of the group is read
    // as part of this link.
    return MergeSemantics(
      child: ListTile(
        shape: const RoundedRectangleBorder(),
        leading: icon,
        title: Text(title),
        subtitle: detail == null ? null : Text(detail),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Quiet explanatory line with a leading icon.
class InfoNote extends StatelessWidget {
  const InfoNote(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
  });

  /// Explanation.
  final String text;

  /// Leading icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: BpSpace.s2),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium!.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
