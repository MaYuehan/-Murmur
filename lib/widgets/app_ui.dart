import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';

class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({
    super.key,
    required this.children,
    this.backgroundColor,
  });

  final List<Widget> children;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Label with a hand-drawn chalk-style underline.
class AppChalkUnderlineLabel extends StatelessWidget {
  const AppChalkUnderlineLabel({
    super.key,
    required this.label,
    this.style,
    this.underlineColor = AppTheme.primaryColor,
    this.underlineOverlap = 1,
  });

  final String label;
  final TextStyle? style;
  final Color underlineColor;
  /// How far the underline rises into the text (px).
  final double underlineOverlap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: -2,
            right: -2,
            bottom: underlineOverlap,
            height: 10,
            child: CustomPaint(
              painter: _ChalkUnderlinePainter(color: underlineColor),
              child: const SizedBox.expand(),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ),
    );
  }
}

class _ChalkUnderlinePainter extends CustomPainter {
  const _ChalkUnderlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final double midY = size.height * 0.85;
    const double amplitude = 0.8;
    const double waveLength = 0.13;

    Path buildWave({double yOffset = 0}) {
      final Path path = Path();
      path.moveTo(0, midY + yOffset + math.sin(0) * amplitude);
      for (double x = 1; x <= size.width; x++) {
        final double wobble = math.sin(x * waveLength) * amplitude;
        final double chalkMark = (x % 13).round() == 0 ? 0.4 : 0;
        path.lineTo(x, midY + yOffset + wobble + chalkMark);
      }
      return path;
    }

    final Paint softChalk = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint chalk = Paint()
      ..color = color
      ..strokeWidth = 3.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(buildWave(yOffset: 0.8), softChalk);
    canvas.drawPath(buildWave(), chalk);
  }

  @override
  bool shouldRepaint(covariant _ChalkUnderlinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Swipe area with a very faint warm yellow tint.
class AppInsetPanel extends StatelessWidget {
  const AppInsetPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.only(top: 8),
    this.radius = 10,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  static Color get insetBackgroundColor =>
      AppTheme.primaryColor.withValues(alpha: 0.025);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: insetBackgroundColor,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppSegmentOption<T> {
  const AppSegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Compact text tabs with a yellow underline on the selected item.
class AppUnderlineTabControl<T> extends StatelessWidget {
  const AppUnderlineTabControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.tabGap = 14,
  });

  final List<AppSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double tabGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) SizedBox(width: tabGap),
          _AppUnderlineTab(
            label: options[i].label,
            selected: options[i].value == selected,
            onTap: () => onChanged(options[i].value),
          ),
        ],
      ],
    );
  }
}

class _AppUnderlineTab extends StatelessWidget {
  const _AppUnderlineTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppTheme.textPrimaryColor
                        : AppTheme.secondaryLabelColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 2,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppChipSegmentedControl<T> extends StatelessWidget {
  const AppChipSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const double radius = 999;

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: options.map((AppSegmentOption<T> option) {
            final bool isSelected = option.value == selected;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(option.value),
                  borderRadius: BorderRadius.circular(radius),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? scheme.primary
                            : AppTheme.secondaryLabelColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final List<AppSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 9 : 11),
      ),
      child: Row(
        children: options.map((AppSegmentOption<T> option) {
          final bool isSelected = option.value == selected;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(option.value),
                borderRadius: BorderRadius.circular(compact ? 7 : 9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(vertical: compact ? 5 : 9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.cardColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(compact ? 7 : 9),
                    boxShadow: isSelected
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.textPrimaryColor
                          : AppTheme.secondaryLabelColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 8),
    this.style = AppSectionHeaderStyle.standard,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;
  final AppSectionHeaderStyle style;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = switch (style) {
      AppSectionHeaderStyle.standard => Theme.of(context).textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w700,
          ),
      AppSectionHeaderStyle.caption => const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppTheme.secondaryLabelColor,
            letterSpacing: -0.08,
          ),
    };

    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: textStyle),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

enum AppSectionHeaderStyle { standard, caption }

class AppGroupedTextField extends StatelessWidget {
  const AppGroupedTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.showDivider = true,
    this.validator,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final bool showDivider;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            maxLines > 1 ? 10 : 2,
            16,
            maxLines > 1 ? 10 : 2,
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            textInputAction: textInputAction,
            onChanged: onChanged,
            validator: validator,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hintText,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintStyle: const TextStyle(
                color: AppTheme.secondaryLabelColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            endIndent: 0,
            color: AppTheme.separatorColor,
          ),
      ],
    );
  }
}

class AppPickerTile extends StatelessWidget {
  const AppPickerTile({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.showDivider = true,
    this.valueColor,
    this.placeholder = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showDivider;
  final Color? valueColor;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final Color resolvedValueColor = placeholder
        ? AppTheme.secondaryLabelColor
        : (valueColor ?? AppTheme.iosBlue);

    return Column(
      children: <Widget>[
        Material(
          color: AppTheme.cardColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: resolvedValueColor,
                          ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            color: AppTheme.separatorColor,
          ),
      ],
    );
  }
}

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.showDivider = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Material(
          color: AppTheme.cardColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 18, color: AppTheme.iosBlue),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.iosBlue,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            color: AppTheme.separatorColor,
          ),
      ],
    );
  }
}

class AppFootnote extends StatelessWidget {
  const AppFootnote({
    super.key,
    required this.text,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final String text;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

/// White grouped card — matches [ReminderDetailPage] sections.
class AppDetailSection extends StatelessWidget {
  const AppDetailSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class AppDetailTile extends StatelessWidget {
  const AppDetailTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
    this.multiline = false,
    this.placeholder = false,
    this.showDivider = true,
    this.expanded = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool multiline;
  final bool placeholder;
  final bool showDivider;
  final bool expanded;

  static const double _dividerIndent = 56;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color valueColor =
        placeholder ? scheme.onSurfaceVariant : AppTheme.textPrimaryColor;

    return Column(
      children: <Widget>[
        Material(
          color: AppTheme.cardColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 17, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          value,
                          maxLines: multiline ? null : 2,
                          overflow: multiline ? null : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: valueColor,
                            height: 1.35,
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onTap != null) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: _dividerIndent,
            color: Colors.black.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

class AppDetailTextField extends StatelessWidget {
  const AppDetailTextField({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: controller,
                      maxLines: maxLines,
                      validator: validator,
                      onChanged: onChanged,
                      textInputAction: textInputAction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        hintText: hintText,
                        hintStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: AppDetailTile._dividerIndent,
            color: Colors.black.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

class AppDetailSwitchTile extends StatelessWidget {
  const AppDetailSwitchTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: AppDetailTile._dividerIndent,
            color: Colors.black.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

class AppDetailActionTile extends StatelessWidget {
  const AppDetailActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Material(
          color: AppTheme.cardColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 56 : 0,
                compact ? 6 : 13,
                compact ? 14 : 0,
                compact ? 6 : 13,
              ),
              child: Row(
                mainAxisAlignment:
                    compact ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    icon,
                    size: compact ? 15 : 17,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(width: compact ? 4 : 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: AppDetailTile._dividerIndent,
            color: Colors.black.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

class AppPickerOption<T> {
  const AppPickerOption({required this.value, required this.label});

  final T value;
  final String label;
}

Future<T?> showAppOptionPicker<T>({
  required BuildContext context,
  required String title,
  required List<AppPickerOption<T>> options,
  required T current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppTheme.groupedBackgroundColor,
    builder: (BuildContext context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppGroupedSection(
              children: <Widget>[
                ...options.asMap().entries.map((MapEntry<int, AppPickerOption<T>> entry) {
                  final AppPickerOption<T> option = entry.value;
                  final bool isSelected = option.value == current;
                  final bool isLast = entry.key == options.length - 1;

                  return Column(
                    children: <Widget>[
                      Material(
                        color: AppTheme.cardColor,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(option.value),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight:
                                              isSelected ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    color: AppTheme.iosBlue,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 16,
                          color: AppTheme.separatorColor,
                        ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

class AppActionDialogOption<T> {
  const AppActionDialogOption({
    required this.value,
    required this.label,
    required this.icon,
    this.iconColor,
  });

  final T value;
  final String label;
  final IconData icon;
  final Color? iconColor;
}

Future<T?> showAppActionDialog<T>({
  required BuildContext context,
  required String title,
  required List<AppActionDialogOption<T>> options,
  required String cancelLabel,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
            ),
            AppGroupedSection(
              children: <Widget>[
                for (int index = 0; index < options.length; index++)
                  AppListTile(
                    title: options[index].label,
                    leadingIcon: options[index].icon,
                    leadingIconColor:
                        options[index].iconColor ?? AppTheme.primaryColor,
                    showDivider: index < options.length - 1,
                    onTap: () =>
                        Navigator.of(dialogContext).pop(options[index].value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AppGroupedSection(
              children: <Widget>[
                Material(
                  color: AppTheme.cardColor,
                  child: InkWell(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          cancelLabel,
                          style:
                              Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: destructive
                  ? const TextStyle(color: AppTheme.destructiveColor)
                  : null,
            ),
          ),
        ],
      );
    },
  );
  return result == true;
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingIconColor,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Material(
          color: AppTheme.cardColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (leadingIcon != null) ...<Widget>[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: (leadingIconColor ?? scheme.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        leadingIcon,
                        size: 17,
                        color: leadingIconColor ?? scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: leadingIcon != null ? 56 : 14,
            color: AppTheme.separatorColor,
          ),
      ],
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppBarTextAction extends StatelessWidget {
  const AppBarTextAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ),
          if (onAction != null)
            actionLabel != null
                ? AppBarTextAction(label: actionLabel!, onPressed: onAction!)
                : IconButton(
                    onPressed: onAction,
                    icon: Icon(actionIcon ?? Icons.add),
                    tooltip: actionLabel,
                  ),
        ],
      ),
    );
  }
}
