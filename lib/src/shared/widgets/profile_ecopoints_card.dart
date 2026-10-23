import 'package:flutter/material.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';

class ProfileEcoPointsCard extends StatelessWidget {
  const ProfileEcoPointsCard({super.key, required this.points});
  final double points;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 320),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.eco_outlined, color: Colors.white, size: 36),
          const SizedBox(height: 8),
          Text(
            '${points == points.roundToDouble() ? points.toInt() : points.toStringAsFixed(1)} EcoPoints',
            style: AppTypography.pageTitle.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
