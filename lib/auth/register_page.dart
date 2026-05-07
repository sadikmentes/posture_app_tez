import 'package:flutter/material.dart';
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';

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

  String _digitsOnly(String s) => s.replaceAll(RegExp(r"[^0-9]"), "");

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      return;
    }

    try {
      await Backend.signUpUser(
        fullName: _nameCtrl.text.trim(),
        age: int.parse(_ageCtrl.text.trim()),
        gender: _gender,
        email: _emailCtrl.text.trim().toLowerCase(),
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''));
      return;
    }

    if (!mounted) {
      return;
    }
    _toast("Kayit tamam. Simdi giris yap.");
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Uye Ol")),
      body: ModernBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A5B), Color(0xFF3D6DFF)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Yeni hesap olustur",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Formu doldur, posture takibine hemen basla.",
                              style: TextStyle(color: Color(0xE6FFFFFF)),
                            ),
                          ],
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
                                  Icon(Icons.badge_outlined, color: cs.primary),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Kisisel Bilgiler",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                  if (t.isEmpty) {
                                    return "Ad Soyad zorunlu";
                                  }
                                  if (t.length < 3) {
                                    return "Ad Soyad cok kisa";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _ageCtrl,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Yas",
                                  prefixIcon: Icon(Icons.cake_outlined),
                                ),
                                validator: (v) {
                                  final t = (v ?? "").trim();
                                  final age = int.tryParse(t);
                                  if (age == null) {
                                    return "Yas sayi olmali";
                                  }
                                  if (age < 5 || age > 120) {
                                    return "Yas gecersiz";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _gender,
                                items: const [
                                  DropdownMenuItem(
                                    value: "Erkek",
                                    child: Text("Erkek"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Kadin",
                                    child: Text("Kadin"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Diger",
                                    child: Text("Diger"),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _gender = v ?? "Erkek"),
                                decoration: const InputDecoration(
                                  labelText: "Cinsiyet",
                                  prefixIcon: Icon(Icons.wc_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lock_outline, color: cs.tertiary),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Hesap Bilgileri",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                  if (t.isEmpty) {
                                    return "E-posta zorunlu";
                                  }
                                  if (!_looksLikeEmail(t)) {
                                    return "E-posta gecersiz";
                                  }
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
                                  if (digits.isEmpty) {
                                    return "Telefon zorunlu";
                                  }
                                  if (digits.length < 10) {
                                    return "Telefon cok kisa";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passCtrl,
                                textInputAction: TextInputAction.next,
                                obscureText: _hidePass,
                                decoration: InputDecoration(
                                  labelText: "Sifre",
                                  prefixIcon: const Icon(Icons.key_outlined),
                                  suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => _hidePass = !_hidePass),
                                    icon: Icon(
                                      _hidePass
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  final t = (v ?? "");
                                  if (t.isEmpty) {
                                    return "Sifre zorunlu";
                                  }
                                  if (t.length < 6) {
                                    return "Sifre en az 6 karakter";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pass2Ctrl,
                                textInputAction: TextInputAction.done,
                                obscureText: _hidePass2,
                                decoration: InputDecoration(
                                  labelText: "Sifre (tekrar)",
                                  prefixIcon: const Icon(Icons.key_outlined),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _hidePass2 = !_hidePass2,
                                    ),
                                    icon: Icon(
                                      _hidePass2
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  final t = (v ?? "");
                                  if (t.isEmpty) {
                                    return "Sifre tekrar zorunlu";
                                  }
                                  if (t != _passCtrl.text) {
                                    return "Sifreler ayni degil";
                                  }
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
                          label: const Text("Uye Ol"),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Not: Hesap bilgileri Supabase veritabaninda saklanir.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(160),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
