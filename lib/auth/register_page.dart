import 'package:flutter/material.dart';
import 'package:posture_app/storage.dart' as ls;



class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = "Erkek";
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _hidePass = true;
  bool _hidePass2 = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _looksLikeEmail(String s) {
    final t = s.trim();
    return t.contains("@") && t.contains(".");
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _submit() async {
  final ok = _formKey.currentState?.validate() ?? false;
  if (!ok) return;

  final user = {
    "fullName": _nameCtrl.text.trim(),
    "age": int.parse(_ageCtrl.text.trim()),
    "gender": _gender,
    "email": _emailCtrl.text.trim(),
    "phone": _phoneCtrl.text.trim(),
    "password": _passCtrl.text, // geçici; Firebase’de tutmayacağız
  };

  await ls.LocalStorage.saveUser(user);


  _toast("Kayıt tamam ✅ Şimdi giriş yap.");
  if (!mounted) return;
  Navigator.pop(context);
}


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Üye Ol")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.badge_outlined, color: cs.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  "Kişisel Bilgiler",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: "Ad Soyad",
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) {
                                final t = (v ?? "").trim();
                                if (t.isEmpty) return "Ad Soyad zorunlu";
                                if (t.length < 3) return "Ad Soyad çok kısa";
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _ageCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Yaş",
                                prefixIcon: Icon(Icons.cake_outlined),
                              ),
                              validator: (v) {
                                final t = (v ?? "").trim();
                                final age = int.tryParse(t);
                                if (age == null) return "Yaş sayı olmalı";
                                if (age < 5 || age > 120) return "Yaş geçersiz";
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              value: _gender,
                              items: const [
                                DropdownMenuItem(value: "Erkek", child: Text("Erkek")),
                                DropdownMenuItem(value: "Kadın", child: Text("Kadın")),
                                DropdownMenuItem(value: "Diğer", child: Text("Diğer")),
                              ],
                              onChanged: (v) => setState(() => _gender = v ?? "Erkek"),
                              decoration: const InputDecoration(
                                labelText: "Cinsiyet",
                                prefixIcon: Icon(Icons.wc_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock_outline, color: cs.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  "Hesap Bilgileri",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _emailCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "E-posta",
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (v) {
                                final t = (v ?? "").trim();
                                if (t.isEmpty) return "E-posta zorunlu";
                                if (!_looksLikeEmail(t)) return "E-posta geçersiz";
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _phoneCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: "Telefon",
                                hintText: "05xx xxx xx xx",
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (v) {
                                final digits = _digitsOnly(v ?? "");
                                if (digits.isEmpty) return "Telefon zorunlu";
                                if (digits.length < 10) return "Telefon çok kısa";
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _passCtrl,
                              textInputAction: TextInputAction.next,
                              obscureText: _hidePass,
                              decoration: InputDecoration(
                                labelText: "Şifre",
                                prefixIcon: const Icon(Icons.key_outlined),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _hidePass = !_hidePass),
                                  icon: Icon(_hidePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                ),
                              ),
                              validator: (v) {
                                final t = (v ?? "");
                                if (t.isEmpty) return "Şifre zorunlu";
                                if (t.length < 6) return "Şifre en az 6 karakter";
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _pass2Ctrl,
                              textInputAction: TextInputAction.done,
                              obscureText: _hidePass2,
                              decoration: InputDecoration(
                                labelText: "Şifre (tekrar)",
                                prefixIcon: const Icon(Icons.key_outlined),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _hidePass2 = !_hidePass2),
                                  icon: Icon(_hidePass2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                ),
                              ),
                              validator: (v) {
                                final t = (v ?? "");
                                if (t.isEmpty) return "Şifre tekrar zorunlu";
                                if (t != _passCtrl.text) return "Şifreler aynı değil";
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("Üye Ol"),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      "Not: Şu an sadece form/validasyon. Bir sonraki adımda Firebase veritabanına kaydedeceğiz.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
