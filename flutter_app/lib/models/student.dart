class Student {
  const Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    this.apaarId,
    required this.classSection,
    this.stage = 'FOUNDATIONAL',
    this.enrolmentStatus = 'ACTIVE',
    this.apaarVerified = false,
    this.lastObservationDate,
    this.overallMastery,
    this.domainMastery = const {},
  });

  final String id;
  final String name;
  final String rollNumber;
  final String? apaarId;
  final String classSection;
  final String stage;
  final String enrolmentStatus;
  final bool apaarVerified;
  final DateTime? lastObservationDate;
  final double? overallMastery;
  final Map<String, double> domainMastery;

  String get maskedApaarId {
    if (apaarId == null || apaarId!.length < 4) return apaarId ?? '';
    return '${'•' * (apaarId!.length - 4)}${apaarId!.substring(apaarId!.length - 4)}';
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rollNumber: json['rollNumber'] as String? ?? '',
      apaarId: json['apaarId'] as String?,
      classSection: json['classSection'] as String? ?? '',
      stage: json['stage'] as String? ?? 'FOUNDATIONAL',
      enrolmentStatus: json['enrolmentStatus'] as String? ?? 'ACTIVE',
      apaarVerified: json['apaarVerified'] as bool? ?? false,
      lastObservationDate: json['lastObservationDate'] != null
          ? DateTime.tryParse(json['lastObservationDate'] as String)
          : null,
      overallMastery: (json['overallMastery'] as num?)?.toDouble(),
      domainMastery: (json['domainMastery'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
    );
  }
}
