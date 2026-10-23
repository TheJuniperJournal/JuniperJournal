import 'package:flutter/material.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;

  const UserAvatar({super.key, this.avatarUrl, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.avatarBackground,
      backgroundImage: hasImage ? NetworkImage(avatarUrl!) : null,
      child: hasImage
          ? null
          : Icon(Icons.person, size: radius * 0.9, color: AppColors.avatarIcon),
    );
  }
}
