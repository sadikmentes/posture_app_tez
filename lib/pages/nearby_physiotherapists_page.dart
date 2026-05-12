import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:posture_app/pages/chat_page.dart';
import 'package:posture_app/storage.dart' as ls;
import 'package:posture_app/supabase_backend.dart';
import 'package:posture_app/ui/modern_background.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyPhysiotherapistsPage extends StatefulWidget {
  const NearbyPhysiotherapistsPage({super.key});

  @override
  State<NearbyPhysiotherapistsPage> createState() =>
      _NearbyPhysiotherapistsPageState();
}

class _NearbyPhysiotherapistsPageState
    extends State<NearbyPhysiotherapistsPage> {
  static const String _googlePlacesApiKey =
      'AIzaSyDMM8zJxfauTv-pHSFwfvonW8et9YIWT7A';
  static const Duration _liveRequestTimeout = Duration(seconds: 8);
  static const Duration _locationTimeout = Duration(seconds: 8);
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const int _maxVisibleCenters = 12;

  static DateTime? _cacheAt;
  static Position? _cachedPosition;
  static List<_PhysiotherapistDistance> _cachedNearby = const [];
  static String? _cachedSourceLabel;

  bool _loading = true;
  bool _isRefreshing = false;
  String? _error;
  String _sourceLabel = 'Canlı veri';
  Position? _currentPosition;
  List<_PhysiotherapistDistance> _nearby = const [];
  List<Map<String, dynamic>> _registeredPhysiotherapists = const [];
  Map<String, dynamic>? _currentUser;
  DateTime? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    final hasUsableCache =
        _cachedNearby.isNotEmpty &&
        _cachedPosition != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl;
    if (hasUsableCache) {
      _currentPosition = _cachedPosition;
      _nearby = List<_PhysiotherapistDistance>.from(_cachedNearby);
      _sourceLabel = _cachedSourceLabel ?? 'Onbellekten yuklendi';
      _lastUpdatedAt = _cacheAt;
      _loading = false;
    }
    _loadRegisteredPhysiotherapists();
    _loadCurrentUser();
    _loadNearby(
      forceRefresh: !hasUsableCache,
      showBlockingLoader: !hasUsableCache,
    );
  }

  Future<void> _loadRegisteredPhysiotherapists() async {
    final profiles = await Backend.loadPhysiotherapists();
    if (!mounted) return;
    setState(() => _registeredPhysiotherapists = profiles);
  }

  Future<void> _loadCurrentUser() async {
    final user = await Backend.currentProfile();
    if (!mounted) return;
    setState(() => _currentUser = user);
  }

  Future<void> _loadNearby({
    bool forceRefresh = false,
    bool showBlockingLoader = false,
  }) async {
    final canReuseCache =
        !forceRefresh &&
        _cachedNearby.isNotEmpty &&
        _cachedPosition != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl;
    if (canReuseCache) {
      if (!mounted) return;
      setState(() {
        _currentPosition = _cachedPosition;
        _nearby = List<_PhysiotherapistDistance>.from(_cachedNearby);
        _sourceLabel = _cachedSourceLabel ?? 'Onbellekten yuklendi';
        _lastUpdatedAt = _cacheAt;
        _loading = false;
        _isRefreshing = false;
        _error = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _error = null;
      if (showBlockingLoader || _nearby.isEmpty) {
        _loading = true;
      } else {
        _isRefreshing = true;
      }
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Konum servisi kapalı. Lütfen cihaz ayarlarından konumu açın.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Konum izni verilmedi.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Konum izni kalıcı olarak reddedildi. Lütfen ayarlardan izin verin.',
        );
      }

      final position = await _resolveCurrentPosition();
      final liveResult = await _fetchLiveCenters(position);
      final centers = liveResult.centers.isEmpty
          ? _fallbackCenters
          : liveResult.centers;
      final results = _rankByDistance(position, centers);
      final sourceLabel = liveResult.centers.isEmpty
          ? 'Canlı kaynaklara ulaşılamadı, örnek liste gösteriliyor'
          : liveResult.source;
      final now = DateTime.now();

      _cacheAt = now;
      _cachedPosition = position;
      _cachedNearby = List<_PhysiotherapistDistance>.unmodifiable(results);
      _cachedSourceLabel = sourceLabel;

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _nearby = results;
        _sourceLabel = sourceLabel;
        _lastUpdatedAt = now;
        _loading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _runUserAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<Position> _resolveCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: _locationTimeout,
      );
    } catch (_) {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<_LiveFetchResult> _fetchLiveCenters(Position position) async {
    final requests = <Future<_LiveFetchResult>>[
      _fetchOverpassCenters(position).then(
        (centers) => _LiveFetchResult(
          centers: centers,
          source: 'OpenStreetMap canlı veri',
        ),
      ),
    ];

    if (_googlePlacesApiKey.trim().isNotEmpty) {
      requests.insert(
        0,
        _fetchGoogleCenters(position).then(
          (centers) => _LiveFetchResult(
            centers: centers,
            source: 'Google Places canlı veri',
          ),
        ),
      );
    }

    final results = await Future.wait(requests);
    final available = results
        .where((result) => result.centers.isNotEmpty)
        .toList();
    if (available.isEmpty) {
      return const _LiveFetchResult(
        centers: [],
        source: 'Canlı veri alınamadı',
      );
    }
    available.sort((a, b) => b.centers.length.compareTo(a.centers.length));
    return available.first;
  }

  List<_PhysiotherapistDistance> _rankByDistance(
    Position position,
    List<_Physiotherapist> centers,
  ) {
    final ranked = centers.map((center) {
      final meters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        center.latitude,
        center.longitude,
      );
      return _PhysiotherapistDistance(center: center, distanceInMeters: meters);
    }).toList();
    ranked.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
    return ranked;
  }

  Future<List<_Physiotherapist>> _fetchGoogleCenters(Position position) async {
    final payload = <String, dynamic>{
      'includedTypes': ['physiotherapist'],
      'maxResultCount': 16,
      'locationRestriction': {
        'circle': {
          'center': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'radius': 12000.0,
        },
      },
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _googlePlacesApiKey,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.location,'
                  'places.formattedAddress,places.nationalPhoneNumber,'
                  'places.primaryTypeDisplayName',
            },
            body: jsonEncode(payload),
          )
          .timeout(_liveRequestTimeout);

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }

      final places = decoded['places'];
      if (places is! List) {
        return const [];
      }

      final centers = <_Physiotherapist>[];
      final dedupe = <String>{};

      for (final raw in places) {
        if (raw is! Map) continue;

        final id = raw['id']?.toString() ?? '';
        final location = raw['location'];
        if (location is! Map) continue;

        final latitude = (location['latitude'] as num?)?.toDouble();
        final longitude = (location['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) continue;

        final displayName = raw['displayName'];
        final name = displayName is Map
            ? (displayName['text']?.toString() ?? '')
            : '';
        final finalName = name.trim().isEmpty ? 'Fizyoterapi Merkezi' : name;

        final primaryTypeDisplayName = raw['primaryTypeDisplayName'];
        final specialty = primaryTypeDisplayName is Map
            ? (primaryTypeDisplayName['text']?.toString() ?? '')
            : '';
        final finalSpecialty = specialty.trim().isEmpty
            ? 'Fizyoterapi'
            : specialty;

        final address =
            raw['formattedAddress']?.toString() ?? 'Adres bilgisi bulunamadı';
        final phone = raw['nationalPhoneNumber']?.toString() ?? '-';

        final dedupeKey = id.isNotEmpty
            ? id
            : '${finalName.toLowerCase()}_'
                  '${latitude.toStringAsFixed(4)}_'
                  '${longitude.toStringAsFixed(4)}';
        if (!dedupe.add(dedupeKey)) continue;

        centers.add(
          _Physiotherapist(
            name: finalName,
            specialty: finalSpecialty,
            address: address,
            phone: phone,
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }

      return centers;
    } catch (_) {
      return const [];
    }
  }

  Future<List<_Physiotherapist>> _fetchOverpassCenters(
    Position position,
  ) async {
    final lat = position.latitude.toStringAsFixed(6);
    final lon = position.longitude.toStringAsFixed(6);

    final query =
        '''
[out:json][timeout:10];
(
  node["healthcare"="physiotherapist"](around:12000,$lat,$lon);
  way["healthcare"="physiotherapist"](around:12000,$lat,$lon);
  relation["healthcare"="physiotherapist"](around:12000,$lat,$lon);
  node["healthcare:speciality"~"physio|fizyo",i](around:12000,$lat,$lon);
  node["name"~"fizyoterap|physio|fizyo",i](around:12000,$lat,$lon);
);
out center 40;
''';

    try {
      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            headers: {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=utf-8',
              'User-Agent': 'posture_app/1.0 nearby-physiotherapists',
            },
            body: 'data=${Uri.encodeQueryComponent(query)}',
          )
          .timeout(_liveRequestTimeout);
      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }

      return _parseOverpassResults(decoded);
    } catch (_) {
      return const [];
    }
  }

  List<_Physiotherapist> _parseOverpassResults(Map<String, dynamic> payload) {
    final rawElements = payload['elements'];
    if (rawElements is! List) {
      return const [];
    }

    final centers = <_Physiotherapist>[];
    final dedupe = <String>{};

    for (final raw in rawElements) {
      if (raw is! Map) continue;

      final tagsRaw = raw['tags'];
      final tags = tagsRaw is Map
          ? Map<String, dynamic>.from(tagsRaw)
          : const <String, dynamic>{};

      final latitude = _readCoordinate(raw, 'lat');
      final longitude = _readCoordinate(raw, 'lon');
      if (latitude == null || longitude == null) continue;

      final name =
          _pickTag(tags, ['name', 'official_name']) ?? 'Fizyoterapi Merkezi';
      final specialty =
          _pickTag(tags, ['healthcare:speciality', 'description']) ??
          'Fizyoterapi';
      final address = _buildAddress(tags);
      final phone = _pickTag(tags, ['contact:phone', 'phone']) ?? '-';

      final id =
          '${name.toLowerCase()}_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
      if (!dedupe.add(id)) continue;

      centers.add(
        _Physiotherapist(
          name: name,
          specialty: specialty,
          address: address,
          phone: phone,
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }

    return centers;
  }

  double? _readCoordinate(Map raw, String axis) {
    final value = raw[axis];
    if (value is num) {
      return value.toDouble();
    }

    final center = raw['center'];
    if (center is Map) {
      final centerValue = center[axis];
      if (centerValue is num) {
        return centerValue.toDouble();
      }
    }

    return null;
  }

  String _buildAddress(Map<String, dynamic> tags) {
    final full = _pickTag(tags, ['addr:full', 'address']);
    if (full != null && full.trim().isNotEmpty) {
      return full;
    }

    final street = _joinNonEmpty([
      _pickTag(tags, ['addr:street']),
      _pickTag(tags, ['addr:housenumber']),
    ], ' ');

    final locality = _pickTag(tags, [
      'addr:suburb',
      'addr:district',
      'addr:city',
      'addr:town',
      'addr:village',
    ]);

    final region = _pickTag(tags, ['addr:state', 'addr:province']);
    final country = _pickTag(tags, ['addr:country']);

    final line = _joinNonEmpty([street, locality, region, country], ', ');
    if (line.isNotEmpty) {
      return line;
    }

    return 'Adres bilgisi bulunamadı';
  }

  String? _pickTag(Map<String, dynamic> tags, List<String> keys) {
    for (final key in keys) {
      final value = tags[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _joinNonEmpty(List<String?> parts, String separator) {
    return parts
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(separator);
  }

  Future<void> _openDirections(_Physiotherapist center) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${center.latitude},${center.longitude}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
    }
  }

  Future<void> _callCenter(String phone) async {
    if (phone.trim().isEmpty || phone.trim() == '-') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon bilgisi bulunamadı.')),
      );
      return;
    }

    final cleaned = phone.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Arama başlatılamadı.')));
    }
  }

  Future<void> _emailPhysiotherapist(String email) async {
    if (email.trim().isEmpty || email.trim() == '-') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta bilgisi bulunamadi.')),
      );
      return;
    }

    final uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      queryParameters: const {
        'subject': 'Postur uygulamasi uzerinden iletisim',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta uygulamasi acilamadi.')),
      );
    }
  }

  Future<void> _sendRequest(
    Map<String, dynamic> profile,
    String message,
  ) async {
    final user = _currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talep icin once kullanici girisi yap.')),
      );
      return;
    }

    final userId = user['id']?.toString();
    final physioId = profile['id']?.toString();
    if (userId == null ||
        userId.isEmpty ||
        physioId == null ||
        physioId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Talep icin kullanici veya uzman profili eksik.'),
        ),
      );
      return;
    }

    final consentGranted = await _ensurePhysioSharingConsent(profile);
    if (!consentGranted) return;

    try {
      await Backend.createSupportRequest(
        physiotherapist: profile,
        userProfile: user,
        message: message,
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
      const SnackBar(content: Text('Talep fizyoterapist paneline gonderildi.')),
    );
  }

  Future<bool> _ensurePhysioSharingConsent(Map<String, dynamic> profile) async {
    final hasConsent = await ls.LocalStorage.hasConsent('physio_data_sharing');
    if (hasConsent) return true;
    if (!mounted) return false;

    final name = profile['full_name']?.toString() ?? 'fizyoterapist';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Veri Paylasimi Onayi'),
          content: Text(
            'Talep veya sohbet baslattiginda adin, iletisim bilgin, yazdigin mesaj ve uygulamadaki ilgili postur/saglik ozeti $name ile paylasilabilir. Bu paylasim fizyoterapist destegi icindir.',
            style: TextStyle(color: cs.onSurface.withAlpha(180), height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kabul ediyorum'),
            ),
          ],
        );
      },
    );

    if (accepted != true) return false;
    await ls.LocalStorage.setConsent('physio_data_sharing', true);
    await Backend.recordConsent(
      consentKey: 'physio_data_sharing',
      version: 'v1',
      granted: true,
      metadata: {
        'source': 'physiotherapist_contact',
        'physiotherapistId': profile['id']?.toString(),
      },
    );
    return true;
  }

  Future<void> _openRequestSheet(Map<String, dynamic> profile) async {
    var draft = '';
    final name = profile['full_name']?.toString() ?? 'Fizyoterapist';
    final clinic = profile['clinic_name']?.toString() ?? '';

    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E7A80).withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: Color(0xFF0E7A80),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'İletişim Talebi',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          clinic.isNotEmpty ? '$name — $clinic' : name,
                          style: TextStyle(
                            color: Theme.of(
                              ctx,
                            ).colorScheme.onSurface.withAlpha(160),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                minLines: 3,
                maxLines: 6,
                autofocus: true,
                onChanged: (value) => draft = value,
                decoration: const InputDecoration(
                  labelText: 'Mesajınız',
                  hintText:
                      'Şikayetinizi veya görüşme isteğinizi kısaca yazın.',
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, draft),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Talep Gönder'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || message == null) return;
    await _sendRequest(profile, message);
  }

  Future<Map<String, dynamic>> _ensureThread(
    Map<String, dynamic> profile,
  ) async {
    final user = _currentUser;
    if (user == null) throw Exception('Kullanici bulunamadi.');
    return Backend.ensureSupportRequest(
      physiotherapist: profile,
      userProfile: user,
    );
  }

  Future<void> _openChat(Map<String, dynamic> profile) async {
    final user = _currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj icin once kullanici girisi yap.')),
      );
      return;
    }

    final consentGranted = await _ensurePhysioSharingConsent(profile);
    if (!consentGranted) return;

    late final Map<String, dynamic> request;
    try {
      request = await _ensureThread(profile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          threadId: request['id']?.toString() ?? '',
          currentRole: 'user',
          currentName: user['full_name']?.toString() ?? 'Kullanici',
          currentEmail: user['email']?.toString() ?? '',
          peerName: profile['full_name']?.toString() ?? 'Fizyoterapist',
          peerEmail: profile['email']?.toString() ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCenters = _nearby
        .take(_maxVisibleCenters)
        .toList(growable: false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Yakındaki Fizyoterapi Merkezleri')),
        body: ModernBackground(
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: TabBar(
                    tabs: [
                      Tab(
                        icon: Icon(Icons.near_me_outlined),
                        text: 'Yakındaki',
                      ),
                      Tab(
                        icon: Icon(Icons.support_agent_outlined),
                        text: 'Online Destek',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _NearbyCentersTab(
                        loading: _loading,
                        error: _error,
                        visibleCenters: visibleCenters,
                        totalCount: _nearby.length,
                        sourceLabel: _sourceLabel,
                        position: _currentPosition,
                        lastUpdatedAt: _lastUpdatedAt,
                        isRefreshing: _isRefreshing,
                        onRefresh: () => _loadNearby(forceRefresh: true),
                        onRetry: () => _loadNearby(
                          forceRefresh: true,
                          showBlockingLoader: true,
                        ),
                        onDirections: (center) => _openDirections(center),
                        onCall: (phone) => _callCenter(phone),
                      ),
                      _OnlineSupportTab(
                        profiles: _registeredPhysiotherapists,
                        onCall: (profile) =>
                            _callCenter(profile['phone']?.toString() ?? ''),
                        onEmail: (profile) => _emailPhysiotherapist(
                          profile['email']?.toString() ?? '',
                        ),
                        onRequest: (profile) =>
                            _runUserAction(() => _openRequestSheet(profile)),
                        onMessage: (profile) =>
                            _runUserAction(() => _openChat(profile)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyCentersTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<_PhysiotherapistDistance> visibleCenters;
  final int totalCount;
  final String sourceLabel;
  final Position? position;
  final DateTime? lastUpdatedAt;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;
  final ValueChanged<_Physiotherapist> onDirections;
  final ValueChanged<String> onCall;

  const _NearbyCentersTab({
    required this.loading,
    required this.error,
    required this.visibleCenters,
    required this.totalCount,
    required this.sourceLabel,
    required this.position,
    required this.lastUpdatedAt,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onRetry,
    required this.onDirections,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView();
    if (error != null) return _ErrorView(message: error!, onRetry: onRetry);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: visibleCenters.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SummaryCard(
              totalCount: totalCount,
              sourceLabel: sourceLabel,
              position: position,
              lastUpdatedAt: lastUpdatedAt,
              isRefreshing: isRefreshing,
            );
          }

          final item = visibleCenters[index - 1];
          return _CenterCard(
            item: item,
            onDirections: () => onDirections(item.center),
            onCall: () => onCall(item.center.phone),
          );
        },
      ),
    );
  }
}

class _OnlineSupportTab extends StatelessWidget {
  final List<Map<String, dynamic>> profiles;
  final ValueChanged<Map<String, dynamic>> onCall;
  final ValueChanged<Map<String, dynamic>> onEmail;
  final ValueChanged<Map<String, dynamic>> onRequest;
  final ValueChanged<Map<String, dynamic>> onMessage;

  const _OnlineSupportTab({
    required this.profiles,
    required this.onCall,
    required this.onEmail,
    required this.onRequest,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: profiles.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _OnlineSupportSummary(totalCount: profiles.length);
        }

        final profile = profiles[index - 1];
        return _RegisteredPhysiotherapistCard(
          profile: profile,
          onCall: () => onCall(profile),
          onEmail: () => onEmail(profile),
          onRequest: () => onRequest(profile),
          onMessage: () => onMessage(profile),
        );
      },
    );
  }
}

class _OnlineSupportSummary extends StatelessWidget {
  final int totalCount;

  const _OnlineSupportSummary({required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7A80), Color(0xFF3D6DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330E7A80),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.support_agent_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Online Uzman Desteği',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalCount == 0
                      ? 'Kayıtlı online uzman yok. Fizyoterapist kaydı oluşturulunca burada görünür.'
                      : 'Uygulamaya kayıtlı uzmanlarla mesajlaşabilir veya talep gönderebilirsin.',
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$totalCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    height: 1,
                  ),
                ),
                Text(
                  'uzman',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterCard extends StatelessWidget {
  final _PhysiotherapistDistance item;
  final VoidCallback onDirections;
  final VoidCallback onCall;

  const _CenterCard({
    required this.item,
    required this.onDirections,
    required this.onCall,
  });

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Color _distanceColor(double meters) {
    if (meters < 1000) return const Color(0xFF15B88E);
    if (meters < 5000) return const Color(0xFF3D6DFF);
    return const Color(0xFFFF8A5B);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPhone =
        item.center.phone.trim().isNotEmpty && item.center.phone.trim() != '-';
    final distColor = _distanceColor(item.distanceInMeters);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3D6DFF), Color(0xFF0E7A80)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.center.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.center.specialty,
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: distColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: distColor.withAlpha(60)),
                  ),
                  child: Text(
                    _distanceLabel(item.distanceInMeters),
                    style: TextStyle(
                      color: distColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NearbyInfoRow(
              icon: Icons.location_on_outlined,
              text: item.center.address,
            ),
            if (hasPhone)
              _NearbyInfoRow(
                icon: Icons.phone_outlined,
                text: item.center.phone,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasPhone ? onCall : null,
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Hemen Ara'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: const Text('Yol Tarifi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NearbyInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withAlpha(150)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: cs.onSurface.withAlpha(175),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisteredPhysiotherapistCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onRequest;
  final VoidCallback onMessage;

  const _RegisteredPhysiotherapistCard({
    required this.profile,
    required this.onCall,
    required this.onEmail,
    required this.onRequest,
    required this.onMessage,
  });

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'F';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = profile['full_name']?.toString() ?? 'Fizyoterapist';
    final clinic = profile['clinic_name']?.toString() ?? '';
    final specialty = profile['specialty']?.toString() ?? 'Fizyoterapi';
    final services = profile['services']?.toString() ?? '';
    final workingHours = profile['working_hours']?.toString() ?? '';
    final onlineConsultation = profile['online_consultation'] == true;
    final phone = profile['phone']?.toString() ?? '-';
    final email = profile['email']?.toString() ?? '-';
    final address = profile['address']?.toString() ?? '';
    final hasPhone = phone.trim().isNotEmpty && phone.trim() != '-';
    final hasEmail = email.trim().isNotEmpty && email.trim() != '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Üst kısım: avatar + isim + rozetler ───────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0E7A80), Color(0xFF15B88E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      if (clinic.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          clinic,
                          style: TextStyle(
                            color: cs.onSurface.withAlpha(170),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _PhysioChip(
                            label: 'Kayıtlı Uzman',
                            color: const Color(0xFF3D6DFF),
                            icon: Icons.verified_outlined,
                          ),
                          if (onlineConsultation)
                            _PhysioChip(
                              label: 'Online',
                              color: const Color(0xFF15B88E),
                              icon: Icons.video_call_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // ── Bilgiler ───────────────────────────────────────────────
            _NearbyInfoRow(
              icon: Icons.medical_information_outlined,
              text: specialty,
            ),
            if (services.trim().isNotEmpty)
              _NearbyInfoRow(icon: Icons.checklist_outlined, text: services),
            if (workingHours.trim().isNotEmpty)
              _NearbyInfoRow(icon: Icons.schedule_outlined, text: workingHours),
            if (address.trim().isNotEmpty && address.trim() != '-')
              _NearbyInfoRow(icon: Icons.location_on_outlined, text: address),
            if (hasPhone)
              _NearbyInfoRow(icon: Icons.phone_outlined, text: phone),
            if (hasEmail) _NearbyInfoRow(icon: Icons.mail_outline, text: email),
            const SizedBox(height: 12),
            // ── Aksiyonlar ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(Icons.chat_bubble_outline, size: 17),
                    label: const Text('Mesaj Gönder'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRequest,
                    icon: const Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 17,
                    ),
                    label: const Text('Talep'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasPhone ? onCall : null,
                    icon: const Icon(Icons.call_outlined, size: 17),
                    label: const Text('Ara'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasEmail ? onEmail : null,
                    icon: const Icon(Icons.mail_outline, size: 17),
                    label: const Text('E-posta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhysioChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _PhysioChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Yakındaki fizyoterapi merkezleri getiriliyor...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalCount;
  final String sourceLabel;
  final Position? position;
  final DateTime? lastUpdatedAt;
  final bool isRefreshing;

  const _SummaryCard({
    required this.totalCount,
    required this.sourceLabel,
    required this.position,
    required this.lastUpdatedAt,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final secondaryText = onSurface.withAlpha(185);
    final sourceText = Theme.of(context).colorScheme.primary.withAlpha(220);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.near_me_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Konumuna göre sıralandı',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D6DFF).withAlpha(24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$totalCount merkez',
                    style: const TextStyle(
                      color: Color(0xFF2F57D6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sana en yakın merkezler mesafeye göre listeleniyor. '
              'Listeyi yenilemek için aşağı çekebilirsin.',
              style: TextStyle(color: secondaryText),
            ),
            const SizedBox(height: 8),
            Text(
              'Veri kaynağı: $sourceLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sourceText,
              ),
            ),
            if (lastUpdatedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Son güncelleme: ${_formatTime(lastUpdatedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withAlpha(165),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (position != null) ...[
              const SizedBox(height: 4),
              Text(
                'Konum: ${position!.latitude.toStringAsFixed(4)}, '
                '${position!.longitude.toStringAsFixed(4)}',
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withAlpha(165),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (isRefreshing) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Liste güncelleniyor...',
                    style: TextStyle(
                      color: onSurface.withAlpha(185),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 42),
            const SizedBox(height: 10),
            const Text(
              'Merkezler yüklenemedi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: onSurface.withAlpha(180)),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveFetchResult {
  final List<_Physiotherapist> centers;
  final String source;

  const _LiveFetchResult({required this.centers, required this.source});
}

class _Physiotherapist {
  final String name;
  final String specialty;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;

  const _Physiotherapist({
    required this.name,
    required this.specialty,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
  });
}

class _PhysiotherapistDistance {
  final _Physiotherapist center;
  final double distanceInMeters;

  const _PhysiotherapistDistance({
    required this.center,
    required this.distanceInMeters,
  });
}

const _fallbackCenters = <_Physiotherapist>[
  _Physiotherapist(
    name: 'Beşiktaş Postür Fizyoterapi',
    specialty: 'Postür analizi ve masa başı rehabilitasyon',
    address: 'Sinanpaşa Mah., Beşiktaş / İstanbul',
    phone: '+90 212 123 45 67',
    latitude: 41.0444,
    longitude: 29.0043,
  ),
  _Physiotherapist(
    name: 'Kadıköy Omurga ve Hareket Merkezi',
    specialty: 'Bel-boyun rehabilitasyonu, manuel terapi',
    address: 'Caferağa Mah., Kadıköy / İstanbul',
    phone: '+90 216 444 21 10',
    latitude: 40.9902,
    longitude: 29.0268,
  ),
  _Physiotherapist(
    name: 'Şişli Klinik Fizyoterapi',
    specialty: 'Skolyoz takibi ve duruş eğitimi',
    address: 'Halaskargazi Cad., Şişli / İstanbul',
    phone: '+90 212 654 78 91',
    latitude: 41.0537,
    longitude: 28.9889,
  ),
  _Physiotherapist(
    name: 'Bakırköy Hareket Terapi Merkezi',
    specialty: 'Ofis çalışanı postür programları',
    address: 'Zeytinlik Mah., Bakırköy / İstanbul',
    phone: '+90 212 554 20 20',
    latitude: 40.9779,
    longitude: 28.8726,
  ),
  _Physiotherapist(
    name: 'Ataşehir Fizik Tedavi Noktası',
    specialty: 'Sporcu sağlığı ve duruş düzeltme',
    address: 'Atatürk Mah., Ataşehir / İstanbul',
    phone: '+90 216 351 40 40',
    latitude: 40.9978,
    longitude: 29.1282,
  ),
  _Physiotherapist(
    name: 'Ankara Core Fizyoterapi',
    specialty: 'Core güçlendirme ve omurga sağlığı',
    address: 'Kızılay, Çankaya / Ankara',
    phone: '+90 312 417 30 30',
    latitude: 39.9208,
    longitude: 32.8541,
  ),
  _Physiotherapist(
    name: 'İzmir Denge ve Postür Merkezi',
    specialty: 'Denge, yürüyüş ve postür rehabilitasyonu',
    address: 'Alsancak, Konak / İzmir',
    phone: '+90 232 463 55 55',
    latitude: 38.4320,
    longitude: 27.1458,
  ),
];
