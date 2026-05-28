import 'package:flutter/material.dart';
import 'package:murmur/core/constants/app_strings.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: const Center(
        child: Text(AppStrings.comingSoon),
      ),
    );
  }
}
