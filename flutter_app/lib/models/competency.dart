import 'package:flutter/material.dart';

class Domain {
  const Domain({
    required this.id,
    required this.name,
    required this.color,
    this.competencies = const [],
  });

  final String id;
  final String name;
  final Color color;
  final List<Competency> competencies;

  factory Domain.fromJson(Map<String, dynamic> json) {
    return Domain(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: Color(json['color'] as int? ?? 0xFF1A237E),
      competencies: (json['competencies'] as List<dynamic>?)
              ?.map((c) => Competency.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Competency {
  const Competency({
    required this.id,
    required this.domainId,
    required this.name,
    required this.code,
    this.stage = 'FOUNDATIONAL',
    this.descriptorLevels = const [],
  });

  final String id;
  final String domainId;
  final String name;
  final String code;
  final String stage;
  final List<DescriptorLevel> descriptorLevels;

  factory Competency.fromJson(Map<String, dynamic> json) {
    return Competency(
      id: json['id'] as String? ?? '',
      domainId: json['domainId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      stage: json['stage'] as String? ?? 'FOUNDATIONAL',
      descriptorLevels: (json['descriptorLevels'] as List<dynamic>?)
              ?.map((d) => DescriptorLevel.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DescriptorLevel {
  const DescriptorLevel({
    required this.id,
    required this.label,
    required this.numericValue,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final double numericValue;
  final int sortOrder;

  factory DescriptorLevel.fromJson(Map<String, dynamic> json) {
    return DescriptorLevel(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      numericValue: (json['numericValue'] as num?)?.toDouble() ?? 0.0,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class RubricTemplate {
  const RubricTemplate({
    required this.id,
    required this.name,
    required this.stage,
    this.dimensions = const [],
  });

  final String id;
  final String name;
  final String stage;
  final List<RubricDimension> dimensions;

  factory RubricTemplate.fromJson(Map<String, dynamic> json) {
    return RubricTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      stage: json['stage'] as String? ?? 'FOUNDATIONAL',
      dimensions: (json['dimensions'] as List<dynamic>?)
              ?.map((d) => RubricDimension.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class RubricDimension {
  const RubricDimension({
    required this.id,
    required this.name,
    this.descriptorLevels = const [],
  });

  final String id;
  final String name;
  final List<DescriptorLevel> descriptorLevels;

  factory RubricDimension.fromJson(Map<String, dynamic> json) {
    return RubricDimension(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      descriptorLevels: (json['descriptorLevels'] as List<dynamic>?)
              ?.map((d) => DescriptorLevel.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
