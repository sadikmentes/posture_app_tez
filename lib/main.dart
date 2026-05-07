import 'package:flutter/material.dart';
import 'app.dart';
import 'services/posture_alert_service.dart';
import 'supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.initialize();
  await PostureAlertService.I.initialize();
  runApp(const PostureApp());
}
