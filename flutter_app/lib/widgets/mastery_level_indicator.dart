import 'package:flutter/material.dart';

/// Stage-aware mastery level display widget.
///
/// Display varies by education stage:
/// - FOUNDATIONAL: emoji icons (🌊 ⛰️ 🌤️ ⭐)
/// - PREPARATORY: text labels (Beginning, Developing, Proficient, Advanced)
/// - MIDDLE: labels + optional number
/// - SECONDARY: full numeric + descriptor text
class MasteryLevelIndicator extends StatelessWidget {
  const MasteryLevelIndicator({
    super.key,
    required this.numericValue,
    required this.stageCode,
    this.size = MasteryIndicatorSize.medium,
    this.showLabel = true,
  });

  final double numericValue;
  final String stageCode;
  final MasteryIndicatorSize size;
  final bool showLabel;

  static const _foundationalEmojis = ['🌊', '⛰️', '🌤️', '⭐'];
  static const _foundationalLabels = ['Stream', 'Mountain', 'Sky', 'Star'];
  static const _preparatoryLabels = [
    'Beginning',
    'Developing',
    'Proficient',
    'Advanced'
  ];
  static const _middleLabels = [
    'Beginning',
    'Developing',
    'Proficient',
    'Advanced'
  ];
  static const _secondaryLabels = [
    'Needs Improvement',
    'Developing',
    'Proficient',
    'Advanced'
  ];

  int get _levelIndex {
    if (numericValue <= 0) return 0;
    if (numericValue >= 1.0) return 3;
    return (numericValue * 4).floor().clamp(0, 3);
  }

  Color _levelColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (_levelIndex) {
      case 0:
        return Colors.red.shade400;
      case 1:
        return Colors.orange.shade400;
      case 2:
        return scheme.primary;
      case 3:
        return Colors.green.shade600;
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = stageCode.toUpperCase();
    switch (stage) {
      case 'FOUNDATIONAL':
        return _buildFoundational(context);
      case 'PREPARATORY':
        return _buildPreparatory(context);
      case 'MIDDLE':
        return _buildMiddle(context);
      case 'SECONDARY':
        return _buildSecondary(context);
      default:
        return _buildPreparatory(context);
    }
  }

  Widget _buildFoundational(BuildContext context) {
    final idx = _levelIndex;
    final iconSize = size == MasteryIndicatorSize.small ? 18.0 : 28.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Opacity(
              opacity: i <= idx ? 1.0 : 0.3,
              child: Text(
                _foundationalEmojis[i],
                style: TextStyle(fontSize: iconSize),
              ),
            ),
          ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            _foundationalLabels[idx],
            style: _labelStyle(context),
          ),
        ],
      ],
    );
  }

  Widget _buildPreparatory(BuildContext context) {
    final idx = _levelIndex;
    final color = _levelColor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            _preparatoryLabels[idx],
            style: _labelStyle(context)?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiddle(BuildContext context) {
    final idx = _levelIndex;
    final color = _levelColor(context);
    final pct = (numericValue * 100).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _middleLabels[idx],
                style: _labelStyle(context)?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$pct%',
                style: _labelStyle(context)?.copyWith(
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecondary(BuildContext context) {
    final idx = _levelIndex;
    final color = _levelColor(context);
    final pct = (numericValue * 100).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size == MasteryIndicatorSize.small ? 36 : 48,
          height: size == MasteryIndicatorSize.small ? 36 : 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '$pct',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: size == MasteryIndicatorSize.small ? 12 : 16,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            _secondaryLabels[idx],
            style: _labelStyle(context)?.copyWith(color: color),
          ),
        ],
      ],
    );
  }

  TextStyle? _labelStyle(BuildContext context) {
    switch (size) {
      case MasteryIndicatorSize.small:
        return Theme.of(context).textTheme.labelSmall;
      case MasteryIndicatorSize.medium:
        return Theme.of(context).textTheme.labelLarge;
      case MasteryIndicatorSize.large:
        return Theme.of(context).textTheme.titleSmall;
    }
  }
}

enum MasteryIndicatorSize { small, medium, large }

/// Compact color dot for mastery level (used in list views).
class MasteryDot extends StatelessWidget {
  const MasteryDot({super.key, required this.numericValue, this.radius = 6});

  final double? numericValue;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = _dotColor();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color _dotColor() {
    if (numericValue == null) return Colors.grey.shade300;
    final v = numericValue!;
    if (v >= 0.75) return Colors.green.shade600;
    if (v >= 0.5) return Colors.blue.shade500;
    if (v >= 0.25) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
}
