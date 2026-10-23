import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'content_aligned_back_button.dart';
import 'package:flutter/material.dart';

class EvidenceBlockHeader extends StatelessWidget {
  const EvidenceBlockHeader({
    super.key,
    required this.title,
    required this.onBack,
  });
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(height: 1, color: Color(0xFFDADADA)),
          ),
          Positioned(
            left: 60,
            right: 60,
            top: 14,
            height: 44,
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.pageTitle,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 14,
            width: 44,
            height: 44,
            child: ContentAlignedBackButton(onPressed: onBack, size: 28),
          ),
        ],
      ),
    );
  }
}
