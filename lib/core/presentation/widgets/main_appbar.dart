import 'package:flutter/material.dart';

class MainAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData iconData;
  final List<Widget>? actions;

  const MainAppbar({
    super.key,
    required this.title,
    required this.iconData,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Icon(iconData),
      title: Text(title),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
