import 'package:flutter/material.dart';
import 'package:posture_app/services/posture_alert_service.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';

import '../routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _physiotherapistLogin = false;
  bool _loggingIn = false;
  String? _loginError;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailCtrl.text.trim().toLowerCase();
    final pass = passCtrl.text;
    if (_loggingIn) return;
    setState(() {
      _loggingIn = true;
      _loginError = null;
    });
    try {
      final profile = await Backend.signIn(email: email, password: pass);
      if (!mounted) return;
      if (profile == null) {
        throw Exception('Profil bulunamadi.');
      }
      final role = profile['role']?.toString() ?? 'user';
      if (_physiotherapistLogin && role != 'physiotherapist') {
        await PostureAlertService.I.suspend();
        await ls.LocalStorage.logout();
        await Backend.signOut();
        throw Exception('Bu hesap fizyoterapist hesabi degil.');
      }
      if (!_physiotherapistLogin && role != 'user') {
        await PostureAlertService.I.suspend();
        await ls.LocalStorage.logout();
        await Backend.signOut();
        throw Exception('Bu hesap kullanici hesabi degil.');
      }

      await ls.LocalStorage.setLoggedIn(true);
      await ls.LocalStorage.setCurrentAccount(type: role, email: email);
      if (role == 'physiotherapist') {
        await PostureAlertService.I.suspend();
      }
      if (!mounted) return;
      if (role == 'physiotherapist') {
        Navigator.pushReplacementNamed(context, Routes.physiotherapistPortal);
        return;
      }

      final hasDevice = await ls.LocalStorage.getHasPostureDevice(
        userEmail: email,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        hasDevice == null ? Routes.deviceAvailability : Routes.shell,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loginError = _friendlyLoginError(e));
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  String _friendlyLoginError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('invalid login') ||
        raw.contains('invalid credentials') ||
        raw.contains('email not confirmed') ||
        raw.contains('400')) {
      return 'E-posta veya şifre hatalı. Bilgilerini kontrol edip tekrar dene.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.';
    }
    if (raw.contains('fizyoterapist hesabi')) {
      return 'Bu hesap fizyoterapist hesabı değil.';
    }
    if (raw.contains('kullanici hesabi')) {
      return 'Bu hesap kullanıcı hesabı değil.';
    }
    return 'Giriş yapılamadı. Bilgilerini kontrol edip tekrar dene.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: ModernBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3D6DFF), Color(0xFF0E7A80)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.self_improvement,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Hos geldin",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _physiotherapistLogin
                                ? "Danisanlarin sana ulasabilsin."
                                : "Posturunu takip et, raporlarini gor.",
                            style: TextStyle(
                              color: Colors.white.withAlpha(220),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.person_outline),
                          label: Text("Kullanici"),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.medical_services_outlined),
                          label: Text("Fizyoterapist"),
                        ),
                      ],
                      selected: {_physiotherapistLogin},
                      onSelectionChanged: (values) {
                        setState(() => _physiotherapistLogin = values.first);
                      },
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "E-posta",
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: passCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: "Şifre",
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            if (_loginError != null) ...[
                              const SizedBox(height: 12),
                              _LoginWarning(message: _loginError!),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loggingIn ? null : _login,
                                child: _loggingIn
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text("Giriş Yap"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        _physiotherapistLogin
                            ? Routes.physiotherapistRegister
                            : Routes.register,
                      ),
                      icon: Icon(
                        _physiotherapistLogin
                            ? Icons.medical_services_outlined
                            : Icons.person_add_alt_1_outlined,
                      ),
                      label: Text(
                        _physiotherapistLogin
                            ? "Uzman hesabi olustur"
                            : "Hesabin yok mu? Uye ol",
                        style: TextStyle(
                          color: _physiotherapistLogin
                              ? cs.primary
                              : cs.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginWarning extends StatelessWidget {
  final String message;

  const _LoginWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A5B).withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC1A8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFE65050),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A2D24),
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
