import 'dart:math' as math;

class PostureScoreResult {
  final int score;
  final double d;
  final double deltaPitch;
  final double deltaRoll;
  final String postureComment;
  final String systemBehavior;
  final String warningText;
  final bool pitchWarning;
  final bool rollWarning;

  const PostureScoreResult({
    required this.score,
    required this.d,
    required this.deltaPitch,
    required this.deltaRoll,
    required this.postureComment,
    required this.systemBehavior,
    required this.warningText,
    required this.pitchWarning,
    required this.rollWarning,
  });

  PostureScoreResult copyWith({
    int? score,
    double? d,
    double? deltaPitch,
    double? deltaRoll,
    String? postureComment,
    String? systemBehavior,
    String? warningText,
    bool? pitchWarning,
    bool? rollWarning,
  }) {
    return PostureScoreResult(
      score: score ?? this.score,
      d: d ?? this.d,
      deltaPitch: deltaPitch ?? this.deltaPitch,
      deltaRoll: deltaRoll ?? this.deltaRoll,
      postureComment: postureComment ?? this.postureComment,
      systemBehavior: systemBehavior ?? this.systemBehavior,
      warningText: warningText ?? this.warningText,
      pitchWarning: pitchWarning ?? this.pitchWarning,
      rollWarning: rollWarning ?? this.rollWarning,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'D': d,
      'deltaPitch': deltaPitch,
      'deltaRoll': deltaRoll,
      'postureComment': postureComment,
      'systemBehavior': systemBehavior,
      'warningText': warningText,
      'pitchWarning': pitchWarning,
      'rollWarning': rollWarning,
    };
  }
}

class PostureScoreStabilizer {
  final int deadband;
  final int confirmSamples;
  final int immediateJump;

  int? _stableScore;
  int? _candidateScore;
  int _candidateCount = 0;

  PostureScoreStabilizer({
    this.deadband = 4,
    this.confirmSamples = 4,
    this.immediateJump = 12,
  });

  PostureScoreResult apply(PostureScoreResult result) {
    final stable = _stableScore;
    if (stable == null) {
      _stableScore = result.score;
      return result;
    }

    final diff = result.score - stable;
    if (diff.abs() <= deadband) {
      _clearCandidate();
      return result.copyWith(score: stable);
    }

    if (diff.abs() >= immediateJump) {
      _accept(result.score);
      return result;
    }

    final candidate = _candidateScore;
    if (candidate != null && (result.score - candidate).abs() <= deadband) {
      _candidateCount += 1;
    } else {
      _candidateScore = result.score;
      _candidateCount = 1;
    }

    if (_candidateCount >= confirmSamples) {
      _accept(result.score);
      return result;
    }

    return result.copyWith(score: stable);
  }

  void reset() {
    _stableScore = null;
    _clearCandidate();
  }

  void _accept(int score) {
    _stableScore = score;
    _clearCandidate();
  }

  void _clearCandidate() {
    _candidateScore = null;
    _candidateCount = 0;
  }
}

class PostureScoreCalculator {
  static const double defaultRollThreshold = 15.0;
  static const double sensitiveRollThreshold = 10.0;
  static const double pitchWarningThreshold = 20.0;

  final double currentPitch;
  final double currentRoll;
  final double calibratedPitch;
  final double calibratedRoll;
  final double rollThreshold;

  const PostureScoreCalculator({
    required this.currentPitch,
    required this.currentRoll,
    required this.calibratedPitch,
    required this.calibratedRoll,
    this.rollThreshold = defaultRollThreshold,
  });

  PostureScoreResult calculate() {
    final deltaPitch = _angularDistance(currentPitch, calibratedPitch);
    final deltaRoll = _angularDistance(currentRoll, calibratedRoll);

    final d = math.sqrt((deltaPitch * deltaPitch) + (deltaRoll * deltaRoll));

    final score = _scoreForDeviation(d).round().clamp(0, 100);
    final pitchWarning = deltaPitch > pitchWarningThreshold;
    final rollWarning = deltaRoll > rollThreshold;
    final range = _rangeForDeviation(d);

    return PostureScoreResult(
      score: score,
      d: d,
      deltaPitch: deltaPitch,
      deltaRoll: deltaRoll,
      postureComment: range.postureComment,
      systemBehavior: range.systemBehavior,
      warningText: _warningText(
        range: range,
        pitchWarning: pitchWarning,
        rollWarning: rollWarning,
      ),
      pitchWarning: pitchWarning,
      rollWarning: rollWarning,
    );
  }

  double _scoreForDeviation(double d) {
    if (d <= 5.0) {
      return 100.0;
    }
    if (d <= 10.0) {
      return 100.0 - 5.0 * ((d - 5.0) / 5.0);
    }
    if (d <= 20.0) {
      return 95.0 - 15.0 * ((d - 10.0) / 10.0);
    }
    if (d <= 40.0) {
      return 80.0 - 20.0 * ((d - 20.0) / 20.0);
    }
    if (d <= 60.0) {
      return 60.0 - 30.0 * ((d - 40.0) / 20.0);
    }

    return math.max(0.0, 30.0 - 30.0 * ((d - 60.0) / 30.0));
  }

  _DeviationRange _rangeForDeviation(double d) {
    if (d <= 5.0) {
      return const _DeviationRange(
        postureComment: 'İhmal edilebilir sapma',
        systemBehavior: 'Uyarı yok',
        fallbackWarningText: 'Uyarı yok',
      );
    }
    if (d <= 10.0) {
      return const _DeviationRange(
        postureComment: 'Çok hafif sapma',
        systemBehavior: 'Sadece kayıt',
        fallbackWarningText: 'Çok hafif sapma',
      );
    }
    if (d <= 20.0) {
      return const _DeviationRange(
        postureComment: 'Hafif postür bozulması',
        systemBehavior: 'Süreklilik varsa pasif uyarı',
        fallbackWarningText: 'Hafif postür bozulması',
      );
    }
    if (d <= 40.0) {
      return const _DeviationRange(
        postureComment: 'Belirgin postür bozulması',
        systemBehavior: 'Düzeltme uyarısı',
        fallbackWarningText: 'Belirgin postür bozulması',
      );
    }
    if (d <= 60.0) {
      return const _DeviationRange(
        postureComment: 'Kötü postür',
        systemBehavior: 'Güçlü uyarı',
        fallbackWarningText: 'Kötü postür',
      );
    }

    return const _DeviationRange(
      postureComment: 'Ciddi postür bozulması',
      systemBehavior: 'Kritik uyarı',
      fallbackWarningText: 'Ciddi postür bozulması',
    );
  }

  String _warningText({
    required _DeviationRange range,
    required bool pitchWarning,
    required bool rollWarning,
  }) {
    if (pitchWarning && rollWarning) {
      return 'Çok yönlü postür bozulması';
    }
    if (pitchWarning) {
      return 'Öne/arkaya anlamlı postür bozulması';
    }
    if (rollWarning) {
      return 'Yana eğilme / asimetri uyarısı';
    }
    return range.fallbackWarningText;
  }

  double _angularDistance(double current, double reference) {
    var delta = (current - reference) % 360.0;
    if (delta > 180.0) delta -= 360.0;
    if (delta < -180.0) delta += 360.0;
    return delta.abs();
  }
}

class _DeviationRange {
  final String postureComment;
  final String systemBehavior;
  final String fallbackWarningText;

  const _DeviationRange({
    required this.postureComment,
    required this.systemBehavior,
    required this.fallbackWarningText,
  });
}
