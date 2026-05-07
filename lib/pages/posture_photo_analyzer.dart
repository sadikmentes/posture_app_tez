import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:posture_app/pages/posture_analysis_result.dart';

class PosturePhotoAnalyzer {
  static const insufficientLandmarksMessage =
      'Fotoğrafta analiz için yeterli vücut noktası algılanamadı.';
  static const missingRequiredPhotosMessage =
      'Ön, arka ve yan açı fotoğrafları tamamlanmadan analiz yapılamaz.';
  static const upperBodyFallbackMessage =
      'Tam vücut algılanamadı. Üst vücut postür analizi yapılacaktır.';

  final PoseDetector _poseDetector;

  PosturePhotoAnalyzer()
    : _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          model: PoseDetectionModel.accurate,
          mode: PoseDetectionMode.single,
        ),
      );

  Future<PostureAnalysisResult> analyzeFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final poses = await _poseDetector.processImage(inputImage);
    if (poses.isEmpty) {
      throw const PostureAnalysisException(insufficientLandmarksMessage);
    }

    final pose = poses.reduce((best, current) {
      return current.landmarks.length > best.landmarks.length ? current : best;
    });
    final landmarks = pose.landmarks;

    if (_hasFullBody(landmarks)) {
      return _buildResult(landmarks, type: PostureAnalysisType.fullBody);
    }
    if (_hasUpperBody(landmarks)) {
      return _buildResult(
        landmarks,
        type: PostureAnalysisType.upperBody,
        notice: upperBodyFallbackMessage,
      );
    }

    throw const PostureAnalysisException(insufficientLandmarksMessage);
  }

  Future<MultiPhotoPostureAnalysisResult> analyzeMultiple(
    Map<PosturePhotoView, String> imagePaths,
  ) async {
    final missingViews = PosturePhotoView.values
        .where((view) => imagePaths[view] == null)
        .map((view) => view.label)
        .toList(growable: false);
    if (missingViews.isNotEmpty) {
      throw PostureAnalysisException(
        '$missingRequiredPhotosMessage Eksik: ${missingViews.join(', ')}.',
      );
    }

    final viewResults = <PosturePhotoView, PostureAnalysisResult>{};
    final failedViews = <PosturePhotoView, String>{};

    for (final entry in imagePaths.entries) {
      try {
        viewResults[entry.key] = await _analyzeFileForView(
          entry.key,
          entry.value,
        );
      } on PostureAnalysisException catch (e) {
        failedViews[entry.key] = e.message;
      } catch (_) {
        failedViews[entry.key] = insufficientLandmarksMessage;
      }
    }

    if (failedViews.isNotEmpty) {
      final details = failedViews.entries
          .map((entry) => '${entry.key.label}: ${entry.value}')
          .join(' ');
      throw PostureAnalysisException(details);
    }

    return _combineResults(viewResults, failedViews);
  }

  Future<void> close() => _poseDetector.close();

  Future<PostureAnalysisResult> _analyzeFileForView(
    PosturePhotoView view,
    String imagePath,
  ) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final poses = await _poseDetector.processImage(inputImage);
    if (poses.isEmpty) {
      throw const PostureAnalysisException(insufficientLandmarksMessage);
    }

    final pose = poses.reduce((best, current) {
      return current.landmarks.length > best.landmarks.length ? current : best;
    });
    final landmarks = pose.landmarks;

    _validateExpectedView(view, landmarks);
    if (view == PosturePhotoView.side) {
      return _buildResult(
        landmarks,
        type: _hasFullBody(landmarks)
            ? PostureAnalysisType.fullBody
            : PostureAnalysisType.upperBody,
      );
    }
    return _buildFrontalResult(view, landmarks);
  }

  MultiPhotoPostureAnalysisResult _combineResults(
    Map<PosturePhotoView, PostureAnalysisResult> viewResults,
    Map<PosturePhotoView, String> failedViews,
  ) {
    final allResults = viewResults.values.toList(growable: false);
    final sideResult = viewResults[PosturePhotoView.side]!;
    final frontResult = viewResults[PosturePhotoView.front];
    final backResult = viewResults[PosturePhotoView.back];

    final cvaAngle = sideResult.cvaAngle;
    final trunkInclinationAngle = sideResult.trunkInclinationAngle;
    final shoulderDifference = _average(
      [
        frontResult?.shoulderDifference,
        backResult?.shoulderDifference,
      ].whereType<double>(),
    );

    final headStatus = _headForwardStatus(cvaAngle);
    final trunkStatus = _trunkStatus(
      trunkInclinationAngle,
      hasHips: sideResult.isFullBody,
    );
    final shoulderStatus =
        frontResult?.shoulderAlignmentStatus ??
        _dominantStatus(allResults.map((r) => r.shoulderAlignmentStatus));

    final cvaScore = _cvaScore(cvaAngle);
    final trunkScore = _tiltScore(trunkInclinationAngle);
    final shoulderScore = _statusScore(shoulderStatus);
    final postureScore =
        (cvaScore * 0.40 + trunkScore * 0.35 + shoulderScore * 0.25)
            .round()
            .clamp(0, 100);

    return MultiPhotoPostureAnalysisResult(
      postureScore: postureScore,
      cvaAngle: cvaAngle,
      trunkInclinationAngle: trunkInclinationAngle,
      shoulderDifference: shoulderDifference,
      headForwardStatus: headStatus,
      trunkStatus: trunkStatus,
      shoulderAlignmentStatus: shoulderStatus,
      generalComment: _multiPhotoComment(
        postureScore,
        usedPhotoCount: viewResults.length,
        failedPhotoCount: failedViews.length,
      ),
      suggestedExerciseCategory: _exerciseFor(
        postureScore,
        headStatus: headStatus,
        trunkStatus: trunkStatus,
        shoulderStatus: shoulderStatus,
      ),
      isMedicalDisclaimerShown: true,
      viewResults: viewResults,
      failedViews: failedViews,
      metrics: [
        PostureAnalysisMetric(
          label: 'CVA açısı',
          value: '${cvaAngle.toStringAsFixed(1)}°',
          status: headStatus,
          isGood: cvaAngle >= 50,
        ),
        PostureAnalysisMetric(
          label: 'Gövde eğimi',
          value: '${trunkInclinationAngle.toStringAsFixed(1)}°',
          status: trunkStatus,
          isGood: trunkInclinationAngle <= 8,
        ),
        PostureAnalysisMetric(
          label: 'Omuz hizası farkı',
          value: '${shoulderDifference.round()} px',
          status: shoulderStatus,
          isGood: shoulderStatus.contains('dengeli'),
        ),
      ],
    );
  }

  PostureAnalysisResult _buildFrontalResult(
    PosturePhotoView view,
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final shoulder = _midpoint(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final hip = _midpoint(
      landmarks,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );
    final shoulderWidth = _distance(
      _pointOf(landmarks[PoseLandmarkType.leftShoulder]!),
      _pointOf(landmarks[PoseLandmarkType.rightShoulder]!),
    );
    final shoulderDifference = _verticalDifference(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final shoulderDifferenceRatio =
        shoulderDifference / shoulderWidth.clamp(1, double.infinity);
    final trunkInclinationAngle = _angleFromVertical(shoulder, hip);
    final trunkStatus = _trunkStatus(trunkInclinationAngle, hasHips: true);
    final shoulderStatus = _shoulderStatus(shoulderDifferenceRatio);
    final shoulderScore = _shoulderScore(shoulderDifferenceRatio);
    final trunkScore = _tiltScore(trunkInclinationAngle);
    final postureScore = (trunkScore * 0.40 + shoulderScore * 0.60)
        .round()
        .clamp(0, 100);

    return PostureAnalysisResult(
      type: PostureAnalysisType.upperBody,
      analysisType: view.label,
      postureScore: postureScore,
      cvaAngle: 0,
      trunkInclinationAngle: trunkInclinationAngle,
      shoulderDifference: shoulderDifference,
      headForwardStatus: 'Yan görünümde hesaplanır',
      trunkStatus: trunkStatus,
      shoulderAlignmentStatus: shoulderStatus,
      generalComment: '${view.label} omuz ve gövde hizası için kullanıldı.',
      suggestedExerciseCategory: _exerciseFor(
        postureScore,
        headStatus: 'Normal',
        trunkStatus: trunkStatus,
        shoulderStatus: shoulderStatus,
      ),
      isMedicalDisclaimerShown: true,
      landmarks: landmarks,
      metrics: [
        PostureAnalysisMetric(
          label: 'Gövde eğimi',
          value: '${trunkInclinationAngle.toStringAsFixed(1)}°',
          status: trunkStatus,
          isGood: trunkInclinationAngle <= 8,
        ),
        PostureAnalysisMetric(
          label: 'Omuz hizası farkı',
          value: '${shoulderDifference.round()} px',
          status: shoulderStatus,
          isGood: shoulderDifferenceRatio <= 0.08,
        ),
      ],
    );
  }

  PostureAnalysisResult _buildResult(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    required PostureAnalysisType type,
    String? notice,
  }) {
    final ear = _midpoint(
      landmarks,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
    );
    final shoulder = _midpoint(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final shoulderWidth = _distance(
      _pointOf(landmarks[PoseLandmarkType.leftShoulder]!),
      _pointOf(landmarks[PoseLandmarkType.rightShoulder]!),
    );

    // ML Kit does not expose C7. This approximates C7 from shoulder midpoint,
    // following the requested image-based proxy for CVA awareness scoring.
    final c7 = _Point(shoulder.x, shoulder.y + shoulderWidth * 0.18);
    final cvaAngle = _angleFromHorizontal(c7, ear);
    final shoulderDifference = _verticalDifference(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final shoulderDifferenceRatio =
        shoulderDifference / shoulderWidth.clamp(1, double.infinity);

    final hasHips = _hasPair(
      landmarks,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );
    final trunkInclinationAngle = hasHips
        ? _angleFromVertical(
            shoulder,
            _midpoint(
              landmarks,
              PoseLandmarkType.leftHip,
              PoseLandmarkType.rightHip,
            ),
          )
        : _angleFromVertical(ear, shoulder);

    final cvaScore = _cvaScore(cvaAngle);
    final trunkScore = _tiltScore(trunkInclinationAngle);
    final shoulderScore = _shoulderScore(shoulderDifferenceRatio);
    final postureScore =
        (cvaScore * 0.40 + trunkScore * 0.35 + shoulderScore * 0.25)
            .round()
            .clamp(0, 100);

    final headStatus = _headForwardStatus(cvaAngle);
    final trunkStatus = _trunkStatus(trunkInclinationAngle, hasHips: hasHips);
    final shoulderStatus = _shoulderStatus(shoulderDifferenceRatio);

    return PostureAnalysisResult(
      type: type,
      analysisType: type == PostureAnalysisType.fullBody
          ? 'Tam vücut'
          : hasHips
          ? 'Üst vücut + kalça referansı'
          : 'Üst vücut tahmini',
      postureScore: postureScore,
      cvaAngle: cvaAngle,
      trunkInclinationAngle: trunkInclinationAngle,
      shoulderDifference: shoulderDifference,
      headForwardStatus: headStatus,
      trunkStatus: trunkStatus,
      shoulderAlignmentStatus: shoulderStatus,
      generalComment: _generalComment(
        postureScore,
        headStatus: headStatus,
        trunkStatus: trunkStatus,
        shoulderStatus: shoulderStatus,
      ),
      suggestedExerciseCategory: _exerciseFor(
        postureScore,
        headStatus: headStatus,
        trunkStatus: trunkStatus,
        shoulderStatus: shoulderStatus,
      ),
      isMedicalDisclaimerShown: true,
      notice: notice,
      landmarks: landmarks,
      metrics: [
        PostureAnalysisMetric(
          label: 'CVA açısı',
          value: '${cvaAngle.toStringAsFixed(1)}°',
          status: headStatus,
          isGood: cvaAngle >= 50,
        ),
        PostureAnalysisMetric(
          label: hasHips ? 'Gövde eğimi' : 'Üst gövde tahmini',
          value: '${trunkInclinationAngle.toStringAsFixed(1)}°',
          status: trunkStatus,
          isGood: trunkInclinationAngle <= 8,
        ),
        PostureAnalysisMetric(
          label: 'Omuz hizası farkı',
          value: '${shoulderDifference.round()} px',
          status: shoulderStatus,
          isGood: shoulderDifferenceRatio <= 0.08,
        ),
      ],
    );
  }

  bool _hasFullBody(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    return _hasUpperBody(landmarks) &&
        _hasPair(
          landmarks,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
        ) &&
        _hasPair(
          landmarks,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
        ) &&
        _hasPair(
          landmarks,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        );
  }

  bool _hasUpperBody(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    return _hasPair(
          landmarks,
          PoseLandmarkType.leftEar,
          PoseLandmarkType.rightEar,
        ) &&
        _hasPair(
          landmarks,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
        );
  }

  void _validateExpectedView(
    PosturePhotoView view,
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    switch (view) {
      case PosturePhotoView.front:
      case PosturePhotoView.back:
        if (!_hasTorso(landmarks)) {
          throw const PostureAnalysisException(
            'Bu açı için omuz ve kalça noktaları net görünmeli.',
          );
        }
        if (_frontalWidthRatio(landmarks) < 0.32) {
          throw PostureAnalysisException(
            '${view.label} yerine yan açıya benzeyen veya gövdesi yeterince net olmayan bir fotoğraf seçilmiş.',
          );
        }
        return;
      case PosturePhotoView.side:
        if (!_hasUpperBody(landmarks) ||
            !_hasPair(
              landmarks,
              PoseLandmarkType.leftHip,
              PoseLandmarkType.rightHip,
            )) {
          throw const PostureAnalysisException(
            'Yan açı için kulak, omuz ve kalça noktaları net görünmeli.',
          );
        }
        if (_frontalWidthRatio(landmarks) > 0.72) {
          throw const PostureAnalysisException(
            'Yan görünüm yerine ön/arka açıya benzeyen bir fotoğraf seçilmiş.',
          );
        }
        return;
    }
  }

  bool _hasTorso(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    return _hasPair(
          landmarks,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
        ) &&
        _hasPair(
          landmarks,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
        );
  }

  double _frontalWidthRatio(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = _midpoint(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final hip = _midpoint(
      landmarks,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );
    final shoulderWidth = _distance(
      _pointOf(landmarks[PoseLandmarkType.leftShoulder]!),
      _pointOf(landmarks[PoseLandmarkType.rightShoulder]!),
    );
    final torsoHeight = (shoulder.y - hip.y).abs().clamp(1.0, double.infinity);
    return shoulderWidth / torsoHeight;
  }

  bool _hasPair(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType left,
    PoseLandmarkType right,
  ) {
    return _isReliable(landmarks[left]) && _isReliable(landmarks[right]);
  }

  bool _isReliable(PoseLandmark? landmark) {
    return landmark != null && landmark.likelihood >= 0.45;
  }

  _Point _midpoint(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType a,
    PoseLandmarkType b,
  ) {
    final first = landmarks[a]!;
    final second = landmarks[b]!;
    return _Point((first.x + second.x) / 2, (first.y + second.y) / 2);
  }

  _Point _pointOf(PoseLandmark landmark) => _Point(landmark.x, landmark.y);

  double _distance(_Point a, _Point b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _verticalDifference(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType a,
    PoseLandmarkType b,
  ) {
    return (landmarks[a]!.y - landmarks[b]!.y).abs();
  }

  double _angleFromHorizontal(_Point origin, _Point target) {
    final dx = (target.x - origin.x).abs().clamp(1.0, double.infinity);
    final dy = (origin.y - target.y).abs();
    return math.atan(dy / dx) * 180 / math.pi;
  }

  double _angleFromVertical(_Point top, _Point bottom) {
    final dx = (top.x - bottom.x).abs();
    final dy = (top.y - bottom.y).abs().clamp(1.0, double.infinity);
    return math.atan(dx / dy) * 180 / math.pi;
  }

  int _cvaScore(double cvaAngle) {
    if (cvaAngle >= 55) return 100;
    if (cvaAngle <= 38) return 40;
    return (40 + ((cvaAngle - 38) / 17) * 60).round().clamp(0, 100);
  }

  int _tiltScore(double angle) {
    if (angle <= 5) return 100;
    if (angle >= 20) return 35;
    return (100 - ((angle - 5) / 15) * 65).round().clamp(0, 100);
  }

  int _shoulderScore(double differenceRatio) {
    if (differenceRatio <= 0.05) return 100;
    if (differenceRatio >= 0.18) return 35;
    return (100 - ((differenceRatio - 0.05) / 0.13) * 65).round().clamp(0, 100);
  }

  double _average(Iterable<double> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  String _dominantStatus(Iterable<String> statuses) {
    final list = statuses.toList(growable: false);
    if (list.any((status) => status.contains('Belirgin'))) {
      return list.firstWhere((status) => status.contains('Belirgin'));
    }
    if (list.any((status) => status.contains('Hafif'))) {
      return list.firstWhere((status) => status.contains('Hafif'));
    }
    return list.isEmpty ? 'Omuz hizası değerlendirilemedi' : list.first;
  }

  int _statusScore(String status) {
    if (status.contains('dengeli') || status.contains('Normal')) return 100;
    if (status.contains('Hafif') || status.contains('Orta')) return 70;
    if (status.contains('değerlendirilemedi')) return 55;
    return 40;
  }

  String _headForwardStatus(double cvaAngle) {
    if (cvaAngle >= 50) return 'Normal aralık';
    if (cvaAngle >= 45) return 'Hafif öne baş eğilimi';
    return 'Öne baş postürü riski';
  }

  String _trunkStatus(double angle, {required bool hasHips}) {
    final label = hasHips ? 'gövde eğimi' : 'üst gövde eğimi';
    if (angle <= 8) return 'Düşük $label';
    if (angle <= 15) return 'Orta $label';
    return 'Belirgin $label';
  }

  String _shoulderStatus(double differenceRatio) {
    if (differenceRatio <= 0.08) return 'Omuz hizası dengeli';
    if (differenceRatio <= 0.15) return 'Hafif omuz hizasızlığı';
    return 'Belirgin omuz hizasızlığı';
  }

  String _generalComment(
    int score, {
    required String headStatus,
    required String trunkStatus,
    required String shoulderStatus,
  }) {
    if (score >= 85) {
      return 'Görüntü tabanlı ölçümlere göre genel postür hizası iyi görünüyor.';
    }
    if (score >= 70) {
      return '$headStatus, $trunkStatus ve $shoulderStatus bulguları izlenmeli.';
    }
    return 'CVA, gövde eğimi ve omuz hizası birlikte belirgin postür farkındalığı ihtiyacı gösteriyor.';
  }

  String _multiPhotoComment(
    int score, {
    required int usedPhotoCount,
    required int failedPhotoCount,
  }) {
    final coverage = usedPhotoCount >= 3
        ? 'Ön, arka ve yan görünüm birlikte değerlendirildi.'
        : usedPhotoCount == 2
        ? 'İki fotoğraf üzerinden dengeli bir yaklaşık değerlendirme yapıldı.'
        : 'Tek fotoğraf bulunduğu için hızlı analiz yapıldı.';
    final warning = failedPhotoCount > 0
        ? ' Bazı fotoğraflarda yeterli landmark algılanamadı.'
        : '';

    if (score >= 85) {
      return '$coverage Genel postür ölçümleri iyi aralıkta görünüyor.$warning';
    }
    if (score >= 70) {
      return '$coverage Bazı ölçümlerde izlenmesi gereken hafif sapmalar var.$warning';
    }
    return '$coverage CVA, gövde eğimi veya omuz hizasında belirgin sapma sinyali var.$warning';
  }

  String _exerciseFor(
    int score, {
    required String headStatus,
    required String trunkStatus,
    required String shoulderStatus,
  }) {
    if (headStatus.contains('baş')) {
      return 'Boyun derin fleksörleri ve çene çekme';
    }
    if (trunkStatus.contains('Belirgin')) {
      return 'Torakal ekstansiyon ve core stabilizasyon';
    }
    if (shoulderStatus.contains('hizasızlığı')) {
      return 'Skapula stabilizasyonu ve omuz mobilitesi';
    }
    return score >= 85 ? 'Koruyucu mobilite' : 'Üst sırt ve postür aktivasyonu';
  }
}

class PostureAnalysisException implements Exception {
  final String message;

  const PostureAnalysisException(this.message);

  @override
  String toString() => message;
}

class _Point {
  final double x;
  final double y;

  const _Point(this.x, this.y);
}
