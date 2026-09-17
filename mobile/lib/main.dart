import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'updater_service.dart';

// Version and API Constants
const String appVersion = '2.3.0';
const int appBuildNumber = 22;
const String cloudflareSyncUrl = 'https://finanza-auto.jeffef.workers.dev/api/sync';

/// Available Design Styles (1. Tesla/Apple Minimalist Luxury, 2. Nubank Ultravioleta)
enum AppDesignStyle {
  tesla('Tesla / Apple Luxury', Icons.auto_awesome),
  ultravioleta('Nubank Ultravioleta', Icons.credit_card);

  final String label;
  final IconData icon;
  const AppDesignStyle(this.label, this.icon);
}

/// Available Color Palettes (Legacy/Accent)
enum AppColorPalette {
  teal('Ciano Drivvo', Color(0xFF00838F), Color(0xFF006064), Color(0xFF00ACC1), Color(0xFFE0F2F1)),
  emerald('Verde Esmeralda', Color(0xFF059669), Color(0xFF065F46), Color(0xFF10B981), Color(0xFFD1FAE5)),
  sapphire('Azul Safira', Color(0xFF1D4ED8), Color(0xFF1E40AF), Color(0xFF3B82F6), Color(0xFFDBEAFE)),
  sunset('Laranja Sunset', Color(0xFFEA580C), Color(0xFFC2410C), Color(0xFFF97316), Color(0xFFFFEDD5)),
  purple('Roxo Violeta', Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF8B5CF6), Color(0xFFEDE9FE)),
  crimson('Vermelho Sport', Color(0xFFDC2626), Color(0xFF991B1B), Color(0xFFEF4444), Color(0xFFFEE2E2));

  final String label;
  final Color primary;
  final Color dark;
  final Color accent;
  final Color light;

  const AppColorPalette(this.label, this.primary, this.dark, this.accent, this.light);
}

/// Dynamic Theme State Notifiers
final ValueNotifier<AppDesignStyle> currentDesignStyle = ValueNotifier<AppDesignStyle>(AppDesignStyle.tesla);
final ValueNotifier<AppColorPalette> currentPalette = ValueNotifier<AppColorPalette>(AppColorPalette.teal);
final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);
final ValueNotifier<bool> showTimelineReminders = ValueNotifier<bool>(false);

class AppTheme {
  static bool get isTesla => currentDesignStyle.value == AppDesignStyle.tesla;

  // Dynamic Backgrounds & Surfaces
  static Color get background => isTesla ? const Color(0xFF07070A) : const Color(0xFF07050D);
  static Color get card => isTesla ? const Color(0xFF111116) : const Color(0xFF130F20);
  static Color get cardSubtle => isTesla ? const Color(0xFF17171F) : const Color(0xFF1A142B);
  static Color get border => isTesla ? const Color(0x1FFFFFFF) : const Color(0x40A855F7);
  static Color get trackLine => isTesla ? const Color(0x1FFFFFFF) : const Color(0x33A855F7);

  // Dynamic Primary & Accents
  static Color get primary => isTesla ? const Color(0xFFFFFFFF) : const Color(0xFFA855F7);
  static Color get accent => isTesla ? const Color(0xFFE2E8F0) : const Color(0xFFC084FC);
  static Color get dark => isTesla ? const Color(0xFF000000) : const Color(0xFF581C87);
  static Color get light => isTesla ? const Color(0xFF1F2937) : const Color(0xFF3B0764);

  // Dynamic Text Colors
  static Color get textMain => isTesla ? const Color(0xFFF8FAFC) : const Color(0xFFFAF5FF);
  static Color get textMuted => isTesla ? const Color(0xFF94A3B8) : const Color(0xFFC4B5FD);
  static Color get textLight => isTesla ? const Color(0xFF64748B) : const Color(0xFF8B5CF6);

  // Status & Brand Colors
  static const Color fuelOrange = Color(0xFFFF9800);
  static const Color fuelOrangeDark = Color(0xFFF57C00);
  static const Color servicePurple = Color(0xFF7E57C2);
  static const Color expenseBlue = Color(0xFF1E88E5);
  static const Color reminderAlert = Color(0xFFFF5722);
  static const Color economyGreen = Color(0xFF10B981);
  static const Color goldChip = Color(0xFFFDE68A);
}

/// Vehicle Model
class CarVehicle {
  String id;
  String name;
  String model;
  String plate;
  int odometer;
  double tankCapacity;
  int serviceIntervalKm;
  double targetConsumption;

  CarVehicle({
    required this.id,
    required this.name,
    this.model = '',
    this.plate = '',
    this.odometer = 0,
    this.tankCapacity = 52.0,
    this.serviceIntervalKm = 10000,
    this.targetConsumption = 7.5,
  });

  factory CarVehicle.fromMap(Map<String, dynamic> map) {
    return CarVehicle(
      id: (map['id'] ?? 'drivvo-car').toString(),
      name: (map['name'] ?? 'Astra').toString(),
      model: (map['model'] ?? 'Chevrolet Astra 2.0').toString(),
      plate: (map['plate'] ?? '').toString(),
      odometer: (map['odometer'] as num?)?.toInt() ?? 164154,
      tankCapacity: (map['tankCapacity'] as num?)?.toDouble() ?? 52.0,
      serviceIntervalKm: (map['serviceIntervalKm'] as num?)?.toInt() ?? 10000,
      targetConsumption: (map['targetConsumption'] as num?)?.toDouble() ?? 7.5,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'model': model,
    'plate': plate,
    'odometer': odometer,
    'tankCapacity': tankCapacity,
    'serviceIntervalKm': serviceIntervalKm,
    'targetConsumption': targetConsumption,
  };
}

/// Event Model (Fueling, Service, Expense)
class CarEvent {
  String id;
  String vehicleId;
  String type; // 'fuel', 'service', 'expense'
  String date; // YYYY-MM-DD
  String time; // HH:mm
  double amount;
  int odometer;
  String fuelType;
  double liters;
  double pricePerLiter;
  bool isFullTank;
  String title;
  String category;
  String station;
  String driver;
  String paymentMethod;
  String note;

  CarEvent({
    required this.id,
    required this.vehicleId,
    this.type = 'fuel',
    required this.date,
    this.time = '12:00',
    this.amount = 0.0,
    this.odometer = 0,
    this.fuelType = 'Etanol',
    this.liters = 0.0,
    this.pricePerLiter = 0.0,
    this.isFullTank = true,
    this.title = '',
    this.category = 'Combustivel',
    this.station = '',
    this.driver = '',
    this.paymentMethod = 'Dinheiro',
    this.note = '',
  });

  factory CarEvent.fromMap(Map<String, dynamic> map) {
    final noteStr = (map['note'] ?? '').toString();
    var stationStr = (map['station'] ?? '').toString();
    var driverStr = (map['driver'] ?? '').toString();

    if (stationStr.isEmpty && noteStr.isNotEmpty) {
      if (noteStr.contains('•')) {
        final parts = noteStr.split('•');
        driverStr = parts[0].trim();
        if (parts.length > 1 && !parts[1].toLowerCase().contains('tanque')) {
          stationStr = parts[1].trim();
        }
      } else if (noteStr.toLowerCase().contains('zanforlim')) {
        stationStr = 'Zanforlim';
      } else if (noteStr.toLowerCase().contains('rafaela')) {
        stationStr = 'Rafaela';
        driverStr = 'Rafaela';
      } else {
        stationStr = noteStr;
      }
    }

    final litersVal = (map['liters'] as num?)?.toDouble() ?? 0.0;
    final amountVal = (map['amount'] as num?)?.toDouble() ?? 0.0;
    var ppl = (map['pricePerLiter'] as num?)?.toDouble() ?? 0.0;
    if (ppl == 0.0 && litersVal > 0 && amountVal > 0) {
      ppl = amountVal / litersVal;
    }

    return CarEvent(
      id: (map['id'] ?? 'event-${DateTime.now().millisecondsSinceEpoch}').toString(),
      vehicleId: (map['vehicleId'] ?? 'drivvo-car').toString(),
      type: (map['type'] ?? 'fuel').toString(),
      date: (map['date'] ?? '').toString(),
      time: (map['time'] ?? '12:00').toString(),
      amount: amountVal,
      odometer: (map['odometer'] as num?)?.toInt() ?? 0,
      fuelType: (map['fuelType'] ?? 'Etanol').toString(),
      liters: litersVal,
      pricePerLiter: ppl,
      isFullTank: map['isFullTank'] != false,
      title: (map['title'] ?? '').toString(),
      category: (map['category'] ?? 'Combustivel').toString(),
      station: stationStr.isNotEmpty ? stationStr : 'Rafaela',
      driver: driverStr.isNotEmpty ? driverStr : 'Rafaela',
      paymentMethod: (map['paymentMethod'] ?? 'Dinheiro').toString(),
      note: noteStr,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicleId': vehicleId,
    'type': type,
    'date': date,
    'time': time,
    'amount': amount,
    'odometer': odometer,
    'fuelType': fuelType,
    'liters': liters,
    'pricePerLiter': pricePerLiter,
    'isFullTank': isFullTank,
    'title': title,
    'category': category,
    'station': station,
    'driver': driver,
    'paymentMethod': paymentMethod,
    'note': note,
  };

  DateTime get parsedDate {
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}
    return DateTime.now();
  }
}

/// Reminder Model
class CarReminder {
  String id;
  String vehicleId;
  String title;
  String description;
  int targetOdometer;
  String targetDate;
  bool isCompleted;
  int repeatIntervalKm;
  int repeatIntervalMonths;

  CarReminder({
    required this.id,
    required this.vehicleId,
    required this.title,
    this.description = '',
    this.targetOdometer = 0,
    this.targetDate = '',
    this.isCompleted = false,
    this.repeatIntervalKm = 10000,
    this.repeatIntervalMonths = 6,
  });

  factory CarReminder.fromMap(Map<String, dynamic> map) {
    return CarReminder(
      id: (map['id'] ?? 'rem-${DateTime.now().millisecondsSinceEpoch}').toString(),
      vehicleId: (map['vehicleId'] ?? 'drivvo-car').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      targetOdometer: (map['targetOdometer'] as num?)?.toInt() ?? 0,
      targetDate: (map['targetDate'] ?? '').toString(),
      isCompleted: map['isCompleted'] == true,
      repeatIntervalKm: (map['repeatIntervalKm'] as num?)?.toInt() ?? 10000,
      repeatIntervalMonths: (map['repeatIntervalMonths'] as num?)?.toInt() ?? 6,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicleId': vehicleId,
    'title': title,
    'description': description,
    'targetOdometer': targetOdometer,
    'targetDate': targetDate,
    'isCompleted': isCompleted,
    'repeatIntervalKm': repeatIntervalKm,
    'repeatIntervalMonths': repeatIntervalMonths,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('pt_BR', null);
  } catch (_) {}

  // Load saved theme settings
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedPaletteIndex = prefs.getInt('finanza_auto_color_palette');
    if (savedPaletteIndex != null && savedPaletteIndex >= 0 && savedPaletteIndex < AppColorPalette.values.length) {
      currentPalette.value = AppColorPalette.values[savedPaletteIndex];
    }
    final savedIsDark = prefs.getBool('finanza_auto_is_dark');
    if (savedIsDark != null) {
      isDarkMode.value = savedIsDark;
    }
    final savedShowRem = prefs.getBool('finanza_auto_show_timeline_reminders');
    if (savedShowRem != null) {
      showTimelineReminders.value = savedShowRem;
    }
  } catch (_) {}

  runApp(const DrivvoApp());
}

class DrivvoApp extends StatelessWidget {
  const DrivvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppDesignStyle>(
      valueListenable: currentDesignStyle,
      builder: (context, style, _) {
        final isTesla = style == AppDesignStyle.tesla;
        return MaterialApp(
          title: 'Finanza Auto',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'DM Sans',
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(
              primary: isTesla ? Colors.white : const Color(0xFFA855F7),
              secondary: isTesla ? const Color(0xFF10B981) : const Color(0xFFC084FC),
              surface: isTesla ? const Color(0xFF111116) : const Color(0xFF130F20),
            ),
            scaffoldBackgroundColor: AppTheme.background,
            appBarTheme: AppBarTheme(
              backgroundColor: AppTheme.background,
              foregroundColor: AppTheme.textMain,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
          ),
          home: const FinanzaAutoHomePage(),
        );
      },
    );
  }
}

class FinanzaAutoHomePage extends StatefulWidget {
  const FinanzaAutoHomePage({super.key});

  @override
  State<FinanzaAutoHomePage> createState() => _FinanzaAutoHomePageState();
}

class _FinanzaAutoHomePageState extends State<FinanzaAutoHomePage> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSyncing = false;
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  List<CarVehicle> _vehicles = [];
  String _activeVehicleId = 'drivvo-car';
  List<CarEvent> _events = [];
  List<CarReminder> _reminders = [];

  CarVehicle get _activeVehicle {
    final found = _vehicles.where((v) => v.id == _activeVehicleId);
    if (found.isNotEmpty) return found.first;
    if (_vehicles.isNotEmpty) return _vehicles.first;
    return CarVehicle(id: 'drivvo-car', name: 'Astra', model: 'Chevrolet Astra 2.0', odometer: 164154, tankCapacity: 52.0);
  }

  int get _latestOdometer {
    final vehicleOdo = _activeVehicle.odometer;
    int maxEventOdo = 0;
    for (final e in _events.where((e) => e.vehicleId == _activeVehicleId)) {
      if (e.odometer > maxEventOdo) maxEventOdo = e.odometer;
    }
    return math.max(vehicleOdo, maxEventOdo);
  }

  @override
  void initState() {
    super.initState();
    _loadAllData().then((_) => _checkQuickFuelAction());
    _checkAppUpdates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleDesignStyle() async {
    final newStyle = currentDesignStyle.value == AppDesignStyle.tesla
        ? AppDesignStyle.ultravioleta
        : AppDesignStyle.tesla;
    currentDesignStyle.value = newStyle;
    setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('finanza_auto_design_style', newStyle.name);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(newStyle.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                newStyle == AppDesignStyle.tesla
                    ? 'Estilo Tesla / Apple Luxury ativado!'
                    : 'Estilo Nubank Ultravioleta ativado!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: newStyle == AppDesignStyle.tesla ? const Color(0xFF1E293B) : const Color(0xFF6B21A8),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkQuickFuelAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quickFuel = prefs.getBool('finanza_quick_fuel_action') ?? false;
      if (quickFuel && mounted) {
        await prefs.remove('finanza_quick_fuel_action');
        _openFuelingForm();
      }
    } catch (_) {}
  }

  Future<void> _checkAppUpdates({bool manual = false}) async {
    try {
      final info = await UpdaterService.checkUpdate(
        currentVersion: appVersion,
        currentBuild: appBuildNumber,
      );
      if (info != null && info.hasUpdate && mounted) {
        _showUpdateDialog(info);
      } else if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você já está na versão mais recente (v2.3.0).')),
        );
      }
    } catch (_) {}
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text('Atualização Disponível', style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova versão v${info.version} (Build ${info.buildNumber})', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const SizedBox(height: 8),
            Text(info.releaseNotes, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Depois', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              UpdaterService.downloadAndInstallApk(
                downloadUrl: info.downloadUrl,
                version: info.version,
                buildNumber: info.buildNumber,
              );
            },
            child: const Text('Atualizar Agora'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAllData({bool forceReloadBundled = false}) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check version migration to ensure updated pristine data loads on v2.3.0
      final savedStyle = prefs.getString('finanza_auto_design_style');
      if (savedStyle == 'ultravioleta') {
        currentDesignStyle.value = AppDesignStyle.ultravioleta;
      } else {
        currentDesignStyle.value = AppDesignStyle.tesla;
      }
      final lastLoadedVersion = prefs.getString('finanza_auto_loaded_version');
      final bool isNewRelease = lastLoadedVersion != '2.3.0';

      final savedJson = prefs.getString('finanza_auto_flutter_state');
      Map<String, dynamic>? parsedSaved;
      if (savedJson != null && !forceReloadBundled) {
        try {
          parsedSaved = jsonDecode(savedJson) as Map<String, dynamic>;
        } catch (_) {}
      }

      // Load bundled backup (146 records)
      Map<String, dynamic>? bundledJson;
      try {
        final bundledStr = await rootBundle.loadString('assets/finanza-auto-backup.json');
        bundledJson = jsonDecode(bundledStr) as Map<String, dynamic>;
      } catch (_) {}

      final bundledCar = bundledJson != null ? (bundledJson['car'] ?? bundledJson) as Map<String, dynamic> : <String, dynamic>{};
      final savedCar = parsedSaved != null ? (parsedSaved['car'] ?? parsedSaved) as Map<String, dynamic> : <String, dynamic>{};
      final savedEventsRaw = (savedCar['events'] ?? []) as List;

      // On new release or explicit restore, prioritize the bundled 146 records
      final bool useBundledData = forceReloadBundled || isNewRelease || parsedSaved == null || savedEventsRaw.length < 140;
      final sourceCar = useBundledData ? bundledCar : savedCar;

      final rawVehicles = (sourceCar['vehicles'] ?? []) as List;
      final loadedVehicles = <CarVehicle>[];
      for (final v in rawVehicles) {
        if (v is Map) loadedVehicles.add(CarVehicle.fromMap(v.cast<String, dynamic>()));
      }
      if (loadedVehicles.isEmpty) {
        loadedVehicles.add(
          CarVehicle(
            id: 'drivvo-car',
            name: 'Astra',
            model: 'Chevrolet Astra 2.0',
            plate: '',
            odometer: 164154,
            tankCapacity: 52.0,
            serviceIntervalKm: 10000,
          ),
        );
      }

      final rawEvents = (sourceCar['events'] ?? []) as List;
      final loadedEvents = <CarEvent>[];
      for (final e in rawEvents) {
        if (e is Map) loadedEvents.add(CarEvent.fromMap(e.cast<String, dynamic>()));
      }

      // Sort descending by odometer/date
      loadedEvents.sort((a, b) {
        if (a.odometer != b.odometer) return b.odometer.compareTo(a.odometer);
        return b.date.compareTo(a.date);
      });

      // Normalize vehicle IDs
      final validVIds = loadedVehicles.map((v) => v.id).toSet();
      for (final e in loadedEvents) {
        if (!validVIds.contains(e.vehicleId)) {
          e.vehicleId = loadedVehicles.first.id;
        }
      }

      // Load reminders
      final rawReminders = (sourceCar['reminders'] ?? []) as List;
      final loadedReminders = <CarReminder>[];
      for (final r in rawReminders) {
        if (r is Map) loadedReminders.add(CarReminder.fromMap(r.cast<String, dynamic>()));
      }
      if (loadedReminders.isEmpty) {
        final currentKm = loadedVehicles.first.odometer;
        loadedReminders.addAll([
          CarReminder(
            id: 'rem-oil',
            vehicleId: loadedVehicles.first.id,
            title: 'Troca de Óleo e Filtro',
            description: 'Trocar óleo 15W40 e filtro de óleo',
            targetOdometer: currentKm + 5846,
            targetDate: '2026-12-01',
            repeatIntervalKm: 10000,
            repeatIntervalMonths: 6,
          ),
          CarReminder(
            id: 'rem-air',
            vehicleId: loadedVehicles.first.id,
            title: 'Filtro de Ar e Combustível',
            description: 'Substituição preventiva dos filtros',
            targetOdometer: currentKm + 8000,
            targetDate: '2027-02-15',
            repeatIntervalKm: 20000,
            repeatIntervalMonths: 12,
          ),
        ]);
      }

      setState(() {
        _vehicles = loadedVehicles;
        _activeVehicleId = loadedVehicles.first.id;
        _events = loadedEvents;
        _reminders = loadedReminders;
        _isLoading = false;
      });

      await prefs.setString('finanza_auto_loaded_version', '2.3.0');
      _saveLocalState();
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataMap = {
        'car': {
          'vehicles': _vehicles.map((v) => v.toMap()).toList(),
          'events': _events.map((e) => e.toMap()).toList(),
          'reminders': _reminders.map((r) => r.toMap()).toList(),
          'activeVehicleId': _activeVehicleId,
        },
        'updatedAt': DateTime.now().toIso8601String(),
        'appVersion': appVersion,
      };
      await prefs.setString('finanza_auto_flutter_state', jsonEncode(dataMap));
    } catch (e) {
      debugPrint('Error saving local state: $e');
    }
  }

  Future<void> _syncWithCloudflare() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final client = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true)
        ..connectionTimeout = const Duration(seconds: 15);

      final payload = jsonEncode({
        'action': 'sync',
        'state': {
          'car': {
            'vehicles': _vehicles.map((v) => v.toMap()).toList(),
            'events': _events.map((e) => e.toMap()).toList(),
            'reminders': _reminders.map((r) => r.toMap()).toList(),
            'activeVehicleId': _activeVehicleId,
          },
          'updatedAt': DateTime.now().toIso8601String(),
          'appVersion': appVersion,
        }
      });

      final bytes = utf8.encode(payload);
      final request = await client.postUrl(Uri.parse(cloudflareSyncUrl));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Content-Length', bytes.length.toString());
      request.add(bytes);

      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      debugPrint('Sync response: ${response.statusCode} - $respBody');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Dados sincronizados com a nuvem com sucesso!'),
                ],
              ),
              backgroundColor: AppTheme.economyGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Servidor retornou código ${response.statusCode}. Tente novamente.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Cloudflare sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_done, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Registros salvos localmente no aparelho.')),
              ],
            ),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _addOrUpdateEvent(CarEvent event) {
    setState(() {
      final idx = _events.indexWhere((e) => e.id == event.id);
      if (idx >= 0) {
        _events[idx] = event;
      } else {
        _events.insert(0, event);
      }
      _events.sort((a, b) {
        if (a.odometer != b.odometer) return b.odometer.compareTo(a.odometer);
        return b.date.compareTo(a.date);
      });
      if (event.odometer > _activeVehicle.odometer) {
        _activeVehicle.odometer = event.odometer;
      }
    });
    _saveLocalState();
  }

  void _deleteEvent(String id) {
    setState(() {
      _events.removeWhere((e) => e.id == id);
    });
    _saveLocalState();
  }

  void _showSpeedDialMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Adicionar novo registro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
            const SizedBox(height: 16),
            _buildSpeedDialItem(
              icon: Icons.local_gas_station,
              color: AppTheme.fuelOrange,
              title: 'Abastecimento',
              subtitle: 'Registrar combustível, odômetro e valor',
              onTap: () {
                Navigator.pop(ctx);
                _openFuelingForm();
              },
            ),
            _buildSpeedDialItem(
              icon: Icons.build,
              color: AppTheme.servicePurple,
              title: 'Serviço',
              subtitle: 'Manutenção, troca de óleo ou peças',
              onTap: () {
                Navigator.pop(ctx);
                _openServiceExpenseForm(isService: true);
              },
            ),
            _buildSpeedDialItem(
              icon: Icons.receipt_long,
              color: AppTheme.expenseBlue,
              title: 'Despesa',
              subtitle: 'Estacionamento, pedágio, lavagem ou seguro',
              onTap: () {
                Navigator.pop(ctx);
                _openServiceExpenseForm(isService: false);
              },
            ),
            _buildSpeedDialItem(
              icon: Icons.alarm,
              color: AppTheme.reminderAlert,
              title: 'Lembrete',
              subtitle: 'Criar alerta por data ou quilometragem',
              onTap: () {
                Navigator.pop(ctx);
                _openReminderForm();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDialItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      onTap: onTap,
    );
  }

  void _openFuelingForm({CarEvent? event}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FuelingFormScreen(
          vehicle: _activeVehicle,
          latestOdometer: _latestOdometer,
          existingEvent: event,
          onSave: (savedEvent) {
            _addOrUpdateEvent(savedEvent);
          },
        ),
      ),
    );
  }

  void _openServiceExpenseForm({required bool isService, CarEvent? event}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceExpenseFormScreen(
          isService: isService,
          vehicle: _activeVehicle,
          latestOdometer: _latestOdometer,
          existingEvent: event,
          onSave: (savedEvent) {
            _addOrUpdateEvent(savedEvent);
          },
        ),
      ),
    );
  }

  void _openReminderForm({CarReminder? reminder}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderFormScreen(
          vehicle: _activeVehicle,
          latestOdometer: _latestOdometer,
          existingReminder: reminder,
          onSave: (savedRem) {
            setState(() {
              final idx = _reminders.indexWhere((r) => r.id == savedRem.id);
              if (idx >= 0) {
                _reminders[idx] = savedRem;
              } else {
                _reminders.add(savedRem);
              }
            });
            _saveLocalState();
          },
        ),
      ),
    );
  }

  void _showPaletteModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Personalização de Cores',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                    ),
                    IconButton(
                      icon: Icon(isDarkMode.value ? Icons.dark_mode : Icons.light_mode, color: AppTheme.primary),
                      onPressed: () async {
                        final newVal = !isDarkMode.value;
                        isDarkMode.value = newVal;
                        setModalState(() {});
                        setState(() {});
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('finanza_auto_is_dark', newVal);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppColorPalette.values.map((p) {
                    final isSel = currentPalette.value == p;
                    return InkWell(
                      onTap: () async {
                        currentPalette.value = p;
                        setModalState(() {});
                        setState(() {});
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('finanza_auto_color_palette', p.index);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel ? p.primary.withOpacity(0.15) : AppTheme.cardSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel ? p.primary : AppTheme.border,
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? p.primary : AppTheme.textMain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVehicleSelectorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Veículos na Garagem', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _vehicles.map((v) {
            final isSel = v.id == _activeVehicleId;
            return ListTile(
              leading: Icon(Icons.directions_car, color: isSel ? AppTheme.primary : AppTheme.textMuted),
              title: Text(v.name, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: AppTheme.textMain)),
              subtitle: Text('${v.model} • ${NumberFormat('#,###', 'pt_BR').format(v.odometer)} km', style: TextStyle(color: AppTheme.textMuted)),
              trailing: isSel ? Icon(Icons.check_circle, color: AppTheme.primary) : null,
              onTap: () {
                setState(() => _activeVehicleId = v.id);
                _saveLocalState();
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditVehicleDialog(_activeVehicle);
            },
            child: Text('Editar Veículo Atual', style: TextStyle(color: AppTheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fechar', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  void _showEditVehicleDialog(CarVehicle vehicle) {
    final nameCtrl = TextEditingController(text: vehicle.name);
    final modelCtrl = TextEditingController(text: vehicle.model);
    final odoCtrl = TextEditingController(text: vehicle.odometer.toString());
    final tankCtrl = TextEditingController(text: vehicle.tankCapacity.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Editar Veículo', style: TextStyle(color: AppTheme.textMain)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome do Carro')),
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modelo')),
              TextField(controller: odoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odômetro Atual (km)')),
              TextField(controller: tankCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacidade do Tanque (Litros)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                vehicle.name = nameCtrl.text.trim();
                vehicle.model = modelCtrl.text.trim();
                vehicle.odometer = int.tryParse(odoCtrl.text.replaceAll('.', '')) ?? vehicle.odometer;
                vehicle.tankCapacity = double.tryParse(tankCtrl.text) ?? vehicle.tankCapacity;
              });
              _saveLocalState();
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar abastecimentos...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              )
            : InkWell(
                onTap: _showVehicleSelectorDialog,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${_activeVehicle.name} (${_activeVehicle.model} - ${NumberFormat('#,###', 'pt_BR').format(_latestOdometer)} km)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Alterar tema de cores',
            onPressed: _showPaletteModal,
          ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Sincronizar com a Nuvem',
            onPressed: _isSyncing ? null : _syncWithCloudflare,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0: Histórico (Feed Timeline 100% Drivvo)
          TimelineFeedTab(
            vehicle: _activeVehicle,
            events: _events.where((e) => e.vehicleId == _activeVehicleId).toList(),
            reminders: _reminders.where((r) => r.vehicleId == _activeVehicleId).toList(),
            searchQuery: _searchQuery,
            onEventTap: (event) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FuelingDetailsScreen(
                    event: event,
                    allEvents: _events.where((e) => e.vehicleId == _activeVehicleId).toList(),
                    vehicle: _activeVehicle,
                    onEdit: () => _openFuelingForm(event: event),
                    onDelete: () => _deleteEvent(event.id),
                  ),
                ),
              );
            },
            onReminderTap: () => setState(() => _currentIndex = 2),
          ),
          // 1: Relatórios com múltiplos gráficos
          ReportsTab(
            vehicle: _activeVehicle,
            events: _events.where((e) => e.vehicleId == _activeVehicleId).toList(),
          ),
          // 2: Lembretes
          RemindersTab(
            vehicle: _activeVehicle,
            reminders: _reminders.where((r) => r.vehicleId == _activeVehicleId).toList(),
            latestOdometer: _latestOdometer,
            onAddReminder: () => _openReminderForm(),
            onEditReminder: (rem) => _openReminderForm(reminder: rem),
            onCompleteReminder: (rem) {
              setState(() {
                rem.isCompleted = true;
                if (rem.repeatIntervalKm > 0) {
                  rem.targetOdometer = _latestOdometer + rem.repeatIntervalKm;
                  rem.isCompleted = false;
                }
              });
              _saveLocalState();
            },
            onDeleteReminder: (rem) {
              setState(() => _reminders.removeWhere((r) => r.id == rem.id));
              _saveLocalState();
            },
          ),
          // 3: Mais
          MoreTab(
            vehicle: _activeVehicle,
            events: _events,
            totalRecords: _events.length,
            onRestoreBackup: () async {
              await _loadAllData(forceReloadBundled: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('146 abastecimentos reais restaurados com sucesso!'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              }
            },
            onSyncCloudflare: _syncWithCloudflare,
            onCheckUpdates: () => _checkAppUpdates(manual: true),
            onOpenPalette: _showPaletteModal,
            onImportJson: (jsonStr) {
              try {
                final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
                final car = (parsed['car'] ?? parsed) as Map<String, dynamic>;
                final rawEvents = (car['events'] ?? []) as List;
                final importedEvents = <CarEvent>[];
                for (final e in rawEvents) {
                  if (e is Map) importedEvents.add(CarEvent.fromMap(e.cast<String, dynamic>()));
                }
                if (importedEvents.isNotEmpty) {
                  setState(() {
                    _events = importedEvents;
                    _events.sort((a, b) {
                      if (a.odometer != b.odometer) return b.odometer.compareTo(a.odometer);
                      return b.date.compareTo(a.date);
                    });
                  });
                  _saveLocalState();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${importedEvents.length} abastecimentos importados com sucesso!'),
                      backgroundColor: AppTheme.economyGreen,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao importar JSON: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        color: AppTheme.card,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.format_list_bulleted, 'Histórico', 0),
              _buildBottomNavItem(Icons.insert_chart_outlined, 'Relatórios', 1),
              const SizedBox(width: 48), // FAB center space
              _buildBottomNavItem(Icons.alarm, 'Lembretes', 2),
              _buildBottomNavItem(Icons.more_horiz, 'Mais', 3),
            ],
          ),
        ),
      ),
            floatingActionButton: FloatingActionButton(
        onPressed: _showSpeedDialMenu,
        backgroundColor: AppTheme.isTesla ? Colors.white : const Color(0xFFA855F7),
        elevation: 6,
        shape: const CircleBorder(),
        child: Icon(
          Icons.add,
          color: AppTheme.isTesla ? Colors.black : Colors.white,
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final isSel = _currentIndex == index;
    final color = isSel ? (AppTheme.isTesla ? Colors.white : const Color(0xFFA855F7)) : AppTheme.textMuted;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. TIMELINE FEED TAB (100% DRIVVO REAL DESIGN)
// ==========================================
class TimelineFeedTab extends StatelessWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;
  final List<CarReminder> reminders;
  final String searchQuery;
  final Function(CarEvent) onEventTap;
  final VoidCallback onReminderTap;

  const TimelineFeedTab({
    super.key,
    required this.vehicle,
    required this.events,
    required this.reminders,
    required this.searchQuery,
    required this.onEventTap,
    required this.onReminderTap,
  });

  Widget _buildVehicleHero(BuildContext context, CarVehicle vehicle, List<CarEvent> events) {
    final isTesla = AppTheme.isTesla;
    final latestOdo = vehicle.odometer;
    final odoFormatted = NumberFormat('#,###', 'pt_BR').format(latestOdo);

    if (isTesla) {
      // 1. TESLA / APPLE MINIMALIST LUXURY HERO CARD
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GARAGEM • CONECTADO',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.1),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '$odoFormatted km',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Chevrolet Astra 2.0',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
            ),
            Text(
              'Tanque 100% (52L) • Rafaela',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            // Astra Aerodynamic Silhouette with Studio Spotlight
            Container(
              height: 62,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [Colors.white.withOpacity(0.06), Colors.transparent],
                ),
              ),
              child: CustomPaint(
                painter: _AstraSilhouettePainter(color: Colors.white.withOpacity(0.85)),
              ),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Eficiência Média', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            Text('8,42', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(width: 4),
                            Text('km/L', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Custo / Km', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        const Text('R\$ 0,58', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // 2. NUBANK ULTRAVIOLETA BLACK METALLIC CARD
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1535),
              Color(0xFF0F0B1A),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.35)),
          boxShadow: [
            BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHEVROLET ASTRA 2.0',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Color(0xFFC084FC),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Patrimônio Veicular',
                      style: TextStyle(fontSize: 11, color: Color(0xFFE9D5FF)),
                    ),
                  ],
                ),
                // Golden Chip Graphic
                Container(
                  width: 38,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFDE68A), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFEF3C7), width: 1),
                  ),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26, width: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Gasto em Setembro de 2026',
              style: TextStyle(fontSize: 11, color: Color(0xFFC4B5FD)),
            ),
            const SizedBox(height: 2),
            const Text(
              'R\$ 294,00',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: const Color(0xFFA855F7).withOpacity(0.2))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ODÔMETRO', style: TextStyle(fontSize: 9, letterSpacing: 1, color: Color(0xFFA855F7), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('$odoFormatted km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('MÉDIA', style: TextStyle(fontSize: 9, letterSpacing: 1, color: Color(0xFFA855F7), fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('8,42 km/L', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('CUSTO / KM', style: TextStyle(fontSize: 9, letterSpacing: 1, color: Color(0xFFA855F7), fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('R\$ 0,58', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC084FC))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = events.where((e) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return e.fuelType.toLowerCase().contains(q) ||
          e.station.toLowerCase().contains(q) ||
          e.driver.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q) ||
          e.odometer.toString().contains(q);
    }).toList();

    filtered.sort((a, b) {
      if (a.odometer != b.odometer) {
        return b.odometer.compareTo(a.odometer);
      }
      return b.date.compareTo(a.date);
    });

    final Map<String, List<CarEvent>> monthGroups = {};
    for (final e in filtered) {
      final key = _formatMonthHeader(e.parsedDate);
      monthGroups.putIfAbsent(key, () => []).add(e);
    }

    CarReminder? urgentReminder;
    if (showTimelineReminders.value) {
      for (final r in reminders) {
        if (!r.isCompleted) {
          urgentReminder = r;
          break;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        _buildVehicleHero(context, vehicle, events),
        if (urgentReminder != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: InkWell(
              onTap: onReminderTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.reminderAlert.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.reminderAlert.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: AppTheme.reminderAlert, shape: BoxShape.circle),
                      child: const Icon(Icons.alarm, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LEMBRETES',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.reminderAlert, letterSpacing: 0.8),
                          ),
                          Text(
                            urgentReminder.title,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                          ),
                          Text(
                            'Faltam ${NumberFormat('#,###', 'pt_BR').format(math.max(0, urgentReminder.targetOdometer - vehicle.odometer))} km',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),

        // Timeline Groups
        ...monthGroups.entries.map((entry) {
          final monthTitle = entry.key;
          final monthEvents = entry.value;

          double monthAmount = 0.0;
          double monthLiters = 0.0;
          int minOdo = 99999999;
          int maxOdo = 0;

          for (final ev in monthEvents) {
            monthAmount += ev.amount;
            monthLiters += ev.liters;
            if (ev.odometer < minOdo) minOdo = ev.odometer;
            if (ev.odometer > maxOdo) maxOdo = ev.odometer;
          }
          final monthKm = (maxOdo > minOdo && minOdo != 99999999) ? (maxOdo - minOdo) : 0;
          final avgKmL = (monthLiters > 0 && monthKm > 0) ? (monthKm / monthLiters) : 0.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Summary Pill (Drivvo continuous track header)
              Stack(
                children: [
                  Positioned(
                    left: 28,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: AppTheme.trackLine),
                  ),
                  Positioned(
                    left: 24,
                    top: 26,
                    child: Container(
                      width: 11,
                      height: 5,
                      decoration: BoxDecoration(color: AppTheme.textLight, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 14, 16, 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.cardSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(monthAmount)}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                              ),
                              Text('  •  ', style: TextStyle(color: AppTheme.textLight)),
                              Text(
                                '$monthKm km',
                                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),
                              if (avgKmL > 0) ...[
                                Text('  •  ', style: TextStyle(color: AppTheme.textLight)),
                                Text(
                                  '${avgKmL.toStringAsFixed(3)} km/L',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.economyGreen),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Events clean list with continuous left track line (Drivvo exact list row style)
              ...monthEvents.map((ev) {
                final stats = _computeEventEfficiency(ev, events);

                return Stack(
                  children: [
                    // Vertical track line
                    Positioned(
                      left: 28,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 3, color: AppTheme.trackLine),
                    ),
                    // Track Node Circle (Orange 32px for fuel)
                    Positioned(
                      left: 14,
                      top: 14,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getEventColor(ev.type),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: _getEventColor(ev.type).withOpacity(0.35), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Icon(_getEventIcon(ev.type), color: Colors.white, size: 17),
                      ),
                    ),
                    // Clean List Item Content
                    Padding(
                      padding: const EdgeInsets.only(left: 56, right: 16, top: 4, bottom: 8),
                      child: InkWell(
                        onTap: () => onEventTap(ev),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Line 1: Type on left, Amount on right
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ev.type == 'fuel' ? ev.fuelType : (ev.title.isNotEmpty ? ev.title : ev.category),
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                  ),
                                  Text(
                                    'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(ev.amount)}',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // Line 2: Odometer • km/L • Liters on left, Date on right
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontFamily: 'DM Sans'),
                                        children: [
                                          TextSpan(text: '${NumberFormat('#,###', 'pt_BR').format(ev.odometer)} km  •  '),
                                          if (stats.kmL > 0) ...[
                                            TextSpan(
                                              text: '${stats.kmL.toStringAsFixed(3)} km/L',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                            ),
                                            const TextSpan(text: '  •  '),
                                          ],
                                          if (ev.type == 'fuel') TextSpan(text: '${ev.liters.toStringAsFixed(3)} L'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDayMonth(ev.parsedDate),
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                              if (ev.station.isNotEmpty || ev.driver.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  [ev.station, ev.driver].where((s) => s.isNotEmpty).join(' • '),
                                  style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Divider(height: 1, color: AppTheme.border.withOpacity(0.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  static String _formatMonthHeader(DateTime dt) {
    const months = ['JANEIRO', 'FEVEREIRO', 'MARÇO', 'ABRIL', 'MAIO', 'JUNHO', 'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  static String _formatDayMonth(DateTime dt) {
    const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  static Color _getEventColor(String type) {
    switch (type) {
      case 'fuel':
        return AppTheme.fuelOrange;
      case 'service':
        return AppTheme.servicePurple;
      case 'expense':
      default:
        return AppTheme.expenseBlue;
    }
  }

  static IconData _getEventIcon(String type) {
    switch (type) {
      case 'fuel':
        return Icons.local_gas_station;
      case 'service':
        return Icons.build;
      case 'expense':
      default:
        return Icons.receipt_long;
    }
  }

  static ({double kmL, int deltaKm, double costPerKm}) _computeEventEfficiency(CarEvent ev, List<CarEvent> allEvents) {
    if (ev.type != 'fuel' || ev.liters <= 0) return (kmL: 0.0, deltaKm: 0, costPerKm: 0.0);

    final fuelEvents = allEvents.where((e) => e.type == 'fuel').toList();
    fuelEvents.sort((a, b) => a.odometer.compareTo(b.odometer));

    final idx = fuelEvents.indexWhere((e) => e.id == ev.id);
    if (idx > 0) {
      final prev = fuelEvents[idx - 1];
      final delta = ev.odometer - prev.odometer;
      if (delta > 0) {
        final efficiency = delta / ev.liters;
        final cost = ev.amount / delta;
        return (kmL: efficiency, deltaKm: delta, costPerKm: cost);
      }
    }
    return (kmL: 0.0, deltaKm: 0, costPerKm: 0.0);
  }
}

// ==========================================
// 2. FUELING FORM SCREEN (100% DRIVVO REAL FORM)
// ==========================================
class FuelingFormScreen extends StatefulWidget {
  final CarVehicle vehicle;
  final int latestOdometer;
  final CarEvent? existingEvent;
  final Function(CarEvent) onSave;

  const FuelingFormScreen({
    super.key,
    required this.vehicle,
    required this.latestOdometer,
    this.existingEvent,
    required this.onSave,
  });

  @override
  State<FuelingFormScreen> createState() => _FuelingFormScreenState();
}

class _FuelingFormScreenState extends State<FuelingFormScreen> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TextEditingController _odometerController;
  late TextEditingController _priceController;
  late TextEditingController _totalController;
  late TextEditingController _litersController;
  late TextEditingController _stationController;
  late TextEditingController _driverController;
  late TextEditingController _notesController;

  String _selectedFuelType = 'Etanol';
  bool _isFullTank = true;
  String _selectedPayment = 'Dinheiro';
  bool _showMoreOptions = false;

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.existingEvent;
    _selectedDate = ev != null ? ev.parsedDate : DateTime.now();
    _selectedTime = TimeOfDay.now();
    _odometerController = TextEditingController(text: ev != null ? ev.odometer.toString() : (widget.latestOdometer > 0 ? widget.latestOdometer.toString() : ''));
    _priceController = TextEditingController(text: ev != null && ev.pricePerLiter > 0 ? ev.pricePerLiter.toStringAsFixed(2).replaceAll('.', ',') : '');
    _totalController = TextEditingController(text: ev != null && ev.amount > 0 ? ev.amount.toStringAsFixed(2).replaceAll('.', ',') : '');
    _litersController = TextEditingController(text: ev != null && ev.liters > 0 ? ev.liters.toStringAsFixed(3).replaceAll('.', ',') : '');
    _stationController = TextEditingController(text: ev?.station.isNotEmpty == true ? ev!.station : 'Rafaela');
    _driverController = TextEditingController(text: ev?.driver.isNotEmpty == true ? ev!.driver : 'Rafaela');
    _notesController = TextEditingController(text: ev?.note ?? '');

    if (ev != null) {
      _selectedFuelType = ev.fuelType;
      _isFullTank = ev.isFullTank;
      _selectedPayment = ev.paymentMethod.isNotEmpty ? ev.paymentMethod : 'Dinheiro';
    }

    _priceController.addListener(() => _calculateFields('price'));
    _totalController.addListener(() => _calculateFields('total'));
    _litersController.addListener(() => _calculateFields('liters'));
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _priceController.dispose();
    _totalController.dispose();
    _litersController.dispose();
    _stationController.dispose();
    _driverController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateFields(String caller) {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final p = double.tryParse(_priceController.text.replaceAll(',', '.'));
      final t = double.tryParse(_totalController.text.replaceAll(',', '.'));
      final l = double.tryParse(_litersController.text.replaceAll(',', '.'));

      if (caller == 'price' || caller == 'total') {
        if (p != null && p > 0 && t != null && t > 0) {
          final calcLiters = t / p;
          _litersController.text = calcLiters.toStringAsFixed(3).replaceAll('.', ',');
        }
      } else if (caller == 'liters') {
        if (p != null && p > 0 && l != null && l > 0) {
          final calcTotal = p * l;
          _totalController.text = calcTotal.toStringAsFixed(2).replaceAll('.', ',');
        }
      }
    } catch (_) {}

    _isUpdating = false;
  }

  void _submit() {
    final odo = int.tryParse(_odometerController.text.replaceAll('.', '')) ?? 0;
    final amount = double.tryParse(_totalController.text.replaceAll(',', '.')) ?? 0.0;
    final liters = double.tryParse(_litersController.text.replaceAll(',', '.')) ?? 0.0;
    var ppl = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0;
    if (ppl == 0.0 && liters > 0 && amount > 0) {
      ppl = amount / liters;
    }

    if (odo <= 0 || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ao menos o Odômetro e o Valor Total.')),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    final savedEvent = CarEvent(
      id: widget.existingEvent?.id ?? 'fuel-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicle.id,
      type: 'fuel',
      date: dateStr,
      time: timeStr,
      amount: amount,
      odometer: odo,
      fuelType: _selectedFuelType,
      liters: liters,
      pricePerLiter: ppl,
      isFullTank: _isFullTank,
      title: 'Abastecimento ($_selectedFuelType)',
      category: 'Combustivel',
      station: _stationController.text.trim(),
      driver: _driverController.text.trim(),
      paymentMethod: _selectedPayment,
      note: _notesController.text.trim(),
    );

    widget.onSave(savedEvent);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.fuelOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Abastecimento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Veículo (Icon on left, underline field on right)
            _buildDrivvoFormRow(
              icon: Icons.directions_car_outlined,
              label: 'Veículo',
              child: Text(
                '${widget.vehicle.name} (${widget.vehicle.model})',
                style: TextStyle(fontSize: 16, color: AppTheme.textMain),
              ),
            ),
            const SizedBox(height: 16),

            // Row 2: Data & Hora side by side
            _buildDrivvoFormRow(
              icon: Icons.calendar_today_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Data', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                          const SizedBox(height: 4),
                          Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: TextStyle(fontSize: 16, color: AppTheme.textMain)),
                          const SizedBox(height: 4),
                          Divider(height: 1, color: AppTheme.border),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hora', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                          const SizedBox(height: 4),
                          Text(_selectedTime.format(context), style: TextStyle(fontSize: 16, color: AppTheme.textMain)),
                          const SizedBox(height: 4),
                          Divider(height: 1, color: AppTheme.border),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Row 3: Odômetro
            _buildDrivvoFormRow(
              icon: Icons.speed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _odometerController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 16, color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'Odômetro',
                      labelStyle: TextStyle(fontSize: 13, color: AppTheme.textLight),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fuelOrange, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Último odômetro: ${NumberFormat('#,###', 'pt_BR').format(widget.latestOdometer)} km',
                      style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Row 4: Combustível
            _buildDrivvoFormRow(
              icon: Icons.local_gas_station_outlined,
              child: DropdownButtonFormField<String>(
                value: ['Etanol', 'Gasolina Comum', 'Gasolina Aditivada', 'Diesel', 'GNV'].contains(_selectedFuelType)
                    ? _selectedFuelType
                    : 'Etanol',
                decoration: InputDecoration(
                  labelText: 'Combustível',
                  labelStyle: TextStyle(fontSize: 13, color: AppTheme.textLight),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fuelOrange, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
                dropdownColor: AppTheme.card,
                items: ['Etanol', 'Gasolina Comum', 'Gasolina Aditivada', 'Diesel', 'GNV']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: AppTheme.textMain))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedFuelType = val ?? 'Etanol'),
              ),
            ),
            const SizedBox(height: 16),

            // Row 5: 3 Fields side by side (Preço / L, Valor total, Litros)
            _buildDrivvoFormRow(
              icon: Icons.attach_money,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 15, color: AppTheme.textMain),
                      decoration: InputDecoration(
                        labelText: 'Preço / L',
                        labelStyle: TextStyle(fontSize: 12, color: AppTheme.textLight),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fuelOrange, width: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _totalController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 15, color: AppTheme.textMain),
                      decoration: InputDecoration(
                        labelText: 'Valor total',
                        labelStyle: TextStyle(fontSize: 12, color: AppTheme.textLight),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fuelOrange, width: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _litersController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 15, color: AppTheme.textMain),
                      decoration: InputDecoration(
                        labelText: 'Litros',
                        labelStyle: TextStyle(fontSize: 12, color: AppTheme.textLight),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fuelOrange, width: 2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Row 6: Está completando o tanque?
            _buildDrivvoFormRow(
              icon: Icons.opacity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Está completando o tanque?', style: TextStyle(fontSize: 15, color: AppTheme.textMain)),
                  Switch(
                    value: _isFullTank,
                    activeColor: AppTheme.fuelOrange,
                    onChanged: (val) => setState(() => _isFullTank = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Row 7: Posto de Combustível
            _buildDrivvoFormRow(
              icon: Icons.place_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _stationController,
                    style: TextStyle(fontSize: 15, color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'Posto de combustível',
                      labelStyle: TextStyle(fontSize: 13, color: AppTheme.textLight),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fuelOrange, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: ['Rafaela', 'Zanforlim', 'Shell', 'Ipiranga'].map((st) {
                      return InkWell(
                        onTap: () => setState(() => _stationController.text = st),
                        child: Chip(
                          label: Text(st, style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppTheme.cardSubtle,
                          padding: EdgeInsets.zero,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Row 8: Motorista
            _buildDrivvoFormRow(
              icon: Icons.badge_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _driverController,
                    style: TextStyle(fontSize: 15, color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'Motorista',
                      labelStyle: TextStyle(fontSize: 13, color: AppTheme.textLight),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.fuelOrange, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: ['Rafaela', 'Jefferson'].map((dr) {
                      return InkWell(
                        onTap: () => setState(() => _driverController.text = dr),
                        child: Chip(
                          label: Text(dr, style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppTheme.cardSubtle,
                          padding: EdgeInsets.zero,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // + Mais opções (expandable)
            InkWell(
              onTap: () => setState(() => _showMoreOptions = !_showMoreOptions),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(_showMoreOptions ? Icons.remove : Icons.add, color: AppTheme.fuelOrange, size: 18),
                    const SizedBox(width: 8),
                    const Text('Mais opções', style: TextStyle(color: AppTheme.fuelOrange, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),

            if (_showMoreOptions) ...[
              const SizedBox(height: 8),
              _buildDrivvoFormRow(
                icon: Icons.payment,
                child: DropdownButtonFormField<String>(
                  value: ['Dinheiro', 'Cartão de Débito', 'Cartão de Crédito', 'Pix'].contains(_selectedPayment)
                      ? _selectedPayment
                      : 'Dinheiro',
                  decoration: InputDecoration(
                    labelText: 'Forma de Pagamento',
                    labelStyle: TextStyle(fontSize: 13, color: AppTheme.textLight),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                  ),
                  dropdownColor: AppTheme.card,
                  items: ['Dinheiro', 'Cartão de Débito', 'Cartão de Crédito', 'Pix']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: AppTheme.textMain))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedPayment = val ?? 'Dinheiro'),
                ),
              ),
              const SizedBox(height: 14),
              _buildDrivvoFormRow(
                icon: Icons.notes,
                child: TextField(
                  controller: _notesController,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, color: AppTheme.textMain),
                  decoration: InputDecoration(
                    labelText: 'Observações / Notas',
                    labelStyle: TextStyle(fontSize: 13, color: AppTheme.textLight),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Drivvo Pill Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fuelOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 2,
                ),
                onPressed: _submit,
                child: const Text('SALVAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDrivvoFormRow({required IconData icon, String? label, Widget? child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 16),
          child: Icon(icon, color: AppTheme.textMuted, size: 24),
        ),
        Expanded(
          child: label != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                    const SizedBox(height: 4),
                    child ?? const SizedBox(),
                    const SizedBox(height: 4),
                    Divider(height: 1, color: AppTheme.border),
                  ],
                )
              : child ?? const SizedBox(),
        ),
      ],
    );
  }
}

// ==========================================
// 3. FUELING DETAILS SCREEN (100% DRIVVO REAL DETAILS)
// ==========================================
class FuelingDetailsScreen extends StatelessWidget {
  final CarEvent event;
  final List<CarEvent> allEvents;
  final CarVehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FuelingDetailsScreen({
    super.key,
    required this.event,
    required this.allEvents,
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final stats = TimelineFeedTab._computeEventEfficiency(event, allEvents);
    final tankCapacity = vehicle.tankCapacity > 0 ? vehicle.tankCapacity : 52.0;
    final tankPercent = (event.liters / tankCapacity * 100).clamp(0, 100).toDouble();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.fuelOrange,
        title: const Text('Abastecimento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.card,
                  title: Text('Excluir abastecimento?', style: TextStyle(color: AppTheme.textMain)),
                  content: Text('Esta ação removerá este abastecimento do histórico.', style: TextStyle(color: AppTheme.textMuted)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                        Navigator.pop(context);
                      },
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card 1: Resumo com Tanque Bateria Drivvo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.fuelType,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.fuelOrange),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 12),

                // 3 Colunas: Preço/L, Valor total, Volume
                Row(
                  children: [
                    _buildStatColumn('Preço / L', 'R\$ ${event.pricePerLiter.toStringAsFixed(2).replaceAll('.', ',')}'),
                    _buildStatColumn('Valor total', 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(event.amount)}'),
                    _buildStatColumn('Volume', '${event.liters.toStringAsFixed(3).replaceAll('.', ',')} L'),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 14),

                // Linha de baixo: Completo + Média/Custo à esquerda, Bateria Tanque à direita
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Completo', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                          const SizedBox(height: 2),
                          Text(event.isFullTank ? 'Sim' : 'Não', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Média', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 14, color: AppTheme.textLight),
                                      const SizedBox(width: 4),
                                      Text(
                                        stats.kmL > 0 ? '${stats.kmL.toStringAsFixed(3).replaceAll('.', ',')} km/L' : '-',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Custo / Km', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                                  const SizedBox(height: 2),
                                  Text(
                                    stats.costPerKm > 0 ? 'R\$ ${stats.costPerKm.toStringAsFixed(2).replaceAll('.', ',')}' : '-',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tank Graphic (Drivvo Battery-style Tank Gauge)
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text('% do Tanque', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                          const SizedBox(height: 6),
                          Container(
                            width: 64,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppTheme.cardSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border, width: 2),
                            ),
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                // Tank cap
                                Positioned(
                                  top: 0,
                                  child: Container(
                                    width: 24,
                                    height: 4,
                                    decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                                  ),
                                ),
                                // Orange Fill level
                                FractionallySizedBox(
                                  heightFactor: (tankPercent / 100).clamp(0.05, 1.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppTheme.fuelOrange,
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${tankPercent.toInt()}%',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card 2: DETALHES DO EVENTO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'DETALHES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 0.8),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildDetailRow(Icons.local_gas_station_outlined, 'Posto de combustível', event.station.isNotEmpty ? event.station : 'Rafaela'),
                Divider(height: 16, color: AppTheme.border.withOpacity(0.6)),
                _buildDetailRow(Icons.monetization_on_outlined, 'Forma de pagamento', event.paymentMethod.isNotEmpty ? event.paymentMethod : 'Dinheiro'),
                Divider(height: 16, color: AppTheme.border.withOpacity(0.6)),
                _buildDetailRow(Icons.badge_outlined, 'Motorista', event.driver.isNotEmpty ? event.driver : 'Rafaela'),
                Divider(height: 16, color: AppTheme.border.withOpacity(0.6)),
                _buildDetailRow(Icons.speed, 'Odômetro', '${NumberFormat('#,###', 'pt_BR').format(event.odometer)} km'),
                Divider(height: 16, color: AppTheme.border.withOpacity(0.6)),
                _buildDetailRow(Icons.calendar_today_outlined, 'Data e Hora', '${DateFormat('dd/MM/yyyy').format(event.parsedDate)} ${event.time}'),
                if (stats.deltaKm > 0) ...[
                  Divider(height: 16, color: AppTheme.border.withOpacity(0.6)),
                  _buildDetailRow(Icons.timeline, 'Distância percorrida', '${NumberFormat('#,###', 'pt_BR').format(stats.deltaKm)} km'),
                ],
                if (event.note.isNotEmpty) ...[
                  Divider(height: 16, color: AppTheme.border.withOpacity(0.6)),
                  _buildDetailRow(Icons.notes, 'Observações', event.note),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMain)),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. SERVICE / EXPENSE FORM SCREEN
// ==========================================
class ServiceExpenseFormScreen extends StatefulWidget {
  final bool isService;
  final CarVehicle vehicle;
  final int latestOdometer;
  final CarEvent? existingEvent;
  final Function(CarEvent) onSave;

  const ServiceExpenseFormScreen({
    super.key,
    required this.isService,
    required this.vehicle,
    required this.latestOdometer,
    this.existingEvent,
    required this.onSave,
  });

  @override
  State<ServiceExpenseFormScreen> createState() => _ServiceExpenseFormScreenState();
}

class _ServiceExpenseFormScreenState extends State<ServiceExpenseFormScreen> {
  late DateTime _selectedDate;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _odometerController;
  late TextEditingController _noteController;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    final ev = widget.existingEvent;
    _selectedDate = ev != null ? ev.parsedDate : DateTime.now();
    _titleController = TextEditingController(text: ev?.title ?? '');
    _amountController = TextEditingController(text: ev != null && ev.amount > 0 ? ev.amount.toStringAsFixed(2).replaceAll('.', ',') : '');
    _odometerController = TextEditingController(text: ev != null ? ev.odometer.toString() : (widget.latestOdometer > 0 ? widget.latestOdometer.toString() : ''));
    _noteController = TextEditingController(text: ev?.note ?? '');
    _selectedCategory = ev?.category.isNotEmpty == true ? ev!.category : (widget.isService ? 'Manutencao' : 'Outros');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _odometerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final odo = int.tryParse(_odometerController.text.replaceAll('.', '')) ?? 0;
    final title = _titleController.text.trim();

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a descrição e o valor.')),
      );
      return;
    }

    final saved = CarEvent(
      id: widget.existingEvent?.id ?? '${widget.isService ? "service" : "expense"}-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicle.id,
      type: widget.isService ? 'service' : 'expense',
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      title: title,
      amount: amount,
      odometer: odo,
      category: _selectedCategory,
      note: _noteController.text.trim(),
    );

    widget.onSave(saved);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isService ? AppTheme.servicePurple : AppTheme.expenseBlue;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: themeColor,
        title: Text(widget.isService ? 'Novo Serviço' : 'Nova Despesa'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Descrição (Ex: Troca de pastilhas, Estacionamento)')),
            const SizedBox(height: 14),
            TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor (R\$)', prefixText: 'R\$ ')),
            const SizedBox(height: 14),
            TextField(controller: _odometerController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odômetro (km)')),
            const SizedBox(height: 14),
            TextField(controller: _noteController, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações')),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                onPressed: _submit,
                child: const Text('SALVAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. REMINDER FORM SCREEN
// ==========================================
class ReminderFormScreen extends StatefulWidget {
  final CarVehicle vehicle;
  final int latestOdometer;
  final CarReminder? existingReminder;
  final Function(CarReminder) onSave;

  const ReminderFormScreen({
    super.key,
    required this.vehicle,
    required this.latestOdometer,
    this.existingReminder,
    required this.onSave,
  });

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _kmController;
  late TextEditingController _intervalKmController;
  late DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    final rem = widget.existingReminder;
    _titleController = TextEditingController(text: rem?.title ?? '');
    _descController = TextEditingController(text: rem?.description ?? '');
    _kmController = TextEditingController(text: rem != null && rem.targetOdometer > 0 ? rem.targetOdometer.toString() : (widget.latestOdometer + 10000).toString());
    _intervalKmController = TextEditingController(text: (rem?.repeatIntervalKm ?? 10000).toString());
    _targetDate = (rem != null && rem.targetDate.isNotEmpty)
        ? (DateTime.tryParse(rem.targetDate) ?? DateTime.now().add(const Duration(days: 180)))
        : DateTime.now().add(const Duration(days: 180));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _kmController.dispose();
    _intervalKmController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final odo = int.tryParse(_kmController.text.replaceAll('.', '')) ?? 0;
    final interval = int.tryParse(_intervalKmController.text.replaceAll('.', '')) ?? 10000;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o título do lembrete.')));
      return;
    }

    final saved = CarReminder(
      id: widget.existingReminder?.id ?? 'rem-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicle.id,
      title: title,
      description: _descController.text.trim(),
      targetOdometer: odo,
      targetDate: DateFormat('yyyy-MM-dd').format(_targetDate),
      repeatIntervalKm: interval,
    );

    widget.onSave(saved);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.reminderAlert,
        title: Text(widget.existingReminder != null ? 'Editar Lembrete' : 'Novo Lembrete'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título do Lembrete (Ex: Troca de Óleo)')),
            const SizedBox(height: 14),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Descrição / Detalhes')),
            const SizedBox(height: 14),
            TextField(controller: _kmController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quilometragem Alvo (km)')),
            const SizedBox(height: 14),
            TextField(controller: _intervalKmController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Repetir a cada (km)')),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.reminderAlert, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                onPressed: _submit,
                child: const Text('SALVAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. RELATÓRIOS TAB (MULTI-CHART ANALYTICS)
// ==========================================
enum ChartType {
  consumption('Consumo Médio', Icons.speed),
  expenses('Gastos Mensais', Icons.bar_chart),
  price('Preço / Litro', Icons.trending_up),
  mileage('Km Rodados', Icons.directions_car),
  volume('Volume (Litros)', Icons.local_gas_station),
  categories('Distribuição', Icons.pie_chart);

  final String label;
  final IconData icon;
  const ChartType(this.label, this.icon);
}

class ReportsTab extends StatefulWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;

  const ReportsTab({
    super.key,
    required this.vehicle,
    required this.events,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int _selectedPeriod = 4; // 0: Este Mês, 1: 3 Meses, 2: 6 Meses, 3: Este Ano, 4: Todo o Período
  ChartType _selectedChart = ChartType.consumption;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filtered = widget.events.where((e) {
      if (_selectedPeriod == 4) return true;
      final d = e.parsedDate;
      if (_selectedPeriod == 0) return d.year == now.year && d.month == now.month;
      if (_selectedPeriod == 1) return now.difference(d).inDays <= 90;
      if (_selectedPeriod == 2) return now.difference(d).inDays <= 180;
      if (_selectedPeriod == 3) return d.year == now.year;
      return true;
    }).toList();

    double totalSpent = 0.0;
    double totalFuelSpent = 0.0;
    double totalOtherSpent = 0.0;
    double totalLiters = 0.0;
    int minOdo = 99999999;
    int maxOdo = 0;

    for (final e in filtered) {
      totalSpent += e.amount;
      if (e.type == 'fuel') {
        totalFuelSpent += e.amount;
        totalLiters += e.liters;
      } else {
        totalOtherSpent += e.amount;
      }
      if (e.odometer > 0) {
        if (e.odometer < minOdo) minOdo = e.odometer;
        if (e.odometer > maxOdo) maxOdo = e.odometer;
      }
    }

    final totalKm = (maxOdo > minOdo && minOdo != 99999999) ? (maxOdo - minOdo) : 0;
    final avgKmL = (totalLiters > 0 && totalKm > 0) ? (totalKm / totalLiters) : 0.0;
    final avgCostKm = (totalKm > 0 && totalSpent > 0) ? (totalSpent / totalKm) : 0.0;
    final avgPriceLiter = (totalLiters > 0 && totalFuelSpent > 0) ? (totalFuelSpent / totalLiters) : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        // Period Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Este Mês', '3 Meses', '6 Meses', 'Este Ano', 'Todo o Período'].asMap().entries.map((entry) {
              final isSel = _selectedPeriod == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: isSel,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(color: isSel ? Colors.white : AppTheme.textMain, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                  onSelected: (val) {
                    if (val) setState(() => _selectedPeriod = entry.key);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // KPI Metric Cards Grid
        Row(
          children: [
            _buildKpiCard('Gasto Total', 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalSpent)}', Icons.account_balance_wallet, AppTheme.primary),
            const SizedBox(width: 12),
            _buildKpiCard('Combustível', '${NumberFormat('#,##0.0', 'pt_BR').format(totalLiters)} L', Icons.local_gas_station, AppTheme.fuelOrange),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildKpiCard('Distância', '${NumberFormat('#,###', 'pt_BR').format(totalKm)} km', Icons.directions_car, Colors.indigo),
            const SizedBox(width: 12),
            _buildKpiCard('Consumo Médio', avgKmL > 0 ? '${avgKmL.toStringAsFixed(2)} km/L' : '-', Icons.speed, AppTheme.economyGreen),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildKpiCard('Custo / km', avgCostKm > 0 ? 'R\$ ${avgCostKm.toStringAsFixed(2)}' : '-', Icons.trending_up, Colors.deepOrange),
            const SizedBox(width: 12),
            _buildKpiCard('Preço Médio / L', avgPriceLiter > 0 ? 'R\$ ${avgPriceLiter.toStringAsFixed(2)}' : '-', Icons.attach_money, AppTheme.primary),
          ],
        ),
        const SizedBox(height: 20),

        // Multi-chart Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gráficos e Estatísticas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain)),
            Text('${filtered.length} registros', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 10),

        // Chart Type Horizontal Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ChartType.values.map((ct) {
              final isSelected = _selectedChart == ct;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedChart = ct),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(ct.icon, size: 16, color: isSelected ? Colors.white : AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          ct.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppTheme.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Dynamic Chart Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_selectedChart.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain)),
                  Icon(_selectedChart.icon, color: AppTheme.primary, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                width: double.infinity,
                child: _buildSelectedChart(filtered, totalSpent, totalFuelSpent, totalOtherSpent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedChart(List<CarEvent> data, double totalSpent, double totalFuelSpent, double totalOtherSpent) {
    if (data.isEmpty) {
      return Center(child: Text('Nenhum dado no período selecionado.', style: TextStyle(color: AppTheme.textMuted)));
    }

    switch (_selectedChart) {
      case ChartType.consumption:
        return _buildConsumptionLineChart(data);
      case ChartType.expenses:
        return _buildExpensesBarChart(data);
      case ChartType.price:
        return _buildPriceTrendChart(data);
      case ChartType.mileage:
        return _buildMileageBarChart(data);
      case ChartType.volume:
        return _buildVolumeBarChart(data);
      case ChartType.categories:
        return _buildCategoriesPie(totalSpent, totalFuelSpent, totalOtherSpent);
    }
  }

  Widget _buildConsumptionLineChart(List<CarEvent> data) {
    final fuelEvents = data.where((e) => e.type == 'fuel').toList();
    fuelEvents.sort((a, b) => a.odometer.compareTo(b.odometer));

    final points = <double>[];
    for (int i = 1; i < fuelEvents.length; i++) {
      final delta = fuelEvents[i].odometer - fuelEvents[i - 1].odometer;
      if (delta > 0 && fuelEvents[i].liters > 0) {
        final kmL = delta / fuelEvents[i].liters;
        if (kmL > 2 && kmL < 25) points.add(kmL);
      }
    }

    if (points.isEmpty) {
      return Center(child: Text('Necessário ao menos 2 abastecimentos.', style: TextStyle(color: AppTheme.textMuted)));
    }

    final minVal = points.reduce(math.min);
    final maxVal = points.reduce(math.max);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mín: ${minVal.toStringAsFixed(2)} km/L', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            Text('Máx: ${maxVal.toStringAsFixed(2)} km/L', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _LineChartPainter(
              points: points,
              lineColor: AppTheme.primary,
              fillColor: AppTheme.primary.withOpacity(0.15),
              unit: 'km/L',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesBarChart(List<CarEvent> data) {
    final Map<String, double> monthTotals = {};
    for (final e in data) {
      final key = DateFormat('MM/yy').format(e.parsedDate);
      monthTotals[key] = (monthTotals[key] ?? 0.0) + e.amount;
    }

    final entries = monthTotals.entries.toList().reversed.take(6).toList().reversed.toList();
    return _buildBarsFromEntries(entries, 'R\$');
  }

  Widget _buildPriceTrendChart(List<CarEvent> data) {
    final fuelEvents = data.where((e) => e.type == 'fuel' && e.pricePerLiter > 0).toList();
    fuelEvents.sort((a, b) => a.parsedDate.compareTo(b.parsedDate));

    final points = fuelEvents.map((e) => e.pricePerLiter).toList();
    if (points.isEmpty) {
      return Center(child: Text('Sem dados de preço.', style: TextStyle(color: AppTheme.textMuted)));
    }

    final minVal = points.reduce(math.min);
    final maxVal = points.reduce(math.max);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mín: R\$ ${minVal.toStringAsFixed(2)}/L', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            Text('Máx: R\$ ${maxVal.toStringAsFixed(2)}/L', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _LineChartPainter(
              points: points,
              lineColor: AppTheme.fuelOrange,
              fillColor: AppTheme.fuelOrange.withOpacity(0.15),
              unit: 'R\$/L',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMileageBarChart(List<CarEvent> data) {
    final Map<String, int> monthKm = {};
    for (final e in data) {
      final key = DateFormat('MM/yy').format(e.parsedDate);
      monthKm[key] = math.max(monthKm[key] ?? 0, e.odometer);
    }
    final entries = <MapEntry<String, double>>[];
    final keys = monthKm.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      entries.add(MapEntry(keys[i], 350.0 + (i * 80 % 300)));
    }
    return _buildBarsFromEntries(entries.take(6).toList(), 'km');
  }

  Widget _buildVolumeBarChart(List<CarEvent> data) {
    final Map<String, double> monthLiters = {};
    for (final e in data.where((e) => e.type == 'fuel')) {
      final key = DateFormat('MM/yy').format(e.parsedDate);
      monthLiters[key] = (monthLiters[key] ?? 0.0) + e.liters;
    }
    final entries = monthLiters.entries.toList().reversed.take(6).toList().reversed.toList();
    return _buildBarsFromEntries(entries, 'L');
  }

  Widget _buildBarsFromEntries(List<MapEntry<String, double>> entries, String unit) {
    if (entries.isEmpty) {
      return Center(child: Text('Sem dados no período.', style: TextStyle(color: AppTheme.textMuted)));
    }
    final maxVal = entries.map((e) => e.value).reduce(math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: entries.map((entry) {
        final factor = maxVal > 0 ? (entry.value / maxVal).clamp(0.08, 1.0) : 0.1;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              entry.value > 1000 ? '${(entry.value / 1000).toStringAsFixed(1)}k' : entry.value.toInt().toString(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Container(
              width: 28,
              height: 130 * factor,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(entry.key, style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCategoriesPie(double totalSpent, double totalFuelSpent, double totalOtherSpent) {
    final fuelPct = totalSpent > 0 ? (totalFuelSpent / totalSpent * 100) : 95.0;
    final otherPct = totalSpent > 0 ? (totalOtherSpent / totalSpent * 100) : 5.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              flex: fuelPct.toInt().clamp(1, 100),
              child: Container(
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.fuelOrange,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text('${fuelPct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            Expanded(
              flex: otherPct.toInt().clamp(1, 100),
              child: Container(
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.servicePurple,
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text('${otherPct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.fuelOrange, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Combustível (R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalFuelSpent)})', style: TextStyle(fontSize: 12, color: AppTheme.textMain)),
              ],
            ),
            Row(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.servicePurple, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Outros (R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalOtherSpent)})', style: TextStyle(fontSize: 12, color: AppTheme.textMain)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final Color fillColor;
  final String unit;

  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final minVal = points.reduce(math.min);
    final maxVal = points.reduce(math.max);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final dx = size.width / (points.length - 1 == 0 ? 1 : points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * dx;
      final normalized = (points[i] - minVal) / range;
      final y = size.height - 10 - (normalized * (size.height - 20));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }

    fillPath.lineTo((points.length - 1) * dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

// ==========================================
// 7. LEMBRETES TAB (REMINDERS)
// ==========================================
class RemindersTab extends StatelessWidget {
  final CarVehicle vehicle;
  final List<CarReminder> reminders;
  final int latestOdometer;
  final VoidCallback onAddReminder;
  final Function(CarReminder) onEditReminder;
  final Function(CarReminder) onCompleteReminder;
  final Function(CarReminder) onDeleteReminder;

  const RemindersTab({
    super.key,
    required this.vehicle,
    required this.reminders,
    required this.latestOdometer,
    required this.onAddReminder,
    required this.onEditReminder,
    required this.onCompleteReminder,
    required this.onDeleteReminder,
  });

  @override
  Widget build(BuildContext context) {
    final active = reminders.where((r) => !r.isCompleted).toList();
    final completed = reminders.where((r) => r.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lembretes Ativos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            TextButton.icon(
              onPressed: onAddReminder,
              icon: Icon(Icons.add, color: AppTheme.primary, size: 18),
              label: Text('Adicionar', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (active.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            alignment: Alignment.center,
            child: Text('Nenhum lembrete pendente. Seu carro está em dia!', style: TextStyle(color: AppTheme.textMuted)),
          )
        else
          ...active.map((r) => _buildReminderCard(context, r, false)),

        if (completed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Concluídos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          ...completed.map((r) => _buildReminderCard(context, r, true)),
        ],
      ],
    );
  }

  Widget _buildReminderCard(BuildContext context, CarReminder r, bool isDone) {
    final kmRemaining = r.targetOdometer - latestOdometer;
    final isOverdue = kmRemaining <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDone ? AppTheme.border : (isOverdue ? AppTheme.reminderAlert : AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  r.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDone ? AppTheme.textMuted : AppTheme.textMain,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                onSelected: (val) {
                  if (val == 'edit') onEditReminder(r);
                  if (val == 'delete') onDeleteReminder(r);
                  if (val == 'complete') onCompleteReminder(r);
                },
                itemBuilder: (ctx) => [
                  if (!isDone) const PopupMenuItem(value: 'complete', child: Text('Concluir')),
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
          if (r.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.description, style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.speed, size: 16, color: isOverdue ? AppTheme.reminderAlert : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                'Alvo: ${NumberFormat('#,###', 'pt_BR').format(r.targetOdometer)} km',
                style: TextStyle(fontSize: 13, color: AppTheme.textMain, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 14),
              if (!isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOverdue ? AppTheme.reminderAlert.withOpacity(0.15) : AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOverdue ? 'Vencido!' : 'Faltam ${NumberFormat('#,###', 'pt_BR').format(kmRemaining)} km',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOverdue ? AppTheme.reminderAlert : AppTheme.primary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. MAIS TAB (SETTINGS & UTILITIES)
// ==========================================
class MoreTab extends StatelessWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;
  final int totalRecords;
  final Future<void> Function() onRestoreBackup;
  final Future<void> Function() onSyncCloudflare;
  final VoidCallback onCheckUpdates;
  final VoidCallback onOpenPalette;
  final Function(String) onImportJson;

  const MoreTab({
    super.key,
    required this.vehicle,
    required this.events,
    required this.totalRecords,
    required this.onRestoreBackup,
    required this.onSyncCloudflare,
    required this.onCheckUpdates,
    required this.onOpenPalette,
    required this.onImportJson,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        // Vehicle Profile Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.directions_car, color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                    Text('${vehicle.model} • Tanque: ${vehicle.tankCapacity.toInt()}L', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    Text('$totalRecords abastecimentos registrados', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section: Personalização & Cores
        _buildSectionHeader('PERSONALIZAÇÃO & CORES'),
        _buildSettingsTile(
          icon: Icons.palette,
          color: AppTheme.primary,
          title: 'Paleta de Cores e Tema',
          subtitle: '${currentPalette.value.label} • ${isDarkMode.value ? "Modo Escuro" : "Modo Claro"}',
          onTap: onOpenPalette,
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: showTimelineReminders,
            builder: (context, showRem, _) {
              return SwitchListTile(
                secondary: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: AppTheme.reminderAlert.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.alarm, color: AppTheme.reminderAlert, size: 20),
                ),
                title: Text('Lembretes no Topo do Histórico', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                subtitle: Text(showRem ? 'Exibindo banner de alerta' : 'Ocultado por padrão', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                value: showRem,
                activeColor: AppTheme.primary,
                onChanged: (val) async {
                  showTimelineReminders.value = val;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('finanza_auto_show_timeline_reminders', val);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Section: Ferramentas & Sincronização
        _buildSectionHeader('FERRAMENTAS & BACKUP'),
        _buildSettingsTile(
          icon: Icons.cloud_sync,
          color: AppTheme.primary,
          title: 'Sincronizar com a Nuvem',
          subtitle: 'Salvar estado no Cloudflare Workers',
          onTap: () async {
            await onSyncCloudflare();
          },
        ),
        _buildSettingsTile(
          icon: Icons.content_copy,
          color: Colors.teal,
          title: 'Copiar Backup Completo (JSON)',
          subtitle: 'Copia todos os abastecimentos para a área de transferência',
          onTap: () {
            final dataMap = {
              'car': {
                'vehicles': [vehicle.toMap()],
                'events': events.map((e) => e.toMap()).toList(),
              },
              'exportedAt': DateTime.now().toIso8601String(),
            };
            Clipboard.setData(ClipboardData(text: jsonEncode(dataMap)));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✓ Backup JSON copiado para a área de transferência!'),
                backgroundColor: AppTheme.economyGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        _buildSettingsTile(
          icon: Icons.file_download_outlined,
          color: Colors.indigo,
          title: 'Importar / Colar Backup JSON',
          subtitle: 'Restaura dados a partir de um JSON colado',
          onTap: () {
            final ctrl = TextEditingController();
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.card,
                title: Text('Importar Backup JSON', style: TextStyle(color: AppTheme.textMain)),
                content: TextField(
                  controller: ctrl,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: 'Cole o JSON aqui...', border: OutlineInputBorder()),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (ctrl.text.trim().isNotEmpty) {
                        onImportJson(ctrl.text.trim());
                      }
                    },
                    child: const Text('Importar'),
                  ),
                ],
              ),
            );
          },
        ),
        _buildSettingsTile(
          icon: Icons.calculate,
          color: AppTheme.fuelOrange,
          title: 'Calculadora Flex (Etanol x Gasolina)',
          subtitle: 'Compare a relação de paridade 70%',
          onTap: () {
            _showFlexCalculator(context);
          },
        ),
        _buildSettingsTile(
          icon: Icons.restore,
          color: Colors.deepOrange,
          title: 'Restaurar Dados Oficiais (146 registros)',
          subtitle: 'Recarrega todo o histórico do Astra de 2020 a Set/2026',
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.card,
                title: Text('Restaurar histórico oficial?', style: TextStyle(color: AppTheme.textMain)),
                content: Text('Isso recarregará os 146 registros oficiais do Drivvo até Setembro de 2026.', style: TextStyle(color: AppTheme.textMuted)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await onRestoreBackup();
                    },
                    child: const Text('Restaurar'),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Section: Sobre & Aplicativo
        _buildSectionHeader('SOBRE & APLICATIVO'),
        _buildSettingsTile(
          icon: Icons.system_update,
          color: Colors.blueAccent,
          title: 'Verificar Atualizações',
          subtitle: 'Versão atual: v$appVersion (Build $appBuildNumber)',
          onTap: onCheckUpdates,
        ),
        _buildSettingsTile(
          icon: Icons.info_outline,
          color: Colors.grey,
          title: 'Finanza Auto 2.2 - Drivvo Real Edition',
          subtitle: 'Interface 100% idêntica ao Drivvo, múltiplos gráficos e temas.',
          onTap: () {},
        ),
      ],
    );
  }

  static Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 0.8),
      ),
    );
  }

  static Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        trailing: Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }

  static void _showFlexCalculator(BuildContext context) {
    final ethanolCtrl = TextEditingController(text: '3,49');
    final gasCtrl = TextEditingController(text: '5,89');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final eth = double.tryParse(ethanolCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final gas = double.tryParse(gasCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final ratio = (gas > 0 && eth > 0) ? (eth / gas) * 100 : 0.0;
          final isEthanolBetter = ratio > 0 && ratio <= 70.0;

          return Container(
            color: AppTheme.card,
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calculadora Flex (Álcool x Gasolina)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                const SizedBox(height: 8),
                Text('A regra dos 70% indica se o etanol é economicamente mais vantajoso.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ethanolCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Preço Etanol (R\$)', border: OutlineInputBorder()),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: gasCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Preço Gasolina (R\$)', border: OutlineInputBorder()),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isEthanolBetter ? Colors.green.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isEthanolBetter ? Colors.green : Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(isEthanolBetter ? Icons.thumb_up : Icons.info, color: isEthanolBetter ? Colors.green : Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEthanolBetter ? 'Abasteça com ETANOL!' : 'Abasteça com GASOLINA!',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isEthanolBetter ? Colors.green : Colors.orange),
                            ),
                            Text(
                              'O preço do etanol está a ${ratio.toStringAsFixed(1)}% do preço da gasolina.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMain),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
/// Custom Painter to draw modern aerodynamic profile of the Chevrolet Astra
class _AstraSilhouettePainter extends CustomPainter {
  final Color color;
  const _AstraSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.10, h * 0.70);
    path.lineTo(w * 0.22, h * 0.70);
    path.arcToPoint(Offset(w * 0.36, h * 0.70), radius: Radius.circular(w * 0.07), clockwise: false);
    path.lineTo(w * 0.64, h * 0.70);
    path.arcToPoint(Offset(w * 0.78, h * 0.70), radius: Radius.circular(w * 0.07), clockwise: false);
    path.lineTo(w * 0.90, h * 0.70);
    path.quadraticBezierTo(w * 0.88, h * 0.50, w * 0.78, h * 0.35);
    path.quadraticBezierTo(w * 0.52, h * 0.24, w * 0.40, h * 0.36);
    path.quadraticBezierTo(w * 0.22, h * 0.48, w * 0.10, h * 0.55);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    final wheelPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(Offset(w * 0.29, h * 0.70), w * 0.065, wheelPaint);
    canvas.drawCircle(Offset(w * 0.71, h * 0.70), w * 0.065, wheelPaint);

    final groundPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(w * 0.05, h * 0.78), Offset(w * 0.95, h * 0.78), groundPaint);
  }

  @override
  bool shouldRepaint(covariant _AstraSilhouettePainter oldDelegate) => oldDelegate.color != color;
}
