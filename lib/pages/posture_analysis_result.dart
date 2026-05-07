import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum PostureAnalysisType { fullBody, upperBody }

enum PosturePhotoView { front, back, side }

extension PosturePhotoViewLabel on PosturePhotoView {
  String get label {
    switch (this) {
      case PosturePhotoView.front:
        return 'Ön görünüm';
      case PosturePhotoView.back:
        return 'Arka görünüm';
      case PosturePhotoView.side:
        return 'Yan görünüm';
    }
  }
}

class PostureAnalysisMetric {
  final String label;
  final String value;
  final String status;
  final bool isGood;

  const PostureAnalysisMetric({
    required this.label,
    required this.value,
    required this.status,
    required this.isGood,
  });
}

class PostureAnalysisResult {
  final PostureAnalysisType type;
  final String analysisType;
  final int postureScore;
  final double cvaAngle;
  final double trunkInclinationAngle;
  final double shoulderDifference;
  final String headForwardStatus;
  final String trunkStatus;
  final String shoulderAlignmentStatus;
  final String generalComment;
  final String suggestedExerciseCategory;
  final bool isMedicalDisclaimerShown;
  final String? notice;
  final List<PostureAnalysisMetric> metrics;
  final Map<PoseLandmarkType, PoseLandmark> landmarks;

  const PostureAnalysisResult({
    required this.type,
    required this.analysisType,
    required this.postureScore,
    required this.cvaAngle,
    required this.trunkInclinationAngle,
    required this.shoulderDifference,
    required this.headForwardStatus,
    required this.trunkStatus,
    required this.shoulderAlignmentStatus,
    required this.generalComment,
    required this.suggestedExerciseCategory,
    required this.isMedicalDisclaimerShown,
    required this.metrics,
    required this.landmarks,
    this.notice,
  });

  bool get isFullBody => type == PostureAnalysisType.fullBody;

  String get title => isFullBody ? 'Tam vücut analizi' : 'Üst vücut analizi';

  // Backward-compatible aliases for older UI/test code paths.
  int get score => postureScore;
  String get comment => generalComment;
  String get exerciseCategory => suggestedExerciseCategory;
}

class MultiPhotoPostureAnalysisResult {
  final int postureScore;
  final double cvaAngle;
  final double trunkInclinationAngle;
  final double shoulderDifference;
  final String headForwardStatus;
  final String trunkStatus;
  final String shoulderAlignmentStatus;
  final String generalComment;
  final String suggestedExerciseCategory;
  final bool isMedicalDisclaimerShown;
  final List<PostureAnalysisMetric> metrics;
  final Map<PosturePhotoView, PostureAnalysisResult> viewResults;
  final Map<PosturePhotoView, String> failedViews;

  const MultiPhotoPostureAnalysisResult({
    required this.postureScore,
    required this.cvaAngle,
    required this.trunkInclinationAngle,
    required this.shoulderDifference,
    required this.headForwardStatus,
    required this.trunkStatus,
    required this.shoulderAlignmentStatus,
    required this.generalComment,
    required this.suggestedExerciseCategory,
    required this.isMedicalDisclaimerShown,
    required this.metrics,
    required this.viewResults,
    required this.failedViews,
  });

  bool get isMultiPhoto => viewResults.length > 1;

  String get analysisType =>
      isMultiPhoto ? 'Çoklu fotoğraf analizi' : 'Hızlı analiz';
}
