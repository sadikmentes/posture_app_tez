class PostureAiResponder {
  const PostureAiResponder._();

  static String safetyLevel(String message) {
    final text = _normalize(message);
    final urgentTokens = [
      'gogus',
      'nefes',
      'uyusma',
      'felc',
      'travma',
      'dusme',
      'guc kaybi',
      'idrar',
      'gaita',
      'dayanilmaz',
      'bayilma',
    ];
    if (urgentTokens.any(text.contains)) return 'urgent';
    if (text.contains('agri') || text.contains('sizi')) return 'caution';
    return 'general';
  }

  static String reply(String message, Map<String, dynamic> context) {
    final text = _normalize(message);
    final compact = text.trim();
    final summary = _summary(context);

    if (safetyLevel(message) == 'urgent') {
      return 'Bu belirti acil degerlendirme gerektirebilir. Gogus agrisi, nefes darligi, uyusma, guc kaybi, travma sonrasi agri veya dayanilmaz agri varsa beklemeden tibbi destek al.\n\nBen tani koyamam; bu durumda hekim ya da fizyoterapist degerlendirmesi gerekir.';
    }

    if (_isGreeting(compact)) {
      return 'Merhaba. Ben Postur Asistani. Durus verini yorumlama, masa basi mola rutini ve guvenli egzersiz secimi konusunda yardimci olurum.\n\nIstersen "Bugunku posturum nasil?" ya da "5 dakikalik rutin hazirla" diye baslayabiliriz.';
    }

    if (_containsAny(text, ['ne yapabilirsin', 'kimsin', 'sen nesin'])) {
      return 'Ben uygulamanin postur odakli asistaniyim. Son postur verilerini yorumlar, masa basi icin kisa rutin hazirlar, boyun/omuz/sirt/bel icin genel ve guvenli oneriler veririm.\n\nTani koymam, ilac onermem ve fizyoterapistin yerine gecmem.';
    }

    if (_containsAny(text, ['tesekkur', 'sag ol', 'eyvallah'])) {
      return 'Rica ederim. Istersen raporunu yorumlayabilir, kisa bir rutin hazirlayabilir veya agrinin nerede oldugunu yazarsan daha guvenli yonlendirebilirim.';
    }

    if (_containsAny(text, [
      'rapor',
      'yorum',
      'durusum nasil',
      'posturum nasil',
    ])) {
      return '$summary\n\nBenim yorumum: Tek bir skordan cok kotu postur suresinin ne kadar biriktigi onemli. Kotu postur dakikasi artiyorsa ilk hedef daha agir egzersiz degil, oturma suresini bolmek olmali.\n\nBugunku hedef: Her 40 dakikada 2 dakika kalk, ekrani goz hizasina yaklastir ve omuzlarini kulaklarindan uzak tut.';
    }

    if (_containsAny(text, ['rutin', 'program', 'egzersiz', 'hareket'])) {
      return '$summary\n\n5 dakikalik masa basi rutini:\n\n1. Cene geriye cekme - 45 sn\nBasini one itmeden ceneni nazikce geriye al.\n\n2. Kurek kemigi sikistirma - 45 sn\nOmuzlarini yukari kaldirmadan kurek kemiklerini birbirine yaklastir.\n\n3. Gogus acma - 60 sn\nKollarini hafifce geriye al, nefes verirken gevse.\n\n4. Omuz dairesi - 60 sn\nKucuk ve kontrollu daireler ciz.\n\n5. Ayaga kalkip yurume - 90 sn\nBelini zorlamadan kisa bir yuruyus yap.\n\nAgri artarsa hareketi birak.';
    }

    if (_containsAny(text, ['boyun', 'ense'])) {
      return '$summary\n\nBoyun icin guvenli yaklasim: Basini ani sekilde cevirmek yerine kucuk aralikta hareket et. Ekran goz hizasinda olsun, telefon kullanirken basini uzun sure one dusurme.\n\nHafif hareket: 5 tekrar cene geriye cekme. Her tekrarda 2-3 saniye tut. Agri kola yayiliyorsa, uyusma veya guc kaybi varsa uzmana danis.';
    }

    if (_containsAny(text, ['omuz', 'sirt', 'kurek'])) {
      return '$summary\n\nOmuz ve ust sirt icin hedef omuzlari zorla geriye cekmek degil, gogus kafesini acip kurek kemiklerini kontrollu calistirmak.\n\nKisa oneri: 6 tekrar kurek kemigi sikistirma yap. Omuzlarini kulaklarina kaldirmadan, nefesini tutmadan uygula.';
    }

    if (_containsAny(text, ['bel', 'kalca'])) {
      return '$summary\n\nBel icin guvenli yaklasim: Uzun sure ayni pozisyonda kalma. Sandalyede belini tamamen cokturmek yerine pelvisini notr tutmaya calis.\n\nKisa oneri: Ayaga kalk, 1-2 dakika yuru ve belini zorlamadan hafifce gevse. Bacaga yayilan agri, uyusma veya guc kaybi varsa uzmana danis.';
    }

    if (_containsAny(text, ['agri', 'sizi'])) {
      return '$summary\n\nAgri konusunda dikkatli ilerleyelim. Agri hafif bir gerginlik gibiyse hareketleri kucuk ve agrisiz aralikta yap. Agri artarsa dur.\n\nSiddetli, yayilan, uyusma/guc kaybiyla gelen veya travma sonrasi baslayan agri varsa uygulama onerisiyle yetinme; bir uzmana gorun.';
    }

    if (_containsAny(text, ['cihaz', 'sensor', 'bluetooth', 'veri yok'])) {
      return 'Cihaz verisi gelmiyorsa sirasiyla sunlari kontrol et:\n\n1. Bluetooth ve konum izinleri acik mi?\n2. Cihaz uygulamada bagli gorunuyor mu?\n3. Kalibrasyon yaptin mi?\n4. Son 5-10 saniyede canli aci verisi geliyor mu?\n\nVeri geldikten sonra postur skorunu daha anlamli yorumlayabilirim.';
    }

    return '$summary\n\nSana daha iyi yardimci olmam icin sorunu biraz daha net yaz: boyun mu, omuz/sirt mi, bel mi; yoksa raporunu mu yorumlamami istiyorsun?\n\nOrnek: "Boynum masa basinda agriyor" veya "Bugunku posturum nasil?"';
  }

  static String _summary(Map<String, dynamic> context) {
    final tracking = context['trackingMinutes'];
    final avg = context['avgScore'] ?? 0;
    final bad = context['badPostureMinutes'] ?? 0;
    final worst = context['worstScore'] ?? 0;
    final best = context['bestScore'] ?? 0;

    if (tracking is num && tracking > 0) {
      return 'Son 7 gun ozetin: Ortalama skor $avg/100, en dusuk $worst, en iyi $best. Kotu postur suren yaklasik $bad dakika.';
    }
    return 'Henuz yeterli sensor verin yok. Yine de genel postur ve masa basi aliskanliklari icin guvenli oneriler verebilirim.';
  }

  static bool _isGreeting(String text) {
    return [
      'merhaba',
      'selam',
      'slm',
      'hello',
      'hi',
      'iyi gunler',
      'iyi aksamlar',
    ].contains(text);
  }

  static bool _containsAny(String text, List<String> tokens) {
    return tokens.any(text.contains);
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }
}
