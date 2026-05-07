import 'package:flutter/material.dart';
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';

class PhysiotherapistRegisterPage extends StatefulWidget {
  const PhysiotherapistRegisterPage({super.key});

  @override
  State<PhysiotherapistRegisterPage> createState() =>
      _PhysiotherapistRegisterPageState();
}

class _PhysiotherapistRegisterPageState
    extends State<PhysiotherapistRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _hidePass = true;
  bool _hidePass2 = true;
  bool _onlineConsultation = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clinicCtrl.dispose();
    _specialtyCtrl.dispose();
    _servicesCtrl.dispose();
    _hoursCtrl.dispose();
    _bioCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    final text = value.trim();
    return text.contains("@") && text.contains(".");
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r"[^0-9]"), "");

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    try {
      await Backend.signUpPhysiotherapist(
        fullName: _nameCtrl.text.trim(),
        clinicName: _clinicCtrl.text.trim(),
        specialty: _specialtyCtrl.text.trim(),
        services: _servicesCtrl.text.trim(),
        workingHours: _hoursCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        onlineConsultation: _onlineConsultation,
        email: _emailCtrl.text.trim().toLowerCase(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        password: _passCtrl.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Fizyoterapist kaydi olusturuldu.")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Fizyoterapist Kaydi")),
      body: ModernBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0E7A80), Color(0xFF3D6DFF)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Uzman profili olustur",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Kullanicilar telefon veya e-posta ile sana ulasabilsin.",
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
                            children: [
                              _field(
                                controller: _nameCtrl,
                                label: "Ad Soyad",
                                icon: Icons.person_outline,
                                validator: (v) => (v ?? "").trim().length < 3
                                    ? "Ad soyad zorunlu"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _clinicCtrl,
                                label: "Klinik / Merkez Adi",
                                icon: Icons.local_hospital_outlined,
                                validator: (v) => (v ?? "").trim().length < 2
                                    ? "Klinik adi zorunlu"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _specialtyCtrl,
                                label: "Uzmanlik",
                                hint: "Orn: Postur analizi, manuel terapi",
                                icon: Icons.badge_outlined,
                                validator: (v) => (v ?? "").trim().isEmpty
                                    ? "Uzmanlik zorunlu"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _servicesCtrl,
                                label: "Hizmetler",
                                hint: "Orn: Postur analizi, egzersiz planlama",
                                icon: Icons.checklist_outlined,
                                maxLines: 2,
                                validator: (v) => (v ?? "").trim().isEmpty
                                    ? "En az bir hizmet yaz"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _hoursCtrl,
                                label: "Calisma Saatleri",
                                hint: "Orn: Hafta ici 10:00-18:00",
                                icon: Icons.schedule_outlined,
                                validator: (v) => (v ?? "").trim().isEmpty
                                    ? "Calisma saatleri zorunlu"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _onlineConsultation,
                                onChanged: (value) =>
                                    setState(() => _onlineConsultation = value),
                                title: const Text(
                                  "Online gorusme kabul ediyorum",
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                secondary: const Icon(
                                  Icons.video_call_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _bioCtrl,
                                label: "Kisa Tanitim",
                                hint:
                                    "Deneyimini ve hangi konularda yardimci oldugunu yaz.",
                                icon: Icons.description_outlined,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _emailCtrl,
                                label: "E-posta",
                                icon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => !_looksLikeEmail(v ?? "")
                                    ? "E-posta gecersiz"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _phoneCtrl,
                                label: "Telefon",
                                hint: "05xx xxx xx xx",
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) =>
                                    _digitsOnly(v ?? "").length < 10
                                    ? "Telefon gecersiz"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _addressCtrl,
                                label: "Adres",
                                icon: Icons.location_on_outlined,
                                maxLines: 2,
                                validator: (v) => (v ?? "").trim().isEmpty
                                    ? "Adres zorunlu"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passCtrl,
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
                                validator: (v) => (v ?? "").length < 6
                                    ? "Sifre en az 6 karakter"
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pass2Ctrl,
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
                                validator: (v) => v != _passCtrl.text
                                    ? "Sifreler ayni degil"
                                    : null,
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
                          label: const Text("Uzman Kaydi Olustur"),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Not: Uzman bilgileri Supabase veritabaninda saklanir.",
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}
