import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class AppSlidableActionButton extends StatelessWidget {
  const AppSlidableActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  static const double _buttonSize = 40;
  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      child: Center(
        child: Container(
          width: _buttonSize,
          height: _buttonSize,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: _iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
