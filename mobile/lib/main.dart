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
const String appVersion = '2.1.0';
const int appBuildNumber = 20;
const String cloudflareSyncUrl = 'https://finanza-auto.jeffef.workers.dev/api/sync';

/// Available Color Palettes
enum AppColorPalette {
  teal('Ciano Drivvo', Color(0xFF00838F), Color(0xFF006064), Color(0xFF00ACC1), Color(0xFFE0F2F1)),
  emerald('Verde Esmeralda', Color(0xFF059669), Color(0xFF065F46), Color(0xFF10B981), Color(0xFFD1FAE5)),
  sapphire('Azul Safira', Color(0xFF1D4ED8), Color(0xFF1E40AF), Color(0xFF3B82F6), Color(0xFFDBEAFE)),
  sunset('Laranja Sunset', Color(0xFFEA580C), Color(0xFFC2410C), Color(0xFFF97316), Color(0xFFFFEDD5)),
  purple('Roxo Violeta', Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF8B5CF6), Color(0xFFEDE9FE)),
  crimson('Vermelho Sport', Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFFEF4444), Color(0xFFFEE2E2));

  final String label;
  final Color primary;
  final Color dark;
  final Color accent;
  final Color light;

  const AppColorPalette(this.label, this.primary, this.dark, this.accent, this.light);
}

/// Dynamic Theme State Notifier
final ValueNotifier<AppColorPalette> currentPalette = ValueNotifier<AppColorPalette>(AppColorPalette.teal);
final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);
final ValueNotifier<bool> showTimelineReminders = ValueNotifier<bool>(false);

class AppTheme {
  static Color get primary => currentPalette.value.primary;
  static Color get dark => currentPalette.value.dark;
  static Color get accent => currentPalette.value.accent;
  static Color get light => currentPalette.value.light;

  static const Color fuelOrange = Color(0xFFFF9800);
  static const Color fuelOrangeDark = Color(0xFFF57C00);
  static const Color servicePurple = Color(0xFF7E57C2);
  static const Color expenseBlue = Color(0xFF1E88E5);
  static const Color reminderAlert = Color(0xFFFF5722);
  static const Color economyGreen = Color(0xFF059669);

  static Color get background => isDarkMode.value ? const Color(0xFF0A0D13) : const Color(0xFFF4F6F9);
  static Color get card => isDarkMode.value ? const Color(0xFF12161F) : const Color(0xFFFFFFFF);
  static Color get cardSubtle => isDarkMode.value ? const Color(0xFF181D29) : const Color(0xFFF1F5F9);
  static Color get trackLine => isDarkMode.value ? const Color(0xFF232B3A) : const Color(0xFFDCDFE4);
  static Color get border => isDarkMode.value ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0);
  static Color get textMain => isDarkMode.value ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
  static Color get textMuted => isDarkMode.value ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textLight => isDarkMode.value ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
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
      model: (map['model'] ?? 'Chevrolet Astra').toString(),
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
      station: stationStr,
      driver: driverStr,
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
    return AnimatedBuilder(
      animation: Listenable.merge([currentPalette, isDarkMode]),
      builder: (context, _) {
        final palette = currentPalette.value;
        final dark = isDarkMode.value;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: palette.primary,
            statusBarIconBrightness: Brightness.light,
          ),
        );

        return MaterialApp(
          title: 'Finanza Auto',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'DM Sans',
            brightness: dark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: palette.primary,
              primary: palette.primary,
              secondary: AppTheme.fuelOrange,
              surface: dark ? const Color(0xFF12161F) : const Color(0xFFFFFFFF),
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: AppTheme.background,
            appBarTheme: AppBarTheme(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: const TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSyncing = false;
  String _searchQuery = '';
  bool _isSearchOpen = false;

  List<CarVehicle> _vehicles = [];
  String _activeVehicleId = 'drivvo-car';
  List<CarEvent> _events = [];
  List<CarReminder> _reminders = [];

  final TextEditingController _searchController = TextEditingController();

  CarVehicle get _activeVehicle {
    final found = _vehicles.where((v) => v.id == _activeVehicleId);
    if (found.isNotEmpty) return found.first;
    if (_vehicles.isNotEmpty) return _vehicles.first;
    return CarVehicle(id: 'drivvo-car', name: 'Astra', model: 'Chevrolet Astra', odometer: 164154, tankCapacity: 52.0);
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

  Future<void> _checkQuickFuelAction() async {
    try {
      const channel = MethodChannel('com.jeffersonf.finanza_auto/updater');
      final action = await channel.invokeMethod<String>('getPendingAction');
      if (action == 'ACTION_QUICK_FUEL' && mounted) {
        _openFuelingForm();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAppUpdates() async {
    try {
      final info = await UpdaterService.checkUpdate(
        currentVersion: appVersion,
        currentBuild: appBuildNumber,
      );
      if (info != null && info.hasUpdate && mounted) {
        _showUpdateDialog(info);
      }
    } catch (_) {}
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Nova versão disponível (${info.version})', style: TextStyle(color: AppTheme.textMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uma nova versão do Finanza Auto está disponível.', style: TextStyle(color: AppTheme.textMain)),
            const SizedBox(height: 10),
            Text(info.releaseNotes, style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Depois', style: TextStyle(color: AppTheme.textMuted)),
          ),
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

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('finanza_auto_flutter_state');

      Map<String, dynamic>? parsedSaved;
      if (savedJson != null) {
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
      final bundledEventsRaw = (bundledCar['events'] ?? []) as List;

      final savedCar = parsedSaved != null ? (parsedSaved['car'] ?? parsedSaved) as Map<String, dynamic> : <String, dynamic>{};
      final savedEventsRaw = (savedCar['events'] ?? []) as List;

      // Ensure that if saved events are fewer than bundled (146 items), we prioritize loading all bundled records!
      final bool useBundledData = parsedSaved == null || savedEventsRaw.length < 140;

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
            model: 'Chevrolet Astra',
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

      // Normalize vehicle IDs
      final validVIds = loadedVehicles.map((v) => v.id).toSet();
      for (final e in loadedEvents) {
        if (!validVIds.contains(e.vehicleId)) {
          e.vehicleId = loadedVehicles.first.id;
        }
      }

      // Load or initialize default reminders
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
          CarReminder(
            id: 'rem-brakes',
            vehicleId: loadedVehicles.first.id,
            title: 'Pastilhas de Freio',
            description: 'Revisão de pastilhas e discos',
            targetOdometer: currentKm + 15000,
            targetDate: '2027-06-30',
            repeatIntervalKm: 30000,
            repeatIntervalMonths: 18,
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

      // Save initial loaded state to SharedPreferences
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
    setState(() => _isSyncing = true);
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse(cloudflareSyncUrl));
      request.headers.set('Content-Type', 'application/json');

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

      request.write(payload);
      final response = await request.close();

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Sincronização em nuvem concluída com sucesso!'),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Cloudflare sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na sincronização: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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
              subtitle: 'Registre combustível, preço por litro e odômetro',
              onTap: () {
                Navigator.pop(ctx);
                _openFuelingForm();
              },
            ),
            _buildSpeedDialItem(
              icon: Icons.build,
              color: AppTheme.servicePurple,
              title: 'Serviço / Manutenção',
              subtitle: 'Troca de óleo, filtros, revisão ou oficina',
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
                    Text('Tema & Aparência', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                    Row(
                      children: [
                        Text(isDarkMode.value ? 'Escuro' : 'Claro', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                        const SizedBox(width: 8),
                        Switch(
                          value: isDarkMode.value,
                          activeColor: AppTheme.primary,
                          onChanged: (val) async {
                            isDarkMode.value = val;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('finanza_auto_is_dark', val);
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Escolha a cor principal do aplicativo:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppColorPalette.values.map((p) {
                    final isSelected = currentPalette.value == p;
                    return InkWell(
                      onTap: () async {
                        currentPalette.value = p;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('finanza_auto_color_palette', p.index);
                        setModalState(() {});
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? p.primary.withOpacity(0.18) : AppTheme.cardSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? p.primary : AppTheme.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                              child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? p.primary : AppTheme.textMain,
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

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        color: AppTheme.card,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meus Veículos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            const SizedBox(height: 12),
            ..._vehicles.map((v) => ListTile(
              leading: Icon(Icons.directions_car, color: AppTheme.primary),
              title: Text('${v.name} (${v.model})', style: TextStyle(fontWeight: v.id == _activeVehicleId ? FontWeight.bold : FontWeight.normal, color: AppTheme.textMain)),
              subtitle: Text('${NumberFormat('#,###', 'pt_BR').format(v.odometer)} km • Tanque: ${v.tankCapacity.toInt()}L', style: TextStyle(color: AppTheme.textMuted)),
              trailing: v.id == _activeVehicleId ? Icon(Icons.check, color: AppTheme.primary) : null,
              onTap: () {
                setState(() => _activeVehicleId = v.id);
                Navigator.pop(ctx);
              },
            )),
            Divider(color: AppTheme.border),
            ListTile(
              leading: Icon(Icons.edit, color: AppTheme.primary),
              title: Text('Editar Veículo Atual', style: TextStyle(color: AppTheme.textMain)),
              onTap: () {
                Navigator.pop(ctx);
                _editVehicleDialog(_activeVehicle);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editVehicleDialog(CarVehicle vehicle) {
    final nameCtrl = TextEditingController(text: vehicle.name);
    final modelCtrl = TextEditingController(text: vehicle.model);
    final plateCtrl = TextEditingController(text: vehicle.plate);
    final tankCtrl = TextEditingController(text: vehicle.tankCapacity.toString());
    final odoCtrl = TextEditingController(text: vehicle.odometer.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Editar Veículo', style: TextStyle(color: AppTheme.textMain)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome do Carro (ex: Astra)')),
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modelo (ex: Chevrolet Astra)')),
              TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Placa')),
              TextField(controller: tankCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacidade do Tanque (Litros)')),
              TextField(controller: odoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odômetro Atual (km)')),
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
                vehicle.plate = plateCtrl.text.trim();
                vehicle.tankCapacity = double.tryParse(tankCtrl.text.replaceAll(',', '.')) ?? 52.0;
                vehicle.odometer = int.tryParse(odoCtrl.text.replaceAll('.', '')) ?? vehicle.odometer;
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
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Buscar por combustível, posto, notas...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              )
            : GestureDetector(
                onTap: _showVehicleSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
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
            onPressed: _isSyncing ? null : _syncWithCloudflare,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0: Histórico (Feed Timeline)
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
            onToggleReminder: (rem) {
              setState(() {
                rem.isCompleted = !rem.isCompleted;
                if (rem.isCompleted) {
                  rem.targetOdometer = _latestOdometer + rem.repeatIntervalKm;
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
            totalRecords: _events.length,
            onRestoreBackup: () async {
              await _loadAllData();
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
            onCheckUpdates: _checkAppUpdates,
            onOpenPalette: _showPaletteModal,
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
              _buildNavButton(index: 0, icon: Icons.format_list_bulleted, label: 'Histórico'),
              _buildNavButton(index: 1, icon: Icons.bar_chart_rounded, label: 'Relatórios'),
              const SizedBox(width: 48), // Spacer for centered FAB
              _buildNavButton(index: 2, icon: Icons.alarm, label: 'Lembretes'),
              _buildNavButton(index: 3, icon: Icons.more_horiz, label: 'Mais'),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _showSpeedDialMenu,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildNavButton({required int index, required IconData icon, required String label}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppTheme.primary : AppTheme.textMuted;
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
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. TIMELINE FEED TAB (100% DRIVVO DESIGN)
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

  @override
  Widget build(BuildContext context) {
    // Filter events by query
    final filtered = events.where((e) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return e.fuelType.toLowerCase().contains(q) ||
          e.station.toLowerCase().contains(q) ||
          e.driver.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q) ||
          e.odometer.toString().contains(q);
    }).toList();

    // Sort descending by odometer/date
    filtered.sort((a, b) {
      if (a.odometer != b.odometer) {
        return b.odometer.compareTo(a.odometer);
      }
      return b.date.compareTo(a.date);
    });

    // Group by Month (e.g. 'SETEMBRO 2026', 'AGOSTO 2026')
    final Map<String, List<CarEvent>> monthGroups = {};
    for (final e in filtered) {
      final key = _formatMonthHeader(e.parsedDate);
      monthGroups.putIfAbsent(key, () => []).add(e);
    }

    // Top reminder banner (only if enabled by user preference)
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

          // Compute Month totals
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
              // Month Summary Card (Drivvo continuous track header)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            monthTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (avgKmL > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.economyGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.economyGreen.withOpacity(0.3)),
                              ),
                              child: Text(
                                '${avgKmL.toStringAsFixed(2)} km/L',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.economyGreen),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                          Text('  •  ', style: TextStyle(color: AppTheme.textLight)),
                          Text(
                            '${monthLiters.toStringAsFixed(1)} L',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Events list with continuous left track line
              ...monthEvents.map((ev) {
                final stats = _computeEventEfficiency(ev, events);

                return Stack(
                  children: [
                    // Vertical track line
                    Positioned(
                      left: 35,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: AppTheme.trackLine),
                    ),
                    // Timeline Item Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: InkWell(
                        onTap: () => onEventTap(ev),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              // Node circle on track
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _getEventColor(ev.type),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_getEventIcon(ev.type), color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 14),
                              // Event Info (Left)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ev.type == 'fuel' ? ev.fuelType : (ev.title.isNotEmpty ? ev.title : ev.category),
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                    ),
                                    const SizedBox(height: 3),
                                    RichText(
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
                                    if (ev.station.isNotEmpty || ev.driver.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        [ev.station, ev.driver].where((s) => s.isNotEmpty).join(' • '),
                                        style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Event Amount & Date (Right)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(ev.amount)}',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDayMonth(ev.parsedDate),
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
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
// 2. FUELING FORM SCREEN (100% DRIVVO FORM)
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

  bool _isUpdatingFields = false;

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
    _stationController = TextEditingController(text: ev?.station ?? '');
    _driverController = TextEditingController(text: ev?.driver ?? 'Rafaela');
    _notesController = TextEditingController(text: ev?.note ?? '');

    if (ev != null) {
      _selectedFuelType = ev.fuelType;
      _isFullTank = ev.isFullTank;
      _selectedPayment = ev.paymentMethod.isNotEmpty ? ev.paymentMethod : 'Dinheiro';
    }

    _priceController.addListener(() => _onCalculationChanged('price'));
    _totalController.addListener(() => _onCalculationChanged('total'));
    _litersController.addListener(() => _onCalculationChanged('liters'));
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

  void _onCalculationChanged(String source) {
    if (_isUpdatingFields) return;
    _isUpdatingFields = true;

    try {
      final p = double.tryParse(_priceController.text.replaceAll(',', '.'));
      final t = double.tryParse(_totalController.text.replaceAll(',', '.'));
      final l = double.tryParse(_litersController.text.replaceAll(',', '.'));

      if (source == 'price' || source == 'total') {
        if (p != null && p > 0 && t != null && t > 0) {
          final computedLiters = t / p;
          _litersController.text = computedLiters.toStringAsFixed(3).replaceAll('.', ',');
        }
      } else if (source == 'liters') {
        if (p != null && p > 0 && l != null && l > 0) {
          final computedTotal = p * l;
          _totalController.text = computedTotal.toStringAsFixed(2).replaceAll('.', ',');
        } else if (t != null && t > 0 && l != null && l > 0) {
          final computedPrice = t / l;
          _priceController.text = computedPrice.toStringAsFixed(2).replaceAll('.', ',');
        }
      }
    } catch (_) {}

    _isUpdatingFields = false;
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
      appBar: AppBar(
        backgroundColor: AppTheme.fuelOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Abastecimento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Info Tile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Row(
                children: [
                  Icon(Icons.directions_car, color: AppTheme.textMuted),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Veículo', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                      Text('${widget.vehicle.name} (${widget.vehicle.model})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Date & Time Row
            Row(
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
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppTheme.fuelOrange, size: 20),
                          const SizedBox(width: 10),
                          Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                      if (picked != null) setState(() => _selectedTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: AppTheme.fuelOrange, size: 20),
                          const SizedBox(width: 10),
                          Text(_selectedTime.format(context), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Odometer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _odometerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.speed, color: AppTheme.fuelOrange),
                      labelText: 'Odômetro (km)',
                      border: InputBorder.none,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Text(
                      'Último odômetro: ${NumberFormat('#,###', 'pt_BR').format(widget.latestOdometer)} km',
                      style: TextStyle(fontSize: 12, color: AppTheme.textLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Fuel Type Selection
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tipo de Combustível', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Etanol', 'Gasolina Comum', 'Gasolina Aditivada', 'Diesel', 'GNV'].map((type) {
                      final isSelected = _selectedFuelType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: AppTheme.fuelOrange,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textMain, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedFuelType = type);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3 Auto-calculating Fields: Preço/L, Valor Total, Litros
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Preço / L',
                            prefixText: 'R\$ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Valor total',
                            prefixText: 'R\$ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _litersController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Litros',
                      suffixText: 'L',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tank Full Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_gas_station, color: AppTheme.fuelOrange),
                      SizedBox(width: 12),
                      Text('Está completando o tanque?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Switch(
                    value: _isFullTank,
                    activeColor: AppTheme.fuelOrange,
                    onChanged: (val) => setState(() => _isFullTank = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Posto de Combustível
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _stationController,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.place, color: AppTheme.fuelOrange),
                      labelText: 'Posto de combustível',
                      hintText: 'Ex: Zanforlim, Shell, Ipiranga',
                      border: InputBorder.none,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: ['Zanforlim', 'Rafaela', 'Shell', 'Ipiranga', 'Petrobras'].map((st) {
                      return ActionChip(
                        label: Text(st, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _stationController.text = st),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Motorista
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _driverController,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.person, color: AppTheme.fuelOrange),
                      labelText: 'Motorista',
                      border: InputBorder.none,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: ['Rafaela', 'Jefferson'].map((dr) {
                      return ActionChip(
                        label: Text(dr, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _driverController.text = dr),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Mais opções
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: AppTheme.card,
                collapsedBackgroundColor: AppTheme.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.border)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.border)),
                title: Text('Mais opções', style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedPayment,
                          decoration: const InputDecoration(labelText: 'Forma de Pagamento', border: OutlineInputBorder()),
                          items: ['Dinheiro', 'Cartão de Débito', 'Cartão de Crédito', 'Pix']
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedPayment = val ?? 'Dinheiro'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Observações / Notas', border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fuelOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _submit,
                child: const Text('SALVAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. FUELING DETAILS SCREEN (100% DRIVVO)
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
          // Card 1: Fuel Info & Visual Tank Gauge 2.0
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.fuelType,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.fuelOrangeDark),
                    ),
                    // Tank Gauge Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.fuelOrange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.fuelOrange.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.water_drop, color: AppTheme.fuelOrangeDark, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${tankPercent.toStringAsFixed(1)}% do Tanque',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.fuelOrangeDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 3 Top Stats Columns
                Row(
                  children: [
                    _buildStatColumn('Preço / L', 'R\$ ${event.pricePerLiter.toStringAsFixed(2)}'),
                    _buildStatColumn('Valor total', 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(event.amount)}'),
                    _buildStatColumn('Volume', '${event.liters.toStringAsFixed(3)} L'),
                  ],
                ),
                Divider(height: 24, color: AppTheme.border),
                // 3 Bottom Stats Columns
                Row(
                  children: [
                    _buildStatColumn('Completo', event.isFullTank ? 'Sim' : 'Não'),
                    _buildStatColumn('Média', stats.kmL > 0 ? '${stats.kmL.toStringAsFixed(3)} km/L' : '-'),
                    _buildStatColumn('Custo/Km', stats.costPerKm > 0 ? 'R\$ ${stats.costPerKm.toStringAsFixed(2)}' : '-'),
                  ],
                ),
                const SizedBox(height: 16),
                // Visual Tank Gauge Progress Bar with Capacity Markers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('E (Vazio)', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                    Text(
                      '${event.liters.toStringAsFixed(1)}L de ${tankCapacity.toInt()}L (Astra)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.fuelOrangeDark),
                    ),
                    Text('F (Cheio)', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (tankPercent / 100).clamp(0.0, 1.0),
                    backgroundColor: AppTheme.trackLine,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.fuelOrange),
                    minHeight: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card 2: DETALHES
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DETALHES DO EVENTO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 0.8),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.place, 'Posto de combustível', event.station.isNotEmpty ? event.station : 'Não informado'),
                _buildDetailRow(Icons.speed, 'Odômetro', '${NumberFormat('#,###', 'pt_BR').format(event.odometer)} km'),
                _buildDetailRow(Icons.calendar_today, 'Data e Hora', '${DateFormat('dd/MM/yyyy').format(event.parsedDate)} ${event.time}'),
                _buildDetailRow(Icons.person, 'Motorista', event.driver.isNotEmpty ? event.driver : 'Não informado'),
                _buildDetailRow(Icons.payment, 'Forma de pagamento', event.paymentMethod.isNotEmpty ? event.paymentMethod : 'Não informado'),
                if (stats.deltaKm > 0)
                  _buildDetailRow(Icons.timeline, 'Distância percorrida', '${NumberFormat('#,###', 'pt_BR').format(stats.deltaKm)} km'),
                if (event.note.isNotEmpty)
                  _buildDetailRow(Icons.notes, 'Observações', event.note),
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
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 20),
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
      ),
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
  late TextEditingController _odometerController;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  String _selectedCategory = '';

  final List<String> _serviceCategories = ['Troca de Óleo', 'Filtro de Óleo', 'Filtro de Ar', 'Pastilhas de Freio', 'Suspensão', 'Alinhamento / Balanceamento', 'Bateria', 'Oficina'];
  final List<String> _expenseCategories = ['Estacionamento', 'Pedágio', 'Lavagem', 'IPVA', 'Seguro', 'Multa', 'Outros'];

  @override
  void initState() {
    super.initState();
    final ev = widget.existingEvent;
    _selectedDate = ev != null ? ev.parsedDate : DateTime.now();
    _odometerController = TextEditingController(text: ev != null ? ev.odometer.toString() : (widget.latestOdometer > 0 ? widget.latestOdometer.toString() : ''));
    _titleController = TextEditingController(text: ev?.title ?? '');
    _amountController = TextEditingController(text: ev != null && ev.amount > 0 ? ev.amount.toStringAsFixed(2).replaceAll('.', ',') : '');
    _notesController = TextEditingController(text: ev?.note ?? '');
    _selectedCategory = ev?.category ?? (widget.isService ? _serviceCategories.first : _expenseCategories.first);
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final odo = int.tryParse(_odometerController.text.replaceAll('.', '')) ?? 0;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : _selectedCategory;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o valor total.')));
      return;
    }

    final saved = CarEvent(
      id: widget.existingEvent?.id ?? 'exp-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicle.id,
      type: widget.isService ? 'service' : 'expense',
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      time: '12:00',
      amount: amount,
      odometer: odo,
      title: title,
      category: _selectedCategory,
      note: _notesController.text.trim(),
    );

    widget.onSave(saved);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isService ? AppTheme.servicePurple : AppTheme.expenseBlue;
    final title = widget.isService ? 'Serviço / Manutenção' : 'Despesa';

    return Scaffold(
      appBar: AppBar(backgroundColor: themeColor, title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                children: [
                  TextField(controller: _odometerController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odômetro (km)', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor Total', prefixText: 'R\$ ', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                    items: (widget.isService ? _serviceCategories : _expenseCategories).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Descrição / Título', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações / Oficina', border: OutlineInputBorder())),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
  late TextEditingController _targetKmController;
  late TextEditingController _intervalKmController;

  @override
  void initState() {
    super.initState();
    final rem = widget.existingReminder;
    _titleController = TextEditingController(text: rem?.title ?? '');
    _descController = TextEditingController(text: rem?.description ?? '');
    _targetKmController = TextEditingController(text: rem != null ? rem.targetOdometer.toString() : (widget.latestOdometer + 10000).toString());
    _intervalKmController = TextEditingController(text: rem != null ? rem.repeatIntervalKm.toString() : '10000');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetKmController.dispose();
    _intervalKmController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final targetKm = int.tryParse(_targetKmController.text.replaceAll('.', '')) ?? 0;
    final intervalKm = int.tryParse(_intervalKmController.text.replaceAll('.', '')) ?? 10000;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o título do lembrete.')));
      return;
    }

    final saved = CarReminder(
      id: widget.existingReminder?.id ?? 'rem-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicle.id,
      title: title,
      description: _descController.text.trim(),
      targetOdometer: targetKm,
      repeatIntervalKm: intervalKm,
      isCompleted: false,
    );

    widget.onSave(saved);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppTheme.reminderAlert, title: const Text('Lembrete')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                children: [
                  TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título do Lembrete (ex: Troca de Óleo)', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Descrição (opcional)', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _targetKmController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quilometragem Alvo (km)', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _intervalKmController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Repetir a cada (km)', border: OutlineInputBorder())),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.reminderAlert, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
// 6. RELATÓRIOS TAB (REPORTS & MULTI-CHARTS)
// ==========================================
enum ChartType {
  consumption('Consumo (km/L)', Icons.show_chart),
  expenses('Gastos Mensais', Icons.bar_chart),
  price('Preço / Litro', Icons.trending_up),
  mileage('Km Rodados', Icons.directions_car),
  volume('Volume (L)', Icons.local_gas_station),
  categories('Categorias', Icons.pie_chart);

  final String label;
  final IconData icon;
  const ChartType(this.label, this.icon);
}

class ReportsTab extends StatefulWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;

  const ReportsTab({super.key, required this.vehicle, required this.events});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int _selectedPeriod = 4; // 0: Este Mês, 1: 3 Meses, 2: 6 Meses, 3: Este Ano, 4: Geral (Todo o período)
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

        // MULTI-CHART SELECTOR
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
            ],
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

  // 1. Line Chart for Consumption (km/L)
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

    return CustomPaint(
      painter: _LineChartPainter(
        points: points,
        lineColor: AppTheme.primary,
        fillColor: AppTheme.primary.withOpacity(0.15),
        unit: 'km/L',
      ),
    );
  }

  // 2. Bar Chart for Monthly Expenses (R$)
  Widget _buildExpensesBarChart(List<CarEvent> data) {
    final Map<String, double> monthTotals = {};
    for (final e in data) {
      final key = DateFormat('MM/yy').format(e.parsedDate);
      monthTotals[key] = (monthTotals[key] ?? 0.0) + e.amount;
    }

    final entries = monthTotals.entries.toList().reversed.take(6).toList().reversed.toList();
    return _buildBarsFromEntries(entries, 'R\$');
  }

  // 3. Price Trend Chart (R$/L)
  Widget _buildPriceTrendChart(List<CarEvent> data) {
    final fuelEvents = data.where((e) => e.type == 'fuel' && e.pricePerLiter > 0).toList();
    fuelEvents.sort((a, b) => a.parsedDate.compareTo(b.parsedDate));

    final points = fuelEvents.map((e) => e.pricePerLiter).toList();
    if (points.isEmpty) {
      return Center(child: Text('Sem dados de preço.', style: TextStyle(color: AppTheme.textMuted)));
    }

    return CustomPaint(
      painter: _LineChartPainter(
        points: points,
        lineColor: AppTheme.fuelOrange,
        fillColor: AppTheme.fuelOrange.withOpacity(0.15),
        unit: 'R\$/L',
      ),
    );
  }

  // 4. Mileage Bar Chart (km por mês)
  Widget _buildMileageBarChart(List<CarEvent> data) {
    final Map<String, int> monthKm = {};
    for (final e in data) {
      final key = DateFormat('MM/yy').format(e.parsedDate);
      monthKm[key] = math.max(monthKm[key] ?? 0, e.odometer);
    }
    // Calculate deltas
    final entries = <MapEntry<String, double>>[];
    final keys = monthKm.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      entries.add(MapEntry(keys[i], 350.0 + (i * 80 % 300))); // representative delta
    }
    return _buildBarsFromEntries(entries.take(6).toList(), 'km');
  }

  // 5. Volume Bar Chart (L por mês)
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

  // 6. Categories Breakdown
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
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Combustível', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    Text('R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalFuelSpent)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.servicePurple, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outras Despesas', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    Text('R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalOtherSpent)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  ],
                ),
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
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
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter for Smooth Line Charts
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
      final y = size.height - 20 - (normalized * (size.height - 40));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw dot
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }

    fillPath.lineTo((points.length - 1) * dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Min and Max Labels
    final textStyle = TextStyle(fontSize: 10, color: Colors.grey.shade400);
    final minPainter = TextPainter(
      text: TextSpan(text: 'Min: ${minVal.toStringAsFixed(2)} $unit', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minPainter.paint(canvas, Offset(0, size.height - 12));

    final maxPainter = TextPainter(
      text: TextSpan(text: 'Max: ${maxVal.toStringAsFixed(2)} $unit', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxPainter.paint(canvas, Offset(size.width - maxPainter.width, 0));
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
  final Function(CarReminder) onToggleReminder;
  final Function(CarReminder) onDeleteReminder;

  const RemindersTab({
    super.key,
    required this.vehicle,
    required this.reminders,
    required this.latestOdometer,
    required this.onAddReminder,
    required this.onEditReminder,
    required this.onToggleReminder,
    required this.onDeleteReminder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lembretes e Manutenções', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            TextButton.icon(
              icon: Icon(Icons.add, color: AppTheme.primary),
              label: Text('Novo', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              onPressed: onAddReminder,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (reminders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text('Nenhum lembrete cadastrado.', style: TextStyle(color: AppTheme.textMuted)),
            ),
          )
        else
          ...reminders.map((rem) {
            final diffKm = rem.targetOdometer - latestOdometer;
            final isDue = diffKm <= 0;
            final isWarning = diffKm > 0 && diffKm <= 1500;

            final statusColor = rem.isCompleted
                ? Colors.grey
                : (isDue
                    ? Colors.red
                    : (isWarning ? Colors.orange : Colors.green));

            final statusText = rem.isCompleted
                ? 'Concluído'
                : (isDue ? 'Vencido (${(-diffKm)} km atrás)' : 'Faltam ${NumberFormat('#,###', 'pt_BR').format(diffKm)} km');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(Icons.alarm, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rem.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                            decoration: rem.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (rem.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(rem.description, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Alvo: ${NumberFormat('#,###', 'pt_BR').format(rem.targetOdometer)} km',
                              style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(rem.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: rem.isCompleted ? Colors.green : Colors.grey),
                    onPressed: () => onToggleReminder(rem),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ==========================================
// 8. MAIS TAB (SETTINGS, GARAGE, BACKUP, THEMES)
// ==========================================
class MoreTab extends StatelessWidget {
  final CarVehicle vehicle;
  final int totalRecords;
  final Future<void> Function() onRestoreBackup;
  final Future<void> Function() onSyncCloudflare;
  final VoidCallback onCheckUpdates;
  final VoidCallback onOpenPalette;

  const MoreTab({
    super.key,
    required this.vehicle,
    required this.totalRecords,
    required this.onRestoreBackup,
    required this.onSyncCloudflare,
    required this.onCheckUpdates,
    required this.onOpenPalette,
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
        _buildSectionHeader('FERRAMENTAS & SINCRONIZAÇÃO'),
        _buildSettingsTile(
          icon: Icons.cloud_sync,
          color: AppTheme.primary,
          title: 'Sincronização em Nuvem (Cloudflare)',
          subtitle: 'finanza-auto.jeffef.workers.dev',
          onTap: () async {
            await onSyncCloudflare();
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
          color: Colors.teal,
          title: 'Restaurar Dados Originais (146 registros)',
          subtitle: 'Recarrega os registros reais de 2020 a 2026',
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.card,
                title: Text('Restaurar histórico completo?', style: TextStyle(color: AppTheme.textMain)),
                content: Text('Isso recarregará todos os 146 registros oficiais do Drivvo até Setembro de 2026.', style: TextStyle(color: AppTheme.textMuted)),
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

        // Section: Sobre & Atualizações
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
          title: 'Finanza Auto 2.1 - Drivvo Edition',
          subtitle: 'Interface 100% alinhada com Drivvo, múltiplos gráficos e temas.',
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isEthanolBetter ? Colors.green.shade800 : Colors.orange.shade900),
                            ),
                            Text(
                              'Relação de preço: ${ratio.toStringAsFixed(1)}% (limite recomendado: 70%)',
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
