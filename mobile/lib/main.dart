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
const String appVersion = '2.0.0';
const int appBuildNumber = 19;
const String cloudflareSyncUrl = 'https://finanza-auto.jeffef.workers.dev/api/sync';

/// Drivvo Color Palette & Design Tokens
class DrivvoColors {
  static const Color primaryTeal = Color(0xFF00838F);
  static const Color darkTeal = Color(0xFF006064);
  static const Color lightTeal = Color(0xFFE0F2F1);
  static const Color accentTeal = Color(0xFF00ACC1);

  static const Color fuelOrange = Color(0xFFFF9800);
  static const Color fuelOrangeDark = Color(0xFFF57C00);
  static const Color fuelOrangeLight = Color(0xFFFFF3E0);

  static const Color servicePurple = Color(0xFF7E57C2);
  static const Color servicePurpleLight = Color(0xFFEDE7F6);

  static const Color expenseBlue = Color(0xFF1E88E5);
  static const Color expenseBlueLight = Color(0xFFE3F2FD);

  static const Color reminderAlert = Color(0xFFFF5722);
  static const Color reminderAlertBg = Color(0xFFFFF8E1);

  static const Color backgroundLight = Color(0xFFF4F6F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color trackLine = Color(0xFFDCDFE4);
  static const Color textDark = Color(0xFF212529);
  static const Color textMuted = Color(0xFF757575);
  static const Color textLight = Color(0xFF9E9E9E);
  static const Color divider = Color(0xFFE0E0E0);
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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: DrivvoColors.primaryTeal,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const DrivvoApp());
}

class DrivvoApp extends StatelessWidget {
  const DrivvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finanza Auto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'DM Sans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: DrivvoColors.primaryTeal,
          primary: DrivvoColors.primaryTeal,
          secondary: DrivvoColors.fuelOrange,
          surface: DrivvoColors.backgroundLight,
        ),
        scaffoldBackgroundColor: DrivvoColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: DrivvoColors.primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      home: const MainNavigationScreen(),
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
        title: Text('Nova versão disponível (${info.version})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Uma nova versão do Finanza Auto está disponível.'),
            const SizedBox(height: 10),
            Text(info.releaseNotes, style: const TextStyle(fontSize: 13, color: DrivvoColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Depois'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DrivvoColors.primaryTeal, foregroundColor: Colors.white),
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
            const SnackBar(
              content: Text('Sincronização em nuvem concluída com sucesso!'),
              backgroundColor: DrivvoColors.primaryTeal,
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
      // Update vehicle odometer if higher
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                decoration: const BoxDecoration(
                  color: DrivvoColors.divider,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Adicionar novo registro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DrivvoColors.textDark),
            ),
            const SizedBox(height: 16),
            _buildSpeedDialItem(
              icon: Icons.local_gas_station,
              color: DrivvoColors.fuelOrange,
              title: 'Abastecimento',
              subtitle: 'Registre combustível, preço por litro e odômetro',
              onTap: () {
                Navigator.pop(ctx);
                _openFuelingForm();
              },
            ),
            _buildSpeedDialItem(
              icon: Icons.build,
              color: DrivvoColors.servicePurple,
              title: 'Serviço / Manutenção',
              subtitle: 'Troca de óleo, filtros, revisão ou oficina',
              onTap: () {
                Navigator.pop(ctx);
                _openServiceExpenseForm(isService: true);
              },
            ),
            _buildSpeedDialItem(
              icon: Icons.receipt_long,
              color: DrivvoColors.expenseBlue,
              title: 'Despesa',
              subtitle: 'Estacionamento, pedágio, lavagem ou seguro',
              onTap: () {
                Navigator.pop(ctx);
                _openServiceExpenseForm(isService: false);
              },
            ),
            _buildSpeedDialItem(
              icon: Icons.alarm,
              color: DrivvoColors.reminderAlert,
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: DrivvoColors.textMuted)),
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

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meus Veículos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._vehicles.map((v) => ListTile(
              leading: const Icon(Icons.directions_car, color: DrivvoColors.primaryTeal),
              title: Text('${v.name} (${v.model})', style: TextStyle(fontWeight: v.id == _activeVehicleId ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('${NumberFormat('#,###', 'pt_BR').format(v.odometer)} km • Tanque: ${v.tankCapacity.toInt()}L'),
              trailing: v.id == _activeVehicleId ? const Icon(Icons.check, color: DrivvoColors.primaryTeal) : null,
              onTap: () {
                setState(() => _activeVehicleId = v.id);
                Navigator.pop(ctx);
              },
            )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit, color: DrivvoColors.primaryTeal),
              title: const Text('Editar Veículo Atual'),
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
        title: const Text('Editar Veículo'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DrivvoColors.primaryTeal, foregroundColor: Colors.white),
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: DrivvoColors.primaryTeal),
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
          // 1: Relatórios
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
                  const SnackBar(
                    content: Text('146 abastecimentos reais restaurados com sucesso!'),
                    backgroundColor: DrivvoColors.primaryTeal,
                  ),
                );
              }
            },
            onSyncCloudflare: _syncWithCloudflare,
            onCheckUpdates: _checkAppUpdates,
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        color: Colors.white,
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
        backgroundColor: DrivvoColors.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildNavButton({required int index, required IconData icon, required String label}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? DrivvoColors.primaryTeal : DrivvoColors.textMuted;
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

    // Top reminder banner
    CarReminder? urgentReminder;
    for (final r in reminders) {
      if (!r.isCompleted) {
        urgentReminder = r;
        break;
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
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DrivvoColors.reminderAlertBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE082)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: DrivvoColors.reminderAlert, shape: BoxShape.circle),
                      child: const Icon(Icons.alarm, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LEMBRETES',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DrivvoColors.reminderAlert, letterSpacing: 0.8),
                          ),
                          Text(
                            urgentReminder.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DrivvoColors.textDark),
                          ),
                          Text(
                            'Faltam ${NumberFormat('#,###', 'pt_BR').format(math.max(0, urgentReminder.targetOdometer - vehicle.odometer))} km',
                            style: const TextStyle(fontSize: 12, color: DrivvoColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: DrivvoColors.textMuted),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DrivvoColors.divider),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF37474F),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'R$ ${NumberFormat('#,##0.00', 'pt_BR').format(monthAmount)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DrivvoColors.textDark),
                          ),
                          const Text('  •  ', style: TextStyle(color: DrivvoColors.textLight)),
                          Text(
                            '$monthKm km',
                            style: const TextStyle(fontSize: 13, color: DrivvoColors.textDark),
                          ),
                          if (avgKmL > 0) ...[
                            const Text('  •  ', style: TextStyle(color: DrivvoColors.textLight)),
                            Text(
                              '${avgKmL.toStringAsFixed(3)} km/L',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DrivvoColors.textDark),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Events list with continuous left track line
              ...monthEvents.map((ev) {
                // Calculate km/L and delta km for this event
                final stats = _computeEventEfficiency(ev, events);

                return Stack(
                  children: [
                    // Vertical track line
                    Positioned(
                      left: 35,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: DrivvoColors.trackLine),
                    ),
                    // Timeline Item Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: InkWell(
                        onTap: () => onEventTap(ev),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DrivvoColors.divider.withOpacity(0.6)),
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
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DrivvoColors.textDark),
                                    ),
                                    const SizedBox(height: 3),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 12, color: DrivvoColors.textMuted, fontFamily: 'DM Sans'),
                                        children: [
                                          TextSpan(text: '${NumberFormat('#,###', 'pt_BR').format(ev.odometer)} km  •  '),
                                          if (stats.kmL > 0) ...[
                                            TextSpan(
                                              text: '${stats.kmL.toStringAsFixed(3)} km/L',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: DrivvoColors.textDark),
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
                                        style: const TextStyle(fontSize: 11, color: DrivvoColors.textLight),
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
                                    'R$ ${NumberFormat('#,##0.00', 'pt_BR').format(ev.amount)}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DrivvoColors.textDark),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDayMonth(ev.parsedDate),
                                    style: const TextStyle(fontSize: 12, color: DrivvoColors.textMuted),
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
        return DrivvoColors.fuelOrange;
      case 'service':
        return DrivvoColors.servicePurple;
      case 'expense':
      default:
        return DrivvoColors.expenseBlue;
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

    // Find previous fueling with lower odometer
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
        backgroundColor: DrivvoColors.fuelOrange,
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: DrivvoColors.textMuted),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Veículo', style: TextStyle(fontSize: 11, color: DrivvoColors.textLight)),
                      Text('${widget.vehicle.name} (${widget.vehicle.model})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: DrivvoColors.fuelOrange, size: 20),
                          const SizedBox(width: 10),
                          Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: DrivvoColors.fuelOrange, size: 20),
                          const SizedBox(width: 10),
                          Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _odometerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.speed, color: DrivvoColors.fuelOrange),
                      labelText: 'Odômetro (km)',
                      border: InputBorder.none,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Text(
                      'Último odômetro: ${NumberFormat('#,###', 'pt_BR').format(widget.latestOdometer)} km',
                      style: const TextStyle(fontSize: 12, color: DrivvoColors.textLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Fuel Type Selection
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo de Combustível', style: TextStyle(fontSize: 12, color: DrivvoColors.textLight)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Etanol', 'Gasolina Comum', 'Gasolina Aditivada', 'Diesel', 'GNV'].map((type) {
                      final isSelected = _selectedFuelType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: DrivvoColors.fuelOrange,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : DrivvoColors.textDark, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
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
                            prefixText: 'R$ ',
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
                            prefixText: 'R$ ',
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_gas_station, color: DrivvoColors.fuelOrange),
                      SizedBox(width: 12),
                      Text('Está completando o tanque?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Switch(
                    value: _isFullTank,
                    activeColor: DrivvoColors.fuelOrange,
                    onChanged: (val) => setState(() => _isFullTank = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Posto de Combustível
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _stationController,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.place, color: DrivvoColors.fuelOrange),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _driverController,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.person, color: DrivvoColors.fuelOrange),
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
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                title: const Text('Mais opções', style: TextStyle(fontSize: 14, color: DrivvoColors.textMuted)),
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
                  backgroundColor: DrivvoColors.fuelOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    // Compute efficiency metrics
    final stats = TimelineFeedTab._computeEventEfficiency(event, allEvents);
    final tankCapacity = vehicle.tankCapacity > 0 ? vehicle.tankCapacity : 52.0;
    final tankPercent = (event.liters / tankCapacity * 100).clamp(0, 100).toInt();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: DrivvoColors.fuelOrange,
        title: const Text('Abastecimento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Excluir abastecimento?'),
                  content: const Text('Esta ação removerá este abastecimento do histórico.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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
          // Card 1: Fuel Info & Visual Tank Gauge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DrivvoColors.divider),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DrivvoColors.fuelOrangeDark),
                    ),
                    // Tank Graphic Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: DrivvoColors.fuelOrangeLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DrivvoColors.fuelOrange.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.water_drop, color: DrivvoColors.fuelOrangeDark, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$tankPercent% do Tanque',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DrivvoColors.fuelOrangeDark),
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
                    _buildStatColumn('Preço / L', 'R$ ${event.pricePerLiter.toStringAsFixed(2)}'),
                    _buildStatColumn('Valor total', 'R$ ${NumberFormat('#,##0.00', 'pt_BR').format(event.amount)}'),
                    _buildStatColumn('Volume', '${event.liters.toStringAsFixed(3)} L'),
                  ],
                ),
                const Divider(height: 24),
                // 3 Bottom Stats Columns
                Row(
                  children: [
                    _buildStatColumn('Completo', event.isFullTank ? 'Sim' : 'Não'),
                    _buildStatColumn('Média', stats.kmL > 0 ? '${stats.kmL.toStringAsFixed(3)} km/L' : '-'),
                    _buildStatColumn('Custo/Km', stats.costPerKm > 0 ? 'R$ ${stats.costPerKm.toStringAsFixed(2)}' : '-'),
                  ],
                ),
                const SizedBox(height: 12),
                // Visual Tank Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: tankPercent / 100,
                    backgroundColor: DrivvoColors.trackLine,
                    valueColor: const AlwaysStoppedAnimation<Color>(DrivvoColors.fuelOrange),
                    minHeight: 8,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DrivvoColors.divider),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DETALHES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DrivvoColors.textLight, letterSpacing: 0.8),
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
          Text(label, style: const TextStyle(fontSize: 12, color: DrivvoColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DrivvoColors.textDark)),
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
          Icon(icon, color: DrivvoColors.textMuted, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: DrivvoColors.textLight)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DrivvoColors.textDark)),
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
    final themeColor = widget.isService ? DrivvoColors.servicePurple : DrivvoColors.expenseBlue;
    final title = widget.isService ? 'Serviço / Manutenção' : 'Despesa';

    return Scaffold(
      appBar: AppBar(backgroundColor: themeColor, title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  TextField(controller: _odometerController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odômetro (km)', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor Total', prefixText: 'R$ ', border: OutlineInputBorder())),
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
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
      appBar: AppBar(backgroundColor: DrivvoColors.reminderAlert, title: const Text('Lembrete')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
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
                style: ElevatedButton.styleFrom(backgroundColor: DrivvoColors.reminderAlert, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
// 6. RELATÓRIOS TAB (REPORTS & CHARTS)
// ==========================================
class ReportsTab extends StatefulWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;

  const ReportsTab({super.key, required this.vehicle, required this.events});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int _selectedPeriod = 4; // 0: Este Mês, 1: 3 Meses, 2: 6 Meses, 3: Este Ano, 4: Geral (Todo o período)

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
                  selectedColor: DrivvoColors.primaryTeal,
                  labelStyle: TextStyle(color: isSel ? Colors.white : DrivvoColors.textDark, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
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
            _buildKpiCard('Gasto Total', 'R$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalSpent)}', Icons.account_balance_wallet, DrivvoColors.primaryTeal),
            const SizedBox(width: 12),
            _buildKpiCard('Combustível', '${NumberFormat('#,##0.0', 'pt_BR').format(totalLiters)} L', Icons.local_gas_station, DrivvoColors.fuelOrange),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildKpiCard('Distância', '${NumberFormat('#,###', 'pt_BR').format(totalKm)} km', Icons.directions_car, Colors.indigo),
            const SizedBox(width: 12),
            _buildKpiCard('Consumo Médio', avgKmL > 0 ? '${avgKmL.toStringAsFixed(2)} km/L' : '-', Icons.speed, Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildKpiCard('Custo / km', avgCostKm > 0 ? 'R$ ${avgCostKm.toStringAsFixed(2)}' : '-', Icons.trending_up, Colors.deepOrange),
            const SizedBox(width: 12),
            _buildKpiCard('Preço Médio / L', avgPriceLiter > 0 ? 'R$ ${avgPriceLiter.toStringAsFixed(2)}' : '-', Icons.attach_money, Colors.teal),
          ],
        ),
        const SizedBox(height: 20),

        // Summary Chart: Fuel vs Other Expenses
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: DrivvoColors.divider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Distribuição de Despesas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: (totalFuelSpent > 0 ? (totalFuelSpent / (totalSpent > 0 ? totalSpent : 1) * 100).toInt() : 95).clamp(1, 100),
                    child: Container(height: 12, decoration: const BoxDecoration(color: DrivvoColors.fuelOrange, borderRadius: BorderRadius.horizontal(left: Radius.circular(6)))),
                  ),
                  Expanded(
                    flex: (totalOtherSpent > 0 ? (totalOtherSpent / (totalSpent > 0 ? totalSpent : 1) * 100).toInt() : 5).clamp(1, 100),
                    child: Container(height: 12, decoration: const BoxDecoration(color: DrivvoColors.servicePurple, borderRadius: BorderRadius.horizontal(right: Radius.circular(6)))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: DrivvoColors.fuelOrange, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Combustível: R$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalFuelSpent)}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: DrivvoColors.servicePurple, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Outros: R$ ${NumberFormat('#,##0.00', 'pt_BR').format(totalOtherSpent)}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DrivvoColors.divider),
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
                Text(title, style: const TextStyle(fontSize: 12, color: DrivvoColors.textMuted)),
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
            const Text('Lembretes e Manutenções', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add, color: DrivvoColors.primaryTeal),
              label: const Text('Novo', style: TextStyle(color: DrivvoColors.primaryTeal, fontWeight: FontWeight.bold)),
              onPressed: onAddReminder,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (reminders.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('Nenhum lembrete cadastrado.', style: TextStyle(color: DrivvoColors.textMuted)),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DrivvoColors.divider),
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
                            decoration: rem.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (rem.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(rem.description, style: const TextStyle(fontSize: 12, color: DrivvoColors.textMuted)),
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
                              style: const TextStyle(fontSize: 11, color: DrivvoColors.textLight),
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
// 8. MAIS TAB (SETTINGS, GARAGE, BACKUP)
// ==========================================
class MoreTab extends StatelessWidget {
  final CarVehicle vehicle;
  final int totalRecords;
  final Future<void> Function() onRestoreBackup;
  final Future<void> Function() onSyncCloudflare;
  final VoidCallback onCheckUpdates;

  const MoreTab({
    super.key,
    required this.vehicle,
    required this.totalRecords,
    required this.onRestoreBackup,
    required this.onSyncCloudflare,
    required this.onCheckUpdates,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DrivvoColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(color: DrivvoColors.lightTeal, shape: BoxShape.circle),
                child: const Icon(Icons.directions_car, color: DrivvoColors.primaryTeal, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${vehicle.model} • Tanque: ${vehicle.tankCapacity.toInt()}L', style: const TextStyle(fontSize: 13, color: DrivvoColors.textMuted)),
                    Text('$totalRecords abastecimentos registrados', style: const TextStyle(fontSize: 12, color: DrivvoColors.primaryTeal, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section: Ferramentas & Dados
        _buildSectionHeader('FERRAMENTAS & SINCRONIZAÇÃO'),
        _buildSettingsTile(
          icon: Icons.cloud_sync,
          color: DrivvoColors.primaryTeal,
          title: 'Sincronização em Nuvem (Cloudflare)',
          subtitle: 'finanza-auto.jeffef.workers.dev',
          onTap: () async {
            await onSyncCloudflare();
          },
        ),
        _buildSettingsTile(
          icon: Icons.calculate,
          color: DrivvoColors.fuelOrange,
          title: 'Calculadora Flex (Etanol x Gasolina)',
          subtitle: 'Compare a relação de paridade 70%',
          onTap: () {
            _showFlexCalculator(context);
          },
        ),
        _buildSettingsTile(
          icon: Icons.restore,
          color: Colors.teal,
          title: 'Restaurar Dados Originais (146 abastecimentos)',
          subtitle: 'Recarrega os registros reais de 2020 a 2026',
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Restaurar histórico completo?'),
                content: const Text('Isso recarregará todos os 146 registros oficiais do Drivvo até Setembro de 2026.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: DrivvoColors.primaryTeal, foregroundColor: Colors.white),
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
          title: 'Finanza Auto 2.0 - Drivvo Edition',
          subtitle: 'Interface 100% alinhada com Drivvo e dados reais.',
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
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DrivvoColors.textLight, letterSpacing: 0.8),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrivvoColors.divider),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: DrivvoColors.textMuted)),
        trailing: const Icon(Icons.chevron_right, color: DrivvoColors.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }

  static void _showFlexCalculator(BuildContext context) {
    final ethanolCtrl = TextEditingController(text: '3.49');
    final gasCtrl = TextEditingController(text: '5.89');

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

          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Calculadora Flex (Álcool x Gasolina)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('A regra dos 70% indica se o etanol é economicamente mais vantajoso.', style: TextStyle(fontSize: 12, color: DrivvoColors.textMuted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ethanolCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Preço Etanol (R$)', border: OutlineInputBorder()),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: gasCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Preço Gasolina (R$)', border: OutlineInputBorder()),
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
                              style: const TextStyle(fontSize: 12),
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
