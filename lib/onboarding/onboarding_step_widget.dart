import 'package:flutter/material.dart';

class OnboardingStepWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int currentStep;
  final int totalSteps;
  final Widget child;

  const OnboardingStepWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.currentStep,
    required this.totalSteps,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (currentStep + 1) / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(165),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            color: cs.primary,
            backgroundColor: cs.primary.withAlpha(22),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Adım ${currentStep + 1}/$totalSteps',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: cs.onSurface.withAlpha(130),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}
