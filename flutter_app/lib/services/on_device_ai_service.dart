import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Manages on-device AI model lifecycle and template-based observation suggestions.
///
/// Currently uses a template-based approach for generating observation note
/// suggestions. The TFLite model integration is prepared for future use.
class OnDeviceAiService {
  OnDeviceAiService();

  Map<String, dynamic>? _templates;
  bool _modelsLoaded = false;

  bool get isModelLoaded => _modelsLoaded;

  /// Initialize models and load template data from local assets.
  Future<void> initializeModels() async {
    if (_modelsLoaded) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/observation_templates.json',
      );
      _templates = jsonDecode(jsonString) as Map<String, dynamic>;
      _modelsLoaded = true;
    } catch (e) {
      _modelsLoaded = false;
      rethrow;
    }
  }

  /// Generate a draft observation note using template matching.
  ///
  /// Maps the [competencyName] subdomain + [descriptorLevel] to pre-written
  /// templates. Returns a suggestion the teacher can edit before saving.
  Future<ObservationSuggestion> suggestObservationNote({
    required String competencyName,
    required String descriptorLevel,
    String? studentContext,
  }) async {
    if (!_modelsLoaded || _templates == null) {
      await initializeModels();
    }

    final domainCode = _inferDomainCode(competencyName);
    final levelCode = _normalizeLevel(descriptorLevel);

    final domains = _templates!['domains'] as Map<String, dynamic>? ?? {};
    final domain = domains[domainCode] as Map<String, dynamic>?;

    String template;
    List<String> keyIndicators;

    if (domain != null) {
      final levels =
          domain['descriptor_levels'] as Map<String, dynamic>? ?? {};
      final level = levels[levelCode] as Map<String, dynamic>?;

      if (level != null) {
        template = level['template'] as String? ?? _defaultTemplate(levelCode);
        keyIndicators = (level['key_indicators'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [];
      } else {
        template = _defaultTemplate(levelCode);
        keyIndicators = [];
      }
    } else {
      template = _defaultTemplate(levelCode);
      keyIndicators = [];
    }

    final studentName = studentContext ?? '{student_name}';
    final filledTemplate = template.replaceAll('{student_name}', studentName);

    return ObservationSuggestion(
      suggestedNote: filledTemplate,
      keyIndicators: keyIndicators,
      domainCode: domainCode,
      descriptorLevel: levelCode,
      isAiGenerated: true,
    );
  }

  /// Placeholder for future TFLite image classification of evidence photos.
  ///
  /// When a real model is loaded, this will classify evidence photos into
  /// categories (e.g. artwork, written work, physical activity).
  Future<EvidenceClassification> classifyEvidencePhoto(
    Uint8List imageBytes,
  ) async {
    return const EvidenceClassification(
      isValid: false,
      category: 'UNCLASSIFIED',
      confidence: 0.0,
    );
  }

  /// Infer domain code from competency name or subdomain text.
  String _inferDomainCode(String competencyName) {
    final lower = competencyName.toLowerCase();

    if (lower.contains('cognit') ||
        lower.contains('logic') ||
        lower.contains('math') ||
        lower.contains('reason') ||
        lower.contains('problem') ||
        lower.contains('science') ||
        lower.contains('literacy') ||
        lower.contains('reading') ||
        lower.contains('numeracy')) {
      return 'COG';
    }
    if (lower.contains('aesthetic') ||
        lower.contains('art') ||
        lower.contains('music') ||
        lower.contains('creative') ||
        lower.contains('cultur') ||
        lower.contains('craft') ||
        lower.contains('drama') ||
        lower.contains('dance')) {
      return 'AES';
    }
    if (lower.contains('social') ||
        lower.contains('emotion') ||
        lower.contains('empath') ||
        lower.contains('collaborat') ||
        lower.contains('communicat') ||
        lower.contains('relation') ||
        lower.contains('teamwork')) {
      return 'SOC';
    }
    if (lower.contains('physic') ||
        lower.contains('motor') ||
        lower.contains('health') ||
        lower.contains('sport') ||
        lower.contains('yoga') ||
        lower.contains('fitness') ||
        lower.contains('hygiene')) {
      return 'PHY';
    }

    return 'COG';
  }

  /// Normalize descriptor level to one of the four standard codes.
  String _normalizeLevel(String level) {
    final upper = level.toUpperCase().trim();
    if (upper.contains('BEGIN') || upper.contains('EMERG')) return 'BEGINNING';
    if (upper.contains('DEVELOP') || upper.contains('PROGRESS')) {
      return 'DEVELOPING';
    }
    if (upper.contains('PROFIC') || upper.contains('COMPET')) {
      return 'PROFICIENT';
    }
    if (upper.contains('ADVANC') || upper.contains('EXCEL')) return 'ADVANCED';
    return 'DEVELOPING';
  }

  String _defaultTemplate(String level) {
    switch (level) {
      case 'BEGINNING':
        return '{student_name} is beginning to demonstrate foundational understanding in this area. '
            'The student shows initial awareness and participates with teacher support.';
      case 'DEVELOPING':
        return '{student_name} is developing skills in this area and shows growing independence. '
            'The student applies learned strategies with some guidance.';
      case 'PROFICIENT':
        return '{student_name} demonstrates proficient understanding and consistently applies skills '
            'independently across contexts.';
      case 'ADVANCED':
        return '{student_name} exhibits advanced mastery, demonstrating creative application '
            'and the ability to mentor peers in this area.';
      default:
        return '{student_name} is making progress in this competency area.';
    }
  }

  /// Release model resources.
  void dispose() {
    _templates = null;
    _modelsLoaded = false;
  }
}

/// Result of an observation note suggestion.
class ObservationSuggestion {
  const ObservationSuggestion({
    required this.suggestedNote,
    required this.keyIndicators,
    required this.domainCode,
    required this.descriptorLevel,
    required this.isAiGenerated,
  });

  final String suggestedNote;
  final List<String> keyIndicators;
  final String domainCode;
  final String descriptorLevel;
  final bool isAiGenerated;
}

/// Result of evidence photo classification.
class EvidenceClassification {
  const EvidenceClassification({
    required this.isValid,
    required this.category,
    required this.confidence,
  });

  final bool isValid;
  final String category;
  final double confidence;
}
