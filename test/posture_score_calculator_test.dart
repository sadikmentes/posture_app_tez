import 'package:flutter_test/flutter_test.dart';
import 'package:posture_app/posture_score_calculator.dart';

void main() {
  PostureScoreResult calculate({
    required double pitch,
    required double roll,
    double calibratedPitch = 0,
    double calibratedRoll = 0,
    double rollThreshold = PostureScoreCalculator.defaultRollThreshold,
  }) {
    return PostureScoreCalculator(
      currentPitch: pitch,
      currentRoll: roll,
      calibratedPitch: calibratedPitch,
      calibratedRoll: calibratedRoll,
      rollThreshold: rollThreshold,
    ).calculate();
  }

  test('keeps small sensor tolerance at score 100', () {
    final result = calculate(pitch: 3, roll: 4);

    expect(result.d, closeTo(3.5, 0.01));
    expect(result.score, 100);
    expect(result.postureComment, 'İhmal edilebilir sapma');
    expect(result.systemBehavior, 'Uyarı yok');
    expect(result.warningText, 'Uyarı yok');
    expect(result.pitchWarning, isFalse);
    expect(result.rollWarning, isFalse);
  });

  test('calculates piecewise score boundaries', () {
    expect(calculate(pitch: 15, roll: 0).score, 95);
    expect(calculate(pitch: 30, roll: 0).score, 80);
    expect(calculate(pitch: 50, roll: 0).score, 60);
    expect(calculate(pitch: 70, roll: 0).score, 30);
    expect(calculate(pitch: 100, roll: 0).score, 0);
    expect(calculate(pitch: 120, roll: 0).score, 0);
  });

  test('uses calibrated pitch and roll as reference angles', () {
    final result = calculate(
      pitch: 17,
      roll: -2,
      calibratedPitch: 10,
      calibratedRoll: -6,
    );

    expect(result.deltaPitch, 7);
    expect(result.deltaRoll, 4);
    expect(result.d, closeTo(7.23, 0.01));
    expect(result.score, 100);
  });

  test('does not over-penalize roll-only sensor rotation', () {
    final result = calculate(pitch: 0, roll: 50);

    expect(result.score, greaterThanOrEqualTo(85));
    expect(result.pitchWarning, isFalse);
  });

  test('uses shortest angular distance across the -180/180 boundary', () {
    final result = calculate(
      pitch: -179,
      roll: -178,
      calibratedPitch: 179,
      calibratedRoll: 179,
    );

    expect(result.deltaPitch, 2);
    expect(result.deltaRoll, 3);
    expect(result.score, 100);
  });

  test('prioritizes pitch roll and combined warning texts', () {
    expect(
      calculate(pitch: 25, roll: 0).warningText,
      'Öne/arkaya anlamlı postür bozulması',
    );
    expect(
      calculate(pitch: 0, roll: 27).warningText,
      'Yana eğilme / asimetri uyarısı',
    );
    expect(
      calculate(pitch: 25, roll: 27).warningText,
      'Çok yönlü postür bozulması',
    );
  });

  test('allows more sensitive roll threshold', () {
    final defaultResult = calculate(pitch: 0, roll: 23);
    final sensitiveResult = calculate(
      pitch: 0,
      roll: 23,
      rollThreshold: PostureScoreCalculator.sensitiveRollThreshold,
    );

    expect(defaultResult.rollWarning, isFalse);
    expect(sensitiveResult.rollWarning, isTrue);
  });

  test('stabilizes short lived score jitter', () {
    final stabilizer = PostureScoreStabilizer();
    final stable = calculate(pitch: 0, roll: 0);
    final jitter = calculate(pitch: 13, roll: 0);

    expect(stabilizer.apply(stable).score, 100);
    expect(stabilizer.apply(jitter).score, 100);
    expect(stabilizer.apply(stable).score, 100);
    expect(stabilizer.apply(jitter).score, 100);
  });

  test('accepts sustained score changes', () {
    final stabilizer = PostureScoreStabilizer();
    final stable = calculate(pitch: 0, roll: 0);
    final changed = calculate(pitch: 18, roll: 0);

    expect(stabilizer.apply(stable).score, 100);
    expect(stabilizer.apply(changed).score, 100);
    expect(stabilizer.apply(changed).score, 100);
    expect(stabilizer.apply(changed).score, 100);
    expect(stabilizer.apply(changed).score, changed.score);
  });
}
