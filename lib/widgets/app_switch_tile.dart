import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';

class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Material(
          color: AppTheme.cardColor,
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            dense: true,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            title: Text(title),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            value: value,
            onChanged: onChanged,
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 14,
            color: AppTheme.separatorColor,
          ),
      ],
    );
  }
}
