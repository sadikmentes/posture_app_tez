import 'package:posture_app/ai/posture_ai_responder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:posture_app/onboarding/user_health_profile.dart';

class SupabaseConfig {
  static const url = 'https://nhxeayptdcfcifiouciy.supabase.co';
  static const publishableKey =
      'sb_publishable_LyDRZX7zf5xugzwv_wow0Q_C9_8MLob';
}

class Backend {
  static bool _initialized = false;

  static SupabaseClient get _db => Supabase.instance.client;

  static User? get currentUser => _initialized ? _db.auth.currentUser : null;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
    );
    _initialized = true;
  }

  static Future<Map<String, dynamic>?> currentProfile() async {
    if (!_initialized) return null;
    final user = currentUser;
    if (user == null) return null;
    return _db.from('profiles').select().eq('id', user.id).maybeSingle();
  }

  static Future<Map<String, dynamic>?> currentPhysiotherapist() async {
    if (!_initialized) return null;
    final user = currentUser;
    if (user == null) return null;
    return _db
        .from('physiotherapists')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  static Future<Map<String, dynamic>?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_initialized) throw Exception('Supabase baslatilamadi.');
    await _db.auth.signInWithPassword(email: email, password: password);
    return currentProfile();
  }

  static Future<void> signOut() {
    if (!_initialized) return Future.value();
    return _db.auth.signOut();
  }

  static Future<Map<String, dynamic>> signUpUser({
    required String fullName,
    required int age,
    required String gender,
    required String email,
    required String phone,
    required String password,
    UserHealthProfile? healthProfile,
  }) async {
    if (!_initialized) throw Exception('Supabase baslatilamadi.');
    final response = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'role': 'user', 'full_name': fullName},
    );
    final userId = response.user?.id ?? currentUser?.id;
    if (userId == null) {
      throw Exception('Kullanici olusturulamadi.');
    }

    final profile = {
      'id': userId,
      'email': email.trim().toLowerCase(),
      'full_name': fullName,
      'phone': phone,
      'role': 'user',
      'age': age,
      'gender': gender,
    };
    await _db.from('profiles').upsert(profile);
    if (healthProfile != null) {
      await upsertHealthProfile(healthProfile, userId: userId);
    }
    return profile;
  }

  static Future<void> upsertHealthProfile(
    UserHealthProfile healthProfile, {
    String? userId,
  }) async {
    if (!_initialized) throw Exception('Supabase baslatilamadi.');
    final id = userId ?? currentUser?.id;
    if (id == null) throw Exception('Kullanici oturumu bulunamadi.');

    await _db.from('user_health_profiles').upsert({
      'user_id': id,
      'full_name': healthProfile.fullName,
      'age': healthProfile.age,
      'gender': healthProfile.gender,
      'height_cm': healthProfile.heightCm,
      'weight_kg': healthProfile.weightKg,
      'occupation': healthProfile.occupation,
      'sitting_hours_per_day': healthProfile.sittingHoursPerDay,
      'computer_hours_per_day': healthProfile.computerHoursPerDay,
      'has_posture_condition_history': healthProfile.hasPostureConditionHistory,
      'posture_conditions': healthProfile.postureConditions,
      'has_surgery_history': healthProfile.hasSurgeryHistory,
      'surgery_areas': healthProfile.surgeryAreas,
      'has_regular_pain': healthProfile.hasRegularPain,
      'pain_areas': healthProfile.painAreas,
      'pain_severity': healthProfile.painSeverity,
      'weekly_exercise_frequency': healthProfile.weeklyExerciseFrequency,
      'usage_goals': healthProfile.usageGoals,
      'risk_level': healthProfile.riskLevel.name,
      'raw_profile': healthProfile.toJson(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>> signUpPhysiotherapist({
    required String fullName,
    required String clinicName,
    required String specialty,
    required String services,
    required String workingHours,
    required String bio,
    required bool onlineConsultation,
    required String email,
    required String phone,
    required String address,
    required String password,
  }) async {
    if (!_initialized) throw Exception('Supabase baslatilamadi.');
    final response = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'role': 'physiotherapist', 'full_name': fullName},
    );
    final userId = response.user?.id ?? currentUser?.id;
    if (userId == null) {
      throw Exception('Fizyoterapist olusturulamadi.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    await _db.from('profiles').upsert({
      'id': userId,
      'email': normalizedEmail,
      'full_name': fullName,
      'phone': phone,
      'role': 'physiotherapist',
    });

    final profile = {
      'id': userId,
      'email': normalizedEmail,
      'full_name': fullName,
      'clinic_name': clinicName,
      'specialty': specialty,
      'services': services,
      'working_hours': workingHours,
      'bio': bio,
      'online_consultation': onlineConsultation,
      'phone': phone,
      'address': address,
    };
    await _db.from('physiotherapists').upsert(profile);
    return profile;
  }

  static Future<List<Map<String, dynamic>>> loadPhysiotherapists() async {
    if (!_initialized) return [];
    final rows = await _db
        .from('physiotherapists')
        .select()
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<Map<String, dynamic>> createSupportRequest({
    required Map<String, dynamic> physiotherapist,
    required Map<String, dynamic> userProfile,
    required String message,
  }) async {
    if (!_initialized) throw Exception('Supabase baslatilamadi.');
    final request = await ensureSupportRequest(
      physiotherapist: physiotherapist,
      userProfile: userProfile,
    );
    final text = message.trim().isEmpty
        ? 'Postur degerlendirmesi icin iletisime gecmek istiyorum.'
        : message.trim();

    await _db
        .from('support_requests')
        .update({
          'message': text,
          'status': request['status']?.toString() == 'done'
              ? 'accepted'
              : request['status']?.toString() ?? 'new',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', request['id']);

    await sendMessage(
      threadId: request['id'].toString(),
      senderRole: 'user',
      senderName: userProfile['full_name']?.toString() ?? 'Kullanici',
      senderEmail: userProfile['email']?.toString() ?? '',
      receiverEmail: physiotherapist['email']?.toString() ?? '',
      text: text,
    );
    return {...request, 'message': text};
  }

  static Future<Map<String, dynamic>> ensureSupportRequest({
    required Map<String, dynamic> physiotherapist,
    required Map<String, dynamic> userProfile,
  }) async {
    if (!_initialized) throw Exception('Supabase başlatılamadı.');
    final existing = await _db
        .from('support_requests')
        .select()
        .eq('physiotherapist_id', physiotherapist['id'])
        .eq('user_id', userProfile['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return Map<String, dynamic>.from(existing);

    // Yeni thread — otomatik mesaj gönderilmez, chat boş açılır
    final payload = {
      'physiotherapist_id': physiotherapist['id'],
      'physiotherapist_email': physiotherapist['email'],
      'physiotherapist_name': physiotherapist['full_name'],
      'user_id': userProfile['id'],
      'user_email': userProfile['email'],
      'user_name': userProfile['full_name'],
      'user_phone': userProfile['phone'],
      'message': '',
      'status': 'new',
    };
    final request = await _db
        .from('support_requests')
        .insert(payload)
        .select()
        .single();
    return Map<String, dynamic>.from(request);
  }

  static Future<List<Map<String, dynamic>>> loadRequestsForPhysio(
    String physiotherapistId,
  ) async {
    if (!_initialized) return [];
    final rows = await _db
        .from('support_requests')
        .select()
        .eq('physiotherapist_id', physiotherapistId)
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<List<Map<String, dynamic>>> loadRequestsForUser(
    String userId,
  ) async {
    if (!_initialized) return [];
    final rows = await _db
        .from('support_requests')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> updateRequestStatus(String id, String status) {
    if (!_initialized) return Future.value();
    return _db
        .from('support_requests')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  static Future<void> sendMessage({
    required String threadId,
    required String senderRole,
    required String senderName,
    required String senderEmail,
    required String receiverEmail,
    required String text,
  }) {
    if (!_initialized) return Future.value();
    final cleanText = text.trim();
    if (cleanText.isEmpty) return Future.value();
    return _db.from('messages').insert({
      'thread_id': threadId,
      'sender_role': senderRole,
      'sender_name': senderName,
      'sender_email': senderEmail.trim().toLowerCase(),
      'receiver_email': receiverEmail.trim().toLowerCase(),
      'text': cleanText,
    });
  }

  static Future<List<Map<String, dynamic>>> loadMessagesForThread(
    String threadId,
  ) async {
    if (!_initialized) return [];
    final rows = await _db
        .from('messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> saveAiPostureAnalysis(Map<String, dynamic> analysis) {
    if (!_initialized) return Future.value();
    final user = currentUser;
    if (user == null) return Future.value();

    return _db.from('ai_posture_analyses').insert({
      'user_id': user.id,
      'score': analysis['score'],
      'title': analysis['title'],
      'summary': analysis['summary'],
      'findings': analysis['findings'],
      'exercises': analysis['exercises'],
      'metrics': analysis['metrics'],
    });
  }

  static Future<Map<String, dynamic>> ensureAiChatThread({
    String title = 'Postur Asistani',
  }) async {
    if (!_initialized) throw Exception('Supabase baslatilamadi.');
    final user = currentUser;
    if (user == null) throw Exception('Oturum bulunamadi.');

    final existing = await _db
        .from('ai_chat_threads')
        .select()
        .eq('user_id', user.id)
        .order('last_message_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return Map<String, dynamic>.from(existing);

    final thread = await _db
        .from('ai_chat_threads')
        .insert({'user_id': user.id, 'title': title})
        .select()
        .single();
    return Map<String, dynamic>.from(thread);
  }

  static Future<List<Map<String, dynamic>>> loadAiMessages(
    String threadId,
  ) async {
    if (!_initialized) return [];
    final user = currentUser;
    if (user == null) return [];
    final rows = await _db
        .from('ai_chat_messages')
        .select()
        .eq('thread_id', threadId)
        .eq('user_id', user.id)
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> clearAiMessages(String threadId) async {
    if (!_initialized) return;
    final user = currentUser;
    if (user == null) return;
    await _db
        .from('ai_chat_messages')
        .delete()
        .eq('thread_id', threadId)
        .eq('user_id', user.id);

    await _db
        .from('ai_chat_threads')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', threadId)
        .eq('user_id', user.id);
  }

  static Future<Map<String, dynamic>> sendAiChatMessage({
    required String threadId,
    required String message,
    required Map<String, dynamic> postureContext,
    required List<Map<String, dynamic>> recentMessages,
  }) async {
    if (!_initialized) throw Exception('Supabase baslatilamadi.');
    final user = currentUser;
    if (user == null) throw Exception('Oturum bulunamadi.');

    await _db.from('ai_chat_messages').insert({
      'thread_id': threadId,
      'user_id': user.id,
      'role': 'user',
      'content': message,
      'posture_context': postureContext,
    });

    await _db
        .from('ai_chat_threads')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', threadId)
        .eq('user_id', user.id);

    try {
      final response = await _db.functions.invoke(
        'ai-posture-chat',
        body: {
          'threadId': threadId,
          'userId': user.id,
          'message': message,
          'postureContext': postureContext,
          'recentMessages': recentMessages,
        },
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (error) {
      final fallback =
          'Gercek AI fonksiyonuna ulasilamadi. Bu cevap yerel guvenli moddan geliyor.\n\n'
          'Teknik neden: ${error.toString().replaceFirst('Exception: ', '')}\n\n'
          '${_localAiFallback(message, postureContext)}';
      await _db.from('ai_chat_messages').insert({
        'thread_id': threadId,
        'user_id': user.id,
        'role': 'assistant',
        'content': fallback,
        'safety_level': _safetyLevelFor(message),
        'posture_context': postureContext,
      });
      return {'content': fallback, 'fallback': true};
    }

    return {'content': ''};
  }

  static String _safetyLevelFor(String message) {
    return PostureAiResponder.safetyLevel(message);
  }

  static String _localAiFallback(
    String message,
    Map<String, dynamic> postureContext,
  ) {
    return PostureAiResponder.reply(message, postureContext);
  }
}
