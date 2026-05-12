import 'package:flutter/material.dart';
import 'package:posture_app/onboarding/onboarding_step_widget.dart';
import 'package:posture_app/onboarding/user_health_profile.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';

import '../routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  int _step = 0;
  String _gender = 'Kadın';
  double _sittingHours = 6;
  double _computerHours = 4;
  bool? _hasPostureHistory;
  final Set<String> _postureConditions = {};
  bool? _hasSurgery;
  final Set<String> _surgeryAreas = {};
  bool? _hasPain;
  final Set<String> _painAreas = {};
  double _painSeverity = 4;
  String? _exerciseFrequency;
  final Set<String> _usageGoals = {};
  bool _saving = false;
  bool _hidePass = true;
  bool _hidePass2 = true;
  bool _termsConsent = false;
  bool _kvkkConsent = false;
  bool _healthDataConsent = false;
  bool _medicalDisclaimerConsent = false;

  static const _totalSteps = 8;
  static const _postureOptions = [
    'Skolyoz',
    'Kifoz',
    'Boyun fıtığı',
    'Bel fıtığı',
    'Omuz problemi',
    'Duruş bozukluğu tanısı',
    'Diğer',
  ];
  static const _surgeryOptions = [
    'Boyun',
    'Omuz',
    'Sırt',
    'Bel',
    'Kalça',
    'Diğer',
  ];
  static const _painOptions = ['Boyun', 'Omuz', 'Sırt', 'Bel'];
  static const _exerciseOptions = ['Hiç', '1-2 gün', '3-4 gün', '5+ gün'];
  static const _goalOptions = [
    'Duruş düzeltme',
    'Ağrı azaltma',
    'Farkındalık',
    'Egzersiz takibi',
    'Fizyoterapist desteği',
    'Genel sağlık',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _occupationCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _next() async {
    final message = _validationMessage();
    if (message != null) {
      _toast(message);
      return;
    }
    if (_step == _totalSteps - 1 && !_hasRequiredConsents) {
      _toast('Devam etmek icin zorunlu onaylari tamamla.');
      return;
    }
    if (_step == _totalSteps - 1) {
      await _finish();
      return;
    }
    setState(() => _step += 1);
  }

  bool get _hasRequiredConsents =>
      _termsConsent &&
      _kvkkConsent &&
      _healthDataConsent &&
      _medicalDisclaimerConsent;

  Future<void> _back() async {
    if (_step == 0 || _saving) return;
    setState(() => _step -= 1);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final profile = _buildProfile();
    final email = _emailCtrl.text.trim().toLowerCase();
    try {
      await Backend.signUpUser(
        fullName: profile.fullName,
        age: profile.age,
        gender: profile.gender,
        email: email,
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
        healthProfile: profile,
      );
      await ls.LocalStorage.saveHealthProfile(profile, userEmail: email);
      await ls.LocalStorage.saveUser({
        'name': profile.fullName,
        'full_name': profile.fullName,
        'email': email,
        'age': profile.age,
        'gender': profile.gender,
        'health_profile': profile.toJson(),
      });
      await ls.LocalStorage.setLoggedIn(true);
      await ls.LocalStorage.setCurrentAccount(type: 'user', email: email);
      await _saveRequiredConsents(profile);
      try {
        await Backend.signIn(email: email, password: _passCtrl.text);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _showRiskDialog(profile);
  }

  Future<void> _saveRequiredConsents(UserHealthProfile profile) async {
    final metadata = {
      'source': 'user_onboarding',
      'riskLevel': profile.riskLevel.name,
    };
    final consents = {
      'terms_of_use': _termsConsent,
      'kvkk_notice': _kvkkConsent,
      'health_data_processing': _healthDataConsent,
      'medical_disclaimer': _medicalDisclaimerConsent,
    };

    for (final entry in consents.entries) {
      await ls.LocalStorage.setConsent(entry.key, entry.value);
      await Backend.recordConsent(
        consentKey: entry.key,
        version: 'v1',
        granted: entry.value,
        metadata: metadata,
      );
    }
  }

  UserHealthProfile _buildProfile() {
    final risk = UserHealthProfile.calculateRisk(
      sittingHoursPerDay: _sittingHours,
      computerHoursPerDay: _computerHours,
      hasPostureConditionHistory: _hasPostureHistory == true,
      hasSurgeryHistory: _hasSurgery == true,
      hasRegularPain: _hasPain == true,
      painSeverity: _hasPain == true ? _painSeverity : 0,
      weeklyExerciseFrequency: _exerciseFrequency ?? 'Hiç',
    );
    return UserHealthProfile(
      fullName: _nameCtrl.text.trim(),
      age: int.parse(_ageCtrl.text.trim()),
      gender: _gender,
      heightCm: double.parse(_heightCtrl.text.trim().replaceAll(',', '.')),
      weightKg: double.parse(_weightCtrl.text.trim().replaceAll(',', '.')),
      occupation: _occupationCtrl.text.trim().isEmpty
          ? null
          : _occupationCtrl.text.trim(),
      sittingHoursPerDay: _sittingHours,
      computerHoursPerDay: _computerHours,
      hasPostureConditionHistory: _hasPostureHistory == true,
      postureConditions: _postureConditions.toList(growable: false),
      hasSurgeryHistory: _hasSurgery == true,
      surgeryAreas: _surgeryAreas.toList(growable: false),
      hasRegularPain: _hasPain == true,
      painAreas: _painAreas.toList(growable: false),
      painSeverity: _hasPain == true ? _painSeverity : 0,
      weeklyExerciseFrequency: _exerciseFrequency ?? 'Hiç',
      usageGoals: _usageGoals.toList(growable: false),
      riskLevel: risk,
      createdAt: DateTime.now(),
    );
  }

  void _showRiskDialog(UserHealthProfile profile) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Başlangıç profilin hazır'),
          content: Text(
            'Risk profili: ${profile.riskLevel.label}\n\nBu bilgi rutin ve rehber önerilerini kişiselleştirmek için kullanılacak.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.deviceAvailability,
                  (_) => false,
                );
              },
              child: const Text('Devam et'),
            ),
          ],
        );
      },
    );
  }

  String? _validationMessage() {
    switch (_step) {
      case 0:
        final age = int.tryParse(_ageCtrl.text.trim());
        final height = double.tryParse(
          _heightCtrl.text.trim().replaceAll(',', '.'),
        );
        final weight = double.tryParse(
          _weightCtrl.text.trim().replaceAll(',', '.'),
        );
        if (_nameCtrl.text.trim().length < 3) {
          return 'Ad soyad zorunlu.';
        }
        if (age == null || age < 5 || age > 120) {
          return 'Geçerli yaş gir.';
        }
        if (height == null || height < 80 || height > 230) {
          return 'Geçerli boy gir.';
        }
        if (weight == null || weight < 20 || weight > 250) {
          return 'Geçerli kilo gir.';
        }
        return null;
      case 2:
        if (_hasPostureHistory == null) {
          return 'Postür geçmişi sorusunu yanıtla.';
        }
        if (_hasPostureHistory == true && _postureConditions.isEmpty) {
          return 'Yaşanan rahatsızlık türünü seç.';
        }
        return null;
      case 3:
        if (_hasSurgery == null) return 'Operasyon geçmişi sorusunu yanıtla.';
        if (_hasSurgery == true && _surgeryAreas.isEmpty) {
          return 'Operasyon bölgesini seç.';
        }
        return null;
      case 4:
        if (_hasPain == null) return 'Ağrı sorusunu yanıtla.';
        if (_hasPain == true && _painAreas.isEmpty) return 'Ağrı bölgesi seç.';
        return null;
      case 5:
        if (_exerciseFrequency == null) return 'Egzersiz sıklığını seç.';
        return null;
      case 6:
        if (_usageGoals.isEmpty) return 'En az bir kullanım amacı seç.';
        return null;
      case 7:
        if (!_looksLikeEmail(_emailCtrl.text)) return 'Geçerli e-posta gir.';
        if (_phoneCtrl.text.trim().length < 10) return 'Telefon zorunlu.';
        if (_passCtrl.text.length < 6) return 'Şifre en az 6 karakter olmalı.';
        if (_passCtrl.text != _pass2Ctrl.text) return 'Şifreler aynı değil.';
        return null;
    }
    return null;
  }

  bool _looksLikeEmail(String value) {
    final text = value.trim();
    return text.contains('@') && text.contains('.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sağlık Profili')),
      body: ModernBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeOutCubic,
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: _buildStep(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _step == 0 || _saving ? null : _back,
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Geri'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _next,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _step == _totalSteps - 1
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                  ),
                            label: Text(
                              _step == _totalSteps - 1 ? 'Tamamla' : 'İleri',
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _stepBasic();
      case 1:
        return _stepLifestyle();
      case 2:
        return _stepPostureHistory();
      case 3:
        return _stepSurgery();
      case 4:
        return _stepPain();
      case 5:
        return _stepActivity();
      case 6:
        return _stepGoals();
      case 7:
        return _stepAccount();
    }
    return _stepBasic();
  }

  Widget _stepBasic() {
    return OnboardingStepWidget(
      title: 'Temel bilgiler',
      subtitle: 'Rutin önerilerini kişiselleştirelim.',
      icon: Icons.badge_outlined,
      currentStep: _step,
      totalSteps: _totalSteps,
      child: ListView(
        children: [
          _textField(_nameCtrl, 'Ad soyad', Icons.person_outline),
          _gap(),
          Row(
            children: [
              Expanded(
                child: _textField(
                  _ageCtrl,
                  'Yaş',
                  Icons.cake_outlined,
                  number: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Cinsiyet'),
                  items: const [
                    DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
                    DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                    DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                  ],
                  onChanged: (value) =>
                      setState(() => _gender = value ?? 'Kadın'),
                ),
              ),
            ],
          ),
          _gap(),
          Row(
            children: [
              Expanded(
                child: _textField(
                  _heightCtrl,
                  'Boy (cm)',
                  Icons.height,
                  number: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  _weightCtrl,
                  'Kilo (kg)',
                  Icons.monitor_weight_outlined,
                  number: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepLifestyle() {
    return OnboardingStepWidget(
      title: 'Günlük yaşam',
      subtitle: 'Meslek opsiyonel; süreler rutin planı için önemli.',
      icon: Icons.work_outline,
      currentStep: _step,
      totalSteps: _totalSteps,
      child: ListView(
        children: [
          _textField(_occupationCtrl, 'Meslek (opsiyonel)', Icons.work_outline),
          const SizedBox(height: 18),
          _slider('Günlük oturma süresi', _sittingHours, 0, 14, (v) {
            setState(() => _sittingHours = v);
          }),
          _slider('Günlük bilgisayar kullanımı', _computerHours, 0, 14, (v) {
            setState(() => _computerHours = v);
          }),
          const SizedBox(height: 14),
          _consentTile(
            value: _termsConsent,
            title: 'Kullanim sartlarini kabul ediyorum.',
            subtitle:
                'Uygulamanin tani, tedavi veya acil saglik hizmeti sunmadigini biliyorum.',
            onChanged: (value) => setState(() => _termsConsent = value),
          ),
          _consentTile(
            value: _kvkkConsent,
            title: 'KVKK aydinlatma metnini okudum.',
            subtitle:
                'Kisisel verilerimin hangi amaclarla islenecegi hakkinda bilgilendirildim.',
            onChanged: (value) => setState(() => _kvkkConsent = value),
          ),
          _consentTile(
            value: _healthDataConsent,
            title: 'Saglik verilerimin islenmesine acik riza veriyorum.',
            subtitle:
                'Agri, postur gecmisi, cihaz olcumleri ve egzersiz verilerimin uygulama islevleri icin islenmesini onayliyorum.',
            onChanged: (value) => setState(() => _healthDataConsent = value),
          ),
          _consentTile(
            value: _medicalDisclaimerConsent,
            title: 'Tibbi sorumluluk reddini kabul ediyorum.',
            subtitle:
                'Skor ve onerilerin bilgilendirme amacli oldugunu; ciddi belirtilerde uzmana basvurmam gerektigini biliyorum.',
            onChanged: (value) =>
                setState(() => _medicalDisclaimerConsent = value),
          ),
        ],
      ),
    );
  }

  Widget _stepPostureHistory() {
    return OnboardingStepWidget(
      title: 'Sağlık geçmişi',
      subtitle: 'Yanıtına göre detay soruları açılır.',
      icon: Icons.medical_information_outlined,
      currentStep: _step,
      totalSteps: _totalSteps,
      child: ListView(
        children: [
          _yesNo(
            'Daha önce postür veya omurga ile ilgili bir rahatsızlık yaşadınız mı?',
            _hasPostureHistory,
            (v) {
              setState(() {
                _hasPostureHistory = v;
                if (!v) _postureConditions.clear();
              });
            },
          ),
          if (_hasPostureHistory == true) ...[
            const SizedBox(height: 14),
            _chips(_postureOptions, _postureConditions),
          ],
        ],
      ),
    );
  }

  Widget _stepSurgery() {
    return OnboardingStepWidget(
      title: 'Operasyon geçmişi',
      subtitle: 'Hayır seçilirse detay istemeyiz.',
      icon: Icons.healing_outlined,
      currentStep: _step,
      totalSteps: _totalSteps,
      child: ListView(
        children: [
          _yesNo('Daha önce operasyon geçirdiniz mi?', _hasSurgery, (v) {
            setState(() {
              _hasSurgery = v;
              if (!v) _surgeryAreas.clear();
            });
          }),
          if (_hasSurgery == true) ...[
            const SizedBox(height: 14),
            _chips(_surgeryOptions, _surgeryAreas),
          ],
        ],
      ),
    );
  }

  Widget _stepPain() {
    return OnboardingStepWidget(
      title: 'Ağrı analizi',
      subtitle: 'Düzenli ağrı varsa bölge ve şiddeti alırız.',
      icon: Icons.health_and_safety_outlined,
      currentStep: _step,
      totalSteps: _totalSteps,
      child: ListView(
        children: [
          _yesNo('Düzenli ağrı yaşıyor musunuz?', _hasPain, (v) {
            setState(() {
              _hasPain = v;
              if (!v) {
                _painAreas.clear();
                _painSeverity = 0;
              } else if (_painSeverity == 0) {
                _painSeverity = 4;
              }
            });
          }),
          if (_hasPain == true) ...[
            const SizedBox(height: 14),
            _chips(_painOptions, _painAreas),
            const SizedBox(height: 18),
            _slider('Ağrı şiddeti', _painSeverity, 0, 10, (v) {
              setState(() => _painSeverity = v);
            }, suffix: '/10'),
          ],
        ],
      ),
    );
  }

  Widget _stepActivity() {
    return OnboardingStepWidget(
      title: 'Fiziksel aktivite',
      subtitle: 'Haftalık egzersiz sıklığını seç.',
      icon: Icons.directions_run_outlined,
      currentStep: _step,
      totalSteps: _totalSteps,
      child: _singleChoice(_exerciseOptions, _exerciseFrequency, (v) {
        setState(() => _exerciseFrequency = v);
      }),
    );
  }

  Widget _stepGoals() {
    return OnboardingStepWidget(
      title: 'Kullanım amacı',
      subtitle: 'Birden fazla hedef seçebilirsin.',
      icon: Icons.flag_outlined,
      currentStep: _step,
      totalSteps: _totalSteps,
      child: ListView(children: [_chips(_goalOptions, _usageGoals)]),
    );
  }

  Widget _stepAccount() {
    return OnboardingStepWidget(
      title: 'Hesap bilgileri',
      subtitle: 'Son adım; profilini güvenle oluşturalım.',
      icon: Icons.lock_outline,
      currentStep: _step,
      totalSteps: _totalSteps,
      child: ListView(
        children: [
          _textField(_emailCtrl, 'E-posta', Icons.mail_outline),
          _gap(),
          _textField(_phoneCtrl, 'Telefon', Icons.phone_outlined),
          _gap(),
          _passwordField(_passCtrl, 'Şifre', _hidePass, () {
            setState(() => _hidePass = !_hidePass);
          }),
          _gap(),
          _passwordField(_pass2Ctrl, 'Şifre tekrar', _hidePass2, () {
            setState(() => _hidePass2 = !_hidePass2);
          }),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool hidden,
    VoidCallback onToggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: hidden,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.key_outlined),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  Widget _yesNo(String question, bool? value, ValueChanged<bool> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Evet')),
            ButtonSegment(value: false, label: Text('Hayır')),
          ],
          selected: value == null ? <bool>{} : {value},
          emptySelectionAllowed: true,
          onSelectionChanged: (values) {
            if (values.isNotEmpty) onChanged(values.first);
          },
        ),
      ],
    );
  }

  Widget _chips(List<String> options, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        return FilterChip(
          selected: selected.contains(option),
          label: Text(option),
          onSelected: (isSelected) {
            setState(() {
              if (isSelected) {
                selected.add(option);
              } else {
                selected.remove(option);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _consentTile({
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, height: 1.25),
        ),
      ),
    );
  }

  Widget _singleChoice(
    List<String> options,
    String? selected,
    ValueChanged<String> onChanged,
  ) {
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = selected == option;
        return Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            onTap: () => onChanged(option),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
            title: Text(option),
          ),
        );
      },
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String suffix = ' saat',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${value.round()}$suffix',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        Slider(
          min: min,
          max: max,
          divisions: (max - min).round(),
          value: value.clamp(min, max),
          onChanged: onChanged,
        ),
      ],
    );
  }

  SizedBox _gap() => const SizedBox(height: 12);
}
