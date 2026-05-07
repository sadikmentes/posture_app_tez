enum HealthRiskLevel { low, medium, high }

extension HealthRiskLevelLabel on HealthRiskLevel {
  String get label {
    switch (this) {
      case HealthRiskLevel.low:
        return 'Düşük risk';
      case HealthRiskLevel.medium:
        return 'Orta risk';
      case HealthRiskLevel.high:
        return 'Yüksek risk';
    }
  }
}

class UserHealthProfile {
  final String fullName;
  final int age;
  final String gender;
  final double heightCm;
  final double weightKg;
  final String? occupation;
  final double sittingHoursPerDay;
  final double computerHoursPerDay;
  final bool hasPostureConditionHistory;
  final List<String> postureConditions;
  final bool hasSurgeryHistory;
  final List<String> surgeryAreas;
  final bool hasRegularPain;
  final List<String> painAreas;
  final double painSeverity;
  final String weeklyExerciseFrequency;
  final List<String> usageGoals;
  final HealthRiskLevel riskLevel;
  final DateTime createdAt;

  const UserHealthProfile({
    required this.fullName,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.occupation,
    required this.sittingHoursPerDay,
    required this.computerHoursPerDay,
    required this.hasPostureConditionHistory,
    required this.postureConditions,
    required this.hasSurgeryHistory,
    required this.surgeryAreas,
    required this.hasRegularPain,
    required this.painAreas,
    required this.painSeverity,
    required this.weeklyExerciseFrequency,
    required this.usageGoals,
    required this.riskLevel,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'age': age,
    'gender': gender,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'occupation': occupation,
    'sittingHoursPerDay': sittingHoursPerDay,
    'computerHoursPerDay': computerHoursPerDay,
    'hasPostureConditionHistory': hasPostureConditionHistory,
    'postureConditions': postureConditions,
    'hasSurgeryHistory': hasSurgeryHistory,
    'surgeryAreas': surgeryAreas,
    'hasRegularPain': hasRegularPain,
    'painAreas': painAreas,
    'painSeverity': painSeverity,
    'weeklyExerciseFrequency': weeklyExerciseFrequency,
    'usageGoals': usageGoals,
    'riskLevel': riskLevel.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserHealthProfile.fromJson(Map<String, dynamic> json) {
    return UserHealthProfile(
      fullName: json['fullName']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      gender: json['gender']?.toString() ?? '',
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
      occupation: json['occupation']?.toString(),
      sittingHoursPerDay: (json['sittingHoursPerDay'] as num?)?.toDouble() ?? 0,
      computerHoursPerDay:
          (json['computerHoursPerDay'] as num?)?.toDouble() ?? 0,
      hasPostureConditionHistory: json['hasPostureConditionHistory'] == true,
      postureConditions: _stringList(json['postureConditions']),
      hasSurgeryHistory: json['hasSurgeryHistory'] == true,
      surgeryAreas: _stringList(json['surgeryAreas']),
      hasRegularPain: json['hasRegularPain'] == true,
      painAreas: _stringList(json['painAreas']),
      painSeverity: (json['painSeverity'] as num?)?.toDouble() ?? 0,
      weeklyExerciseFrequency:
          json['weeklyExerciseFrequency']?.toString() ?? '',
      usageGoals: _stringList(json['usageGoals']),
      riskLevel: HealthRiskLevel.values.firstWhere(
        (level) => level.name == json['riskLevel'],
        orElse: () => HealthRiskLevel.low,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static HealthRiskLevel calculateRisk({
    required double sittingHoursPerDay,
    required double computerHoursPerDay,
    required bool hasPostureConditionHistory,
    required bool hasSurgeryHistory,
    required bool hasRegularPain,
    required double painSeverity,
    required String weeklyExerciseFrequency,
  }) {
    var points = 0;
    if (sittingHoursPerDay >= 8) points += 2;
    if (sittingHoursPerDay >= 10) points += 1;
    if (computerHoursPerDay >= 6) points += 1;
    if (hasPostureConditionHistory) points += 3;
    if (hasSurgeryHistory) points += 2;
    if (hasRegularPain) points += painSeverity >= 7 ? 4 : 2;
    if (weeklyExerciseFrequency == 'Hiç') points += 2;
    if (weeklyExerciseFrequency == '1-2 gün') points += 1;

    if (points >= 7) return HealthRiskLevel.high;
    if (points >= 3) return HealthRiskLevel.medium;
    return HealthRiskLevel.low;
  }
}
