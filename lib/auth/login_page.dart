import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailCtrl.text.trim().toLowerCase();
    final pass = passCtrl.text;
    try {
      final profile = await Backend.signIn(email: email, password: pass);
      if (!mounted) return;
      if (profile == null) {
        throw Exception('Profil bulunamadi.');
      }
      final role = profile['role']?.toString() ?? 'user';
      if (_physiotherapistLogin && role != 'physiotherapist') {
        await Backend.signOut();
        throw Exception('Bu hesap fizyoterapist hesabi degil.');
      }
      if (!_physiotherapistLogin && role != 'user') {
        await Backend.signOut();
        throw Exception('Bu hesap kullanici hesabi degil.');
      }

      await ls.LocalStorage.setLoggedIn(true);
      await ls.LocalStorage.setCurrentAccount(type: role, email: email);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        role == 'physiotherapist' ? Routes.physiotherapistPortal : Routes.shell,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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
                                labelText: "Sifre",
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _login,
                                child: const Text("Giris Yap"),
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
