import 'package:flutter/material.dart';
import '../routes.dart';
import 'package:posture_app/storage.dart' as ls;




class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
  final email = emailCtrl.text.trim().toLowerCase();
  final pass = passCtrl.text;

  final user = await ls.LocalStorage.loadUser();
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Kayıtlı kullanıcı yok. Önce üye ol.")),
    );
    return;
  }

  final savedEmail = (user["email"] as String).trim().toLowerCase();
  final savedPass = user["password"] as String;

  if (email == savedEmail && pass == savedPass) {
    await ls.LocalStorage.setLoggedIn(true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, Routes.shell);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("E-posta veya şifre hatalı.")),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.self_improvement, size: 56, color: cs.primary),
                  const SizedBox(height: 12),
                  const Text(
                    "Hoş geldin",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Postürünü takip et, raporlarını gör.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 22),

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
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              child: const Text("Giriş Yap"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.register),
                    child: const Text("Hesabın yok mu? Üye ol"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
