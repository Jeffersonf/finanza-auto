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
const String appVersion = '2.3.6';
const int appBuildNumber = 28;
const String cloudflareSyncUrl = 'https://finanza-auto.jeffef.workers.dev/api/sync';

/// Dynamic Theme State Notifiers
final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

/// App Theme Tokens (AutoLog - Cobalt & Âmbar)
class AppTheme {
  // Surfaces & Backgrounds
  static Color get background => isDarkMode.value ? const Color(0xFF0A0E14) : const Color(0xFFF8FAFC);
  static Color get card => isDarkMode.value ? const Color(0xFF131924) : const Color(0xFFFFFFFF);
  static Color get cardSubtle => isDarkMode.value ? const Color(0xFF1A2232) : const Color(0xFFF1F5F9);
  static Color get border => isDarkMode.value ? const Color(0xFF263248) : const Color(0xFFE2E8F0);
  static Color get trackLine => isDarkMode.value ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

  // Cobalt Blue & Accents
  static const Color primary = Color(0xFF2563EB); // Cobalt Blue Principal
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color primaryForeground = Colors.white;
  static Color get primarySoft => isDarkMode.value ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
  static Color get primarySoftText => isDarkMode.value ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);
  static Color get textOnDarkGreen => const Color(0xFFBFDBFE); // Soft cobalt highlight for primary card

  // Âmbar (Combustível e Tanque Parcial)
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFEF3C7);

  // Typography Colors (Slate Neutrals - Zero Green)
  static Color get textMain => isDarkMode.value ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textMuted => isDarkMode.value ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textLight => isDarkMode.value ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Status Colors
  static const Color fuelOrange = Color(0xFFF59E0B);
  static const Color servicePurple = Color(0xFF8B5CF6);
  static const Color expenseBlue = Color(0xFF0284C7);
  static const Color reminderAlert = Color(0xFFEF4444);
  static const Color economyGreen = Color(0xFF2563EB);
}

/// Vehicle Model (Preserving Chevrolet Astra specs: 52L tank, ~164.154 km)
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
      return DateTime.parse(date);
    } catch (_) {
      return DateTime.now();
    }
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
    this.repeatIntervalKm = 0,
    this.repeatIntervalMonths = 0,
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
      repeatIntervalKm: (map['repeatIntervalKm'] as num?)?.toInt() ?? 0,
      repeatIntervalMonths: (map['repeatIntervalMonths'] as num?)?.toInt() ?? 0,
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

  try {
    final prefs = await SharedPreferences.getInstance();
    final savedIsDark = prefs.getBool('finanza_auto_is_dark');
    if (savedIsDark != null) {
      isDarkMode.value = savedIsDark;
    } else {
      isDarkMode.value = true;
      await prefs.setBool('finanza_auto_is_dark', true);
    }
  } catch (_) {}

  runApp(const FinanzaAutoApp());
}

class FinanzaAutoApp extends StatelessWidget {
  const FinanzaAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          key: ValueKey('autolog_app_$isDark'),
          title: 'AutoLog',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'DM Sans',
            brightness: Brightness.light,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              surface: Color(0xFFFFFFFF),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF8FAFC),
              foregroundColor: Color(0xFF0F172A),
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'DM Sans',
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2563EB),
              surface: Color(0xFF131924),
            ),
            scaffoldBackgroundColor: const Color(0xFF0A0E14),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0A0E14),
              foregroundColor: Color(0xFFF8FAFC),
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF8FAFC),
              ),
            ),
          ),
          home: FinanzaAutoHomePage(key: ValueKey('home_$isDark')),
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

  List<CarVehicle> _vehicles = [];
  String _activeVehicleId = 'drivvo-car';
  List<CarEvent> _events = [];
  List<CarReminder> _reminders = [];

  CarVehicle get _activeVehicle {
    return _vehicles.firstWhere(
      (v) => v.id == _activeVehicleId,
      orElse: () => CarVehicle(
        id: 'drivvo-car',
        name: 'Astra',
        model: 'Chevrolet Astra',
        plate: '',
        odometer: 164154,
        tankCapacity: 52.0,
      ),
    );
  }

  int get _latestOdometer {
    if (_events.isEmpty) return _activeVehicle.odometer;
    int maxOdo = _activeVehicle.odometer;
    for (final e in _events) {
      if (e.odometer > maxOdo) maxOdo = e.odometer;
    }
    return maxOdo;
  }

  @override
  void initState() {
    super.initState();
    isDarkMode.addListener(_onThemeChanged);
    _loadAllData().then((_) => _checkQuickFuelAction());
    _checkAppUpdates();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
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
          SnackBar(
            content: Text('Você já está na versão mais recente (v$appVersion+b$appBuildNumber).'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (_) {}
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text('Atualização Disponível', style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova versão v${info.version} (Build ${info.buildNumber})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const SizedBox(height: 8),
            Text(info.releaseNotes, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Depois', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.primaryForeground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startUpdateDownload(info);
            },
            child: const Text('Atualizar Agora'),
          ),
        ],
      ),
    );
  }

  void _startUpdateDownload(AppUpdateInfo info) {
    double progress = 0.0;
    String statusText = 'Iniciando download...';
    bool isDownloading = true;
    bool isComplete = false;
    bool hasFailed = false;
    String? localApkPath;
    void Function(void Function())? updateDialogState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            updateDialogState = setDlgState;
            return AlertDialog(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    hasFailed ? Icons.error_outline : (isComplete ? Icons.check_circle_outline : Icons.downloading),
                    color: hasFailed ? AppTheme.reminderAlert : (isComplete ? AppTheme.primary : AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isComplete ? 'Download Concluído' : (hasFailed ? 'Falha no Download' : 'Baixando Atualização'),
                    style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instalador v${info.version} (${info.buildNumber})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (isDownloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        backgroundColor: AppTheme.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(statusText, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ] else if (hasFailed) ...[
                    const Text(
                      'Não foi possível concluir o download automático. Você pode baixar diretamente pelo navegador abaixo:',
                      style: TextStyle(color: AppTheme.reminderAlert, fontSize: 13),
                    ),
                  ] else ...[
                    Text(
                      'Download concluído! Se o instalador do Android não abrir, permita "Instalar apps desconhecidos" nas configurações.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text('Fechar', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                if (isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                if (isComplete && localApkPath != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.primaryForeground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final canInstall = await UpdaterService.canRequestPackageInstalls();
                      if (!canInstall) {
                        await UpdaterService.openInstallPermissionSettings();
                      }
                      final installed = await UpdaterService.installApk(localApkPath!);
                      if (!installed) {
                        UpdaterService.openInBrowser(info.downloadUrl);
                      }
                    },
                    child: const Text('Instalar Novamente'),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isComplete ? AppTheme.cardSubtle : AppTheme.primary,
                    foregroundColor: isComplete ? AppTheme.textMain : AppTheme.primaryForeground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: const Text('Via Navegador'),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    UpdaterService.openInBrowser(info.downloadUrl);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    Future.microtask(() async {
      try {
        final path = await UpdaterService.downloadApk(
          info.downloadUrl,
          version: info.version,
          buildNumber: info.buildNumber,
          onProgress: (p) {
            progress = p;
            statusText = 'Baixando... ${(p * 100).toInt()}%';
            updateDialogState?.call(() {});
          },
        );

        if (path != null) {
          localApkPath = path;
          isDownloading = false;
          isComplete = true;
          updateDialogState?.call(() {});

          final canInstall = await UpdaterService.canRequestPackageInstalls();
          if (canInstall) {
            final ok = await UpdaterService.installApk(path);
            if (!ok) {
              await UpdaterService.openInstallPermissionSettings();
            }
          } else {
            await UpdaterService.openInstallPermissionSettings();
          }
        } else {
          isDownloading = false;
          hasFailed = true;
          updateDialogState?.call(() {});
        }
      } catch (_) {
        isDownloading = false;
        hasFailed = true;
        updateDialogState?.call(() {});
      }
    });
  }

  Future<void> _loadAllData({bool forceReloadBundled = false}) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLoadedVersion = prefs.getString('finanza_auto_loaded_version');
      final bool isNewRelease = lastLoadedVersion != appVersion;

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
            model: 'Chevrolet Astra',
            plate: '',
            odometer: 164154,
            tankCapacity: 52.0,
            serviceIntervalKm: 10000,
          ),
        );
      }
      for (final v in loadedVehicles) {
        if (v.id == 'drivvo-car' || loadedVehicles.length == 1) {
          v.name = 'Astra';
          v.model = 'Chevrolet Astra';
        }
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

      await prefs.setString('finanza_auto_loaded_version', appVersion);
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
        }
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
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      final payload = jsonEncode({
        'car': {
          'vehicles': _vehicles.map((v) => v.toMap()).toList(),
          'events': _events.map((e) => e.toMap()).toList(),
          'reminders': _reminders.map((r) => r.toMap()).toList(),
          'syncedAt': DateTime.now().toIso8601String(),
          'appVersion': appVersion,
        }
      });

      final bytes = utf8.encode(payload);
      final request = await client.postUrl(Uri.parse(cloudflareSyncUrl));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Content-Length', bytes.length.toString());
      request.add(bytes);

      final response = await request.close();
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Dados sincronizados com a nuvem com sucesso!'),
                ],
              ),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
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
          vehicle: _activeVehicle,
          latestOdometer: _latestOdometer,
          isService: isService,
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
              'Registrar Atividade',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.local_gas_station, color: AppTheme.primary, size: 22),
              ),
              title: Text('Abastecimento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain)),
              subtitle: Text('Registrar combustível, odômetro e valor', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _openFuelingForm();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppTheme.cardSubtle, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.build, color: AppTheme.servicePurple, size: 22),
              ),
              title: Text('Serviço', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain)),
              subtitle: Text('Manutenção, troca de óleo ou peças', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _openServiceExpenseForm(isService: true);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppTheme.cardSubtle, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.receipt_long, color: AppTheme.expenseBlue, size: 22),
              ),
              title: Text('Despesa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain)),
              subtitle: Text('Estacionamento, pedágio, lavagem ou seguro', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _openServiceExpenseForm(isService: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text('Carregando AutoLog...', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // 0: Início
            HomeOverviewTab(
              vehicle: _activeVehicle,
              events: _events,
              latestOdometer: _latestOdometer,
              onOpenFueling: () => _openFuelingForm(),
              onNavigateToHistory: () => setState(() => _currentIndex = 1),
              onNavigateToVehicle: () => setState(() => _currentIndex = 3),
            ),
            // 1: Histórico
            HistoryTab(
              vehicle: _activeVehicle,
              events: _events,
              onEventTap: (ev) => _showEventDetails(ev),
              onAddFueling: () => _openFuelingForm(),
            ),
            // 2: Análise
            AnalyticsTab(
              vehicle: _activeVehicle,
              events: _events,
            ),
            // 3: Veículo
            VehicleTab(
              vehicle: _activeVehicle,
              events: _events,
              reminders: _reminders,
              latestOdometer: _latestOdometer,
              onRestoreBackup: () async {
                await _loadAllData(forceReloadBundled: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('146 abastecimentos reais restaurados com sucesso!'),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                }
              },
              onSyncCloudflare: _syncWithCloudflare,
              onCheckUpdates: () => _checkAppUpdates(manual: true),
              onAddReminder: () => _openReminderForm(),
              onEditOdometer: (newKm) {
                setState(() {
                  _activeVehicle.odometer = newKm;
                });
                _saveLocalState();
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_outlined, Icons.home, 'Início', 0),
                _buildNavItem(Icons.history_outlined, Icons.history, 'Histórico', 1),
                _buildNavItem(Icons.insights_outlined, Icons.insights, 'Análise', 2),
                _buildNavItem(Icons.directions_car_outlined, Icons.directions_car, 'Veículo', 3),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? FloatingActionButton(
              onPressed: _showSpeedDialMenu,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }

  Widget _buildNavItem(IconData outlineIcon, IconData filledIcon, String label, int index) {
    final isSel = _currentIndex == index;
    final color = isSel ? AppTheme.primary : AppTheme.textMuted;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSel ? filledIcon : outlineIcon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(CarEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(24),
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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.cardSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        event.type == 'fuel' ? Icons.local_gas_station : (event.type == 'service' ? Icons.build : Icons.receipt_long),
                        color: event.type == 'fuel' ? AppTheme.accentAmber : (event.type == 'service' ? AppTheme.servicePurple : AppTheme.expenseBlue),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.fuelType.isNotEmpty ? event.fuelType : event.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain)),
                        Text('${DateFormat('dd/MM/yyyy').format(event.parsedDate)} · ${event.station.isNotEmpty ? event.station : "Posto"}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
                Text(
                  'R\$ ${event.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textMain),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 16),
            if (event.type == 'fuel') ...[
              _buildDetailRow('Litros', '${event.liters.toStringAsFixed(2).replaceAll('.', ',')} L'),
              _buildDetailRow('Preço por Litro', 'R\$ ${event.pricePerLiter.toStringAsFixed(2).replaceAll('.', ',')} /L'),
              _buildDetailRow('Odômetro', '${event.odometer.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} km'),
              _buildDetailRow(
                'Tanque',
                event.isFullTank ? 'Tanque Completo' : 'Abastecimento Parcial',
                textColor: event.isFullTank ? AppTheme.primary : AppTheme.accentAmber,
              ),
            ],
            if (event.driver.isNotEmpty) _buildDetailRow('Motorista', event.driver),
            if (event.paymentMethod.isNotEmpty) _buildDetailRow('Forma de Pagamento', event.paymentMethod),
            if (event.note.isNotEmpty) _buildDetailRow('Observações', event.note),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.reminderAlert.withValues(alpha: 0.5)),
                      foregroundColor: AppTheme.reminderAlert,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Excluir'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeleteEvent(event);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (event.type == 'fuel') {
                        _openFuelingForm(event: event);
                      } else {
                        _openServiceExpenseForm(isService: event.type == 'service', event: event);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor ?? AppTheme.textMain)),
        ],
      ),
    );
  }

  void _confirmDeleteEvent(CarEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Excluir Registro', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
        content: Text(
          'Deseja realmente excluir este abastecimento de R\$ ${event.amount.toStringAsFixed(2).replaceAll('.', ',')}?',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.reminderAlert, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteEvent(event.id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. INÍCIO (HOME OVERVIEW TAB)
// ==========================================
class HomeOverviewTab extends StatelessWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;
  final int latestOdometer;
  final VoidCallback onOpenFueling;
  final VoidCallback onNavigateToHistory;
  final VoidCallback onNavigateToVehicle;

  const HomeOverviewTab({
    super.key,
    required this.vehicle,
    required this.events,
    required this.latestOdometer,
    required this.onOpenFueling,
    required this.onNavigateToHistory,
    required this.onNavigateToVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final fuelEvents = events.where((e) => e.type == 'fuel').toList();

    // Current month fuel stats
    final now = DateTime.now();
    final currentMonthEvents = fuelEvents.where((e) {
      final d = e.parsedDate;
      return d.year == now.year && d.month == now.month;
    }).toList();

    // If current month has fewer than 1, take the latest 3 fuelings as period
    final activePeriodEvents = currentMonthEvents.isNotEmpty ? currentMonthEvents : fuelEvents.take(3).toList();
    final double monthFuelSpent = activePeriodEvents.fold(0.0, (sum, e) => sum + e.amount);
    final double monthLiters = activePeriodEvents.fold(0.0, (sum, e) => sum + e.liters);
    final int monthFuelCount = activePeriodEvents.length;

    // Average consumption calculation from full tanks
    double avgConsumption = 0.0;
    final fullTanks = fuelEvents.where((e) => e.isFullTank && e.liters > 0 && e.odometer > 0).toList();
    if (fullTanks.length >= 2) {
      double totalKm = (fullTanks.first.odometer - fullTanks.last.odometer).toDouble();
      double totalL = 0.0;
      for (int i = 0; i < fullTanks.length - 1; i++) {
        totalL += fullTanks[i].liters;
      }
      if (totalL > 0 && totalKm > 0) {
        avgConsumption = totalKm / totalL;
      }
    }
    if (avgConsumption <= 0 || avgConsumption > 25) avgConsumption = 8.4; // Realistic Astra Etanol default

    // Cost per km
    double costPerKm = 0.0;
    if (fuelEvents.length >= 2) {
      final odoDelta = fuelEvents.first.odometer - fuelEvents.last.odometer;
      final totalSpent = fuelEvents.fold(0.0, (sum, e) => sum + e.amount);
      if (odoDelta > 0) {
        costPerKm = totalSpent / odoDelta;
      }
    }
    if (costPerKm <= 0 || costPerKm > 5) costPerKm = 0.68;

    final odoFormatted = latestOdometer.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    final lastFuel = fuelEvents.isNotEmpty ? fuelEvents.first : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // App Brand Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AUTOLOG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Visão geral',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: isDarkMode.value ? 'Mudar para Modo Claro' : 'Mudar para Modo Escuro',
                  onPressed: () async {
                    isDarkMode.value = !isDarkMode.value;
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('finanza_auto_is_dark', isDarkMode.value);
                    } catch (_) {}
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          backgroundColor: AppTheme.card,
                          content: Text(
                            isDarkMode.value ? 'Modo Escuro (Cockpit) ativado' : 'Modo Claro ativado',
                            style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  },
                  icon: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(
                      isDarkMode.value ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: AppTheme.accentAmber,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onNavigateToVehicle,
                  icon: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(Icons.settings_outlined, color: AppTheme.textMuted, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Seletor de Veículo (Card Branco)
        InkWell(
          onTap: onNavigateToVehicle,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.cardSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.model.isNotEmpty ? vehicle.model : 'Chevrolet Astra',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Meu carro · $odoFormatted km',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cartão Principal de Combustível (Hero Fuel Card - Verde Petróleo #176B51)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'COMBUSTÍVEL NO MÊS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppTheme.textOnDarkGreen,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateFormat('MMMM', 'pt_BR').format(now).toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'R\$ ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textOnDarkGreen),
                  ),
                  Text(
                    monthFuelSpent.toStringAsFixed(2).replaceAll('.', ','),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_gas_station, size: 16, color: AppTheme.accentAmber),
                        const SizedBox(width: 6),
                        Text(
                          '$monthFuelCount abastecimento${monthFuelCount != 1 ? "s" : ""}',
                          style: TextStyle(fontSize: 12, color: AppTheme.textOnDarkGreen),
                        ),
                      ],
                    ),
                    Text(
                      '·',
                      style: TextStyle(color: AppTheme.textOnDarkGreen),
                    ),
                    Text(
                      '${monthLiters.toStringAsFixed(2).replaceAll('.', ',')} Litros',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Indicadores Secundários (Dois Lado a Lado)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONSUMO MÉDIO',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          avgConsumption.toStringAsFixed(1).replaceAll('.', ','),
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        ),
                        const SizedBox(width: 4),
                        Text('km/L', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        const Text('Etanol / Cidade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CUSTO POR KM',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('R\$ ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                        Text(
                          costPerKm.toStringAsFixed(2).replaceAll('.', ','),
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        ),
                        const SizedBox(width: 3),
                        Text('/km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Somente combustível',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Evolução do Consumo (Gráfico Limpo)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evolução do Consumo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                      ),
                      Text(
                        'Últimos abastecimentos (km/L)',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  Text(
                    '${avgConsumption.toStringAsFixed(1).replaceAll('.', ',')} km/L',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                width: double.infinity,
                child: CustomPaint(
                  painter: ConsumptionCurvePainter(
                    events: fuelEvents.take(10).toList().reversed.toList(),
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Botão Principal de Ação (Registrar Abastecimento)
        SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Registrar abastecimento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            onPressed: onOpenFueling,
          ),
        ),
        const SizedBox(height: 20),

        // Card Último Registro
        if (lastFuel != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ÚLTIMO REGISTRO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.textMuted),
              ),
              InkWell(
                onTap: onNavigateToHistory,
                child: const Text('Ver histórico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: AppTheme.cardSubtle, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.local_gas_station, color: AppTheme.accentAmber, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lastFuel.fuelType, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain)),
                            Text('${DateFormat('dd MMM', 'pt_BR').format(lastFuel.parsedDate)} · ${lastFuel.station}', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('R\$ ${lastFuel.amount.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain)),
                        Text('${lastFuel.liters.toStringAsFixed(2).replaceAll('.', ',')} L · R\$ ${lastFuel.pricePerLiter.toStringAsFixed(2).replaceAll('.', ',')}/L', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${lastFuel.odometer.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} km',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace'),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: lastFuel.isFullTank ? AppTheme.primary : AppTheme.accentAmber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          lastFuel.isFullTank ? 'Tanque completo' : 'Abastecimento parcial',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: lastFuel.isFullTank ? AppTheme.primary : AppTheme.accentAmber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// Custom painter for smooth consumption line with gradient fill
class ConsumptionCurvePainter extends CustomPainter {
  final List<CarEvent> events;
  final Color color;

  ConsumptionCurvePainter({required this.events, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (events.isEmpty) return;

    final values = <double>[];
    for (int i = 0; i < events.length - 1; i++) {
      final cur = events[i];
      final next = events[i + 1];
      if (cur.odometer > next.odometer && cur.liters > 0) {
        final km = (cur.odometer - next.odometer).toDouble();
        final c = km / cur.liters;
        if (c > 3 && c < 22) values.add(c);
      }
    }
    if (values.length < 2) {
      values.addAll([7.8, 8.2, 8.0, 8.5, 8.4]);
    }

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = (maxVal - minVal) > 0 ? (maxVal - minVal) : 1.0;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (values.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normY = (values[i] - minVal) / range;
      final y = size.height - (normY * (size.height - 20) + 10);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // Gradient Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke Path
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Draw last point
    final lastPoint = points.last;
    canvas.drawCircle(
      lastPoint,
      4.5,
      Paint()..color = color,
    );
    canvas.drawCircle(
      lastPoint,
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// 2. HISTÓRICO (HISTORY TAB)
// ==========================================
class HistoryTab extends StatefulWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;
  final Function(CarEvent) onEventTap;
  final VoidCallback onAddFueling;

  const HistoryTab({
    super.key,
    required this.vehicle,
    required this.events,
    required this.onEventTap,
    required this.onAddFueling,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _selectedCategory = 'Todos';

  @override
  Widget build(BuildContext context) {
    var filtered = widget.events;
    if (_selectedCategory == 'Combustível') {
      filtered = filtered.where((e) => e.type == 'fuel').toList();
    } else if (_selectedCategory == 'Serviço') {
      filtered = filtered.where((e) => e.type == 'service').toList();
    } else if (_selectedCategory == 'Despesa') {
      filtered = filtered.where((e) => e.type == 'expense').toList();
    }

    final totalSpent = filtered.fold(0.0, (sum, e) => sum + e.amount);
    final totalLiters = filtered.where((e) => e.type == 'fuel').fold(0.0, (sum, e) => sum + e.liters);
    final totalRecords = filtered.length;

    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Histórico', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              Text('${filtered.length} registros', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            ],
          ),
        ),

        // Summary Card in Soft Green (#DDEDE5)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Total Gasto', 'R\$ ${totalSpent.toStringAsFixed(2).replaceAll('.', ',')}'),
                Container(width: 1, height: 28, color: AppTheme.border),
                _buildSummaryStat('Volume Total', '${totalLiters.toStringAsFixed(1).replaceAll('.', ',')} L'),
                Container(width: 1, height: 28, color: AppTheme.border),
                _buildSummaryStat('Registros', '$totalRecords'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: ['Todos', 'Combustível', 'Serviço', 'Despesa'].map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.card,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : AppTheme.textMain,
                  ),
                  side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Event List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('Nenhum registro encontrado.', style: TextStyle(color: AppTheme.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final ev = filtered[i];
                    return _buildEventCard(ev);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppTheme.primarySoftText)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
      ],
    );
  }

  Widget _buildEventCard(CarEvent ev) {
    final odoFormatted = ev.odometer.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    return InkWell(
      onTap: () => widget.onEventTap(ev),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.cardSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    ev.type == 'fuel' ? Icons.local_gas_station : (ev.type == 'service' ? Icons.build : Icons.receipt_long),
                    color: ev.type == 'fuel' ? AppTheme.accentAmber : (ev.type == 'service' ? AppTheme.servicePurple : AppTheme.expenseBlue),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ev.type == 'fuel' ? ev.fuelType : (ev.title.isNotEmpty ? ev.title : ev.category),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd MMM', 'pt_BR').format(ev.parsedDate)} · ${ev.station.isNotEmpty ? ev.station : "Posto"}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R\$ ${ev.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain),
                    ),
                    if (ev.type == 'fuel' && ev.liters > 0)
                      Text(
                        '${ev.liters.toStringAsFixed(2).replaceAll('.', ',')} L · R\$ ${ev.pricePerLiter.toStringAsFixed(2).replaceAll('.', ',')}/L',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$odoFormatted km',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace'),
                ),
                if (ev.type == 'fuel')
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: ev.isFullTank ? AppTheme.primary : AppTheme.accentAmber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        ev.isFullTank ? 'Tanque completo' : 'Abastecimento parcial',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: ev.isFullTank ? AppTheme.primary : AppTheme.accentAmber,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. ANÁLISE (ANALYTICS TAB)
// ==========================================
class AnalyticsTab extends StatelessWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;

  const AnalyticsTab({
    super.key,
    required this.vehicle,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final fuelEvents = events.where((e) => e.type == 'fuel').toList();

    double avgConsumption = 0.0;
    final fullTanks = fuelEvents.where((e) => e.isFullTank && e.liters > 0 && e.odometer > 0).toList();
    if (fullTanks.length >= 2) {
      double totalKm = (fullTanks.first.odometer - fullTanks.last.odometer).toDouble();
      double totalL = 0.0;
      for (int i = 0; i < fullTanks.length - 1; i++) {
        totalL += fullTanks[i].liters;
      }
      if (totalL > 0 && totalKm > 0) {
        avgConsumption = totalKm / totalL;
      }
    }
    if (avgConsumption <= 0 || avgConsumption > 25) avgConsumption = 8.4;

    double costPerKm = 0.0;
    if (fuelEvents.length >= 2) {
      final odoDelta = fuelEvents.first.odometer - fuelEvents.last.odometer;
      final totalSpent = fuelEvents.fold(0.0, (sum, e) => sum + e.amount);
      if (odoDelta > 0) costPerKm = totalSpent / odoDelta;
    }
    if (costPerKm <= 0 || costPerKm > 5) costPerKm = 0.68;

    double avgPricePerLiter = 0.0;
    final validPpl = fuelEvents.where((e) => e.pricePerLiter > 0).toList();
    if (validPpl.isNotEmpty) {
      avgPricePerLiter = validPpl.fold(0.0, (sum, e) => sum + e.pricePerLiter) / validPpl.length;
    }
    if (avgPricePerLiter <= 0) avgPricePerLiter = 5.75;

    final totalSpentOverall = events.fold(0.0, (sum, e) => sum + e.amount);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text('Análise', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        const SizedBox(height: 16),

        // Grid com 4 KPIs Principais
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildMetricTile('Consumo Médio', '${avgConsumption.toStringAsFixed(1).replaceAll('.', ',')} km/L', Icons.speed, AppTheme.primary),
            _buildMetricTile('Custo por Km', 'R\$ ${costPerKm.toStringAsFixed(2).replaceAll('.', ',')}', Icons.route, AppTheme.primary),
            _buildMetricTile('Preço Médio / L', 'R\$ ${avgPricePerLiter.toStringAsFixed(2).replaceAll('.', ',')}', Icons.local_gas_station, AppTheme.accentAmber),
            _buildMetricTile('Gasto Acumulado', 'R\$ ${totalSpentOverall.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}', Icons.account_balance_wallet, AppTheme.servicePurple),
          ],
        ),
        const SizedBox(height: 18),

        // Card Evolução do Preço do Litro
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Evolução do Preço do Combustível', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              Text('Histórico de valor pago por litro (R\$/L)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  painter: ConsumptionCurvePainter(
                    events: fuelEvents.take(12).toList().reversed.toList(),
                    color: AppTheme.accentAmber,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Dica de Eficiência
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardSubtle,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Abasteça com tanque completo para cálculos mais precisos de consumo e autonomia do Astra.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMain),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        ],
      ),
    );
  }
}

// ==========================================
// 4. VEÍCULO (VEHICLE TAB)
// ==========================================
class VehicleTab extends StatelessWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;
  final List<CarReminder> reminders;
  final int latestOdometer;
  final VoidCallback onRestoreBackup;
  final VoidCallback onSyncCloudflare;
  final VoidCallback onCheckUpdates;
  final VoidCallback onAddReminder;
  final Function(int) onEditOdometer;

  const VehicleTab({
    super.key,
    required this.vehicle,
    required this.events,
    required this.reminders,
    required this.latestOdometer,
    required this.onRestoreBackup,
    required this.onSyncCloudflare,
    required this.onCheckUpdates,
    required this.onAddReminder,
    required this.onEditOdometer,
  });

  @override
  Widget build(BuildContext context) {
    final odoFormatted = latestOdometer.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text('Veículo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        const SizedBox(height: 16),

        // Cartão do Chevrolet Astra
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chevrolet Astra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                      Text('Tanque 52L · ${vehicle.plate.isNotEmpty ? vehicle.plate : "Sem placa"}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.cardSubtle, borderRadius: BorderRadius.circular(12)),
                    child: const Text('ATIVO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ODÔMETRO ATUAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text('$odoFormatted km', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain, fontFamily: 'monospace')),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.border),
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Ajustar'),
                    onPressed: () {
                      _showEditOdometerDialog(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Manutenções e Revisões
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('REVISÕES & LEMBRETES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.textMuted)),
            InkWell(
              onTap: onAddReminder,
              child: const Text('+ Novo lembrete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...reminders.map((rem) => _buildReminderTile(rem)),
        const SizedBox(height: 20),

        // Utilitários e Sistema
        Text('SISTEMA & DADOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.textMuted)),
        const SizedBox(height: 10),

        _buildActionTile(
          icon: Icons.cloud_sync_outlined,
          title: 'Sincronizar com a Nuvem',
          subtitle: 'Cloudflare Worker Sync',
          onTap: onSyncCloudflare,
        ),
        _buildActionTile(
          icon: Icons.restore,
          title: 'Restaurar 146 Abastecimentos',
          subtitle: 'Carregar backup padrão local',
          onTap: onRestoreBackup,
        ),
        _buildActionTile(
          icon: Icons.system_update_outlined,
          title: 'Verificar Atualizações',
          subtitle: 'Versão atual v$appVersion (Build $appBuildNumber)',
          onTap: onCheckUpdates,
        ),
        _buildActionTile(
          icon: isDarkMode.value ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          title: 'Tema: ${isDarkMode.value ? "Modo Escuro (Cockpit)" : "Modo Claro"}',
          subtitle: isDarkMode.value ? 'Toque para alternar para o Modo Claro' : 'Toque para alternar para o Modo Escuro',
          trailing: Switch(
            value: isDarkMode.value,
            activeColor: AppTheme.primary,
            onChanged: (val) async {
              isDarkMode.value = val;
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('finanza_auto_is_dark', val);
              } catch (_) {}
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppTheme.card,
                    content: Text(
                      val ? 'Modo Escuro (Cockpit) ativado' : 'Modo Claro ativado',
                      style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
            },
          ),
          onTap: () async {
            isDarkMode.value = !isDarkMode.value;
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('finanza_auto_is_dark', isDarkMode.value);
            } catch (_) {}
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppTheme.card,
                  content: Text(
                    isDarkMode.value ? 'Modo Escuro (Cockpit) ativado' : 'Modo Claro ativado',
                    style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildReminderTile(CarReminder rem) {
    final remainingKm = rem.targetOdometer - latestOdometer;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppTheme.cardSubtle, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.build_circle_outlined, color: AppTheme.servicePurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rem.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain)),
                Text(
                  remainingKm > 0 ? 'Faltam $remainingKm km' : 'Revisão pendente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: remainingKm > 0 ? AppTheme.textMuted : AppTheme.reminderAlert,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${rem.targetOdometer.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} km',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary, size: 22),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        trailing: trailing ?? Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
        onTap: onTap,
      ),
    );
  }

  void _showEditOdometerDialog(BuildContext context) {
    final controller = TextEditingController(text: latestOdometer.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Ajustar Odômetro', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quilometragem (km)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              final newKm = int.tryParse(controller.text.replaceAll('.', '')) ?? latestOdometer;
              onEditOdometer(newKm);
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. NOVO ABASTECIMENTO (FUELING FORM SCREEN)
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
    _odometerController = TextEditingController(
      text: ev != null ? ev.odometer.toString() : (widget.latestOdometer > 0 ? widget.latestOdometer.toString() : ''),
    );
    _priceController = TextEditingController(
      text: ev != null && ev.pricePerLiter > 0 ? ev.pricePerLiter.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _totalController = TextEditingController(
      text: ev != null && ev.amount > 0 ? ev.amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _litersController = TextEditingController(
      text: ev != null && ev.liters > 0 ? ev.liters.toStringAsFixed(3).replaceAll('.', ',') : '',
    );
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
    setState(() {});
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
    final displayTotal = _totalController.text.isNotEmpty ? _totalController.text : '0,00';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Novo abastecimento', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: AppTheme.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumo do Valor (Área Verde Suave #DDEDE5)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VALOR TOTAL DO ABASTECIMENTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.primarySoftText)),
                  const SizedBox(height: 4),
                  Text(
                    'R\$ $displayTotal',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Hodômetro
            Text('HODÔMETRO ATUAL (KM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            TextField(
              controller: _odometerController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
              decoration: InputDecoration(
                hintText: 'Ex: 164154',
                prefixIcon: const Icon(Icons.speed, color: AppTheme.primary, size: 20),
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
              ),
            ),
            const SizedBox(height: 16),

            // Data e Hora lado a lado
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                          const SizedBox(height: 4),
                          Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HORA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                          const SizedBox(height: 4),
                          Text(_selectedTime.format(context), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tipo de Combustível
            Text('TIPO DE COMBUSTÍVEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['Etanol', 'Gasolina Comum', 'Gasolina Aditivada', 'Diesel', 'GNV'].map((f) {
                final isSel = _selectedFuelType == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: isSel,
                  onSelected: (_) => setState(() => _selectedFuelType = f),
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.card,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? Colors.white : AppTheme.textMain,
                  ),
                  side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Preço por Litro e Litros lado a lado
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PREÇO / LITRO (R\$)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        decoration: InputDecoration(
                          hintText: '5,79',
                          filled: true,
                          fillColor: AppTheme.card,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LITROS (L)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _litersController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        decoration: InputDecoration(
                          hintText: '35,00',
                          filled: true,
                          fillColor: AppTheme.card,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Valor Total
            Text('VALOR TOTAL (R\$)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            TextField(
              controller: _totalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
              decoration: InputDecoration(
                hintText: '202,65',
                prefixText: 'R\$ ',
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
              ),
            ),
            const SizedBox(height: 18),

            // Tanque Completo (com a explicação solicitada no briefing)
            Container(
              padding: const EdgeInsets.all(14),
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
                      Text('Tanque completo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                      Switch(
                        value: _isFullTank,
                        activeColor: AppTheme.primary,
                        onChanged: (val) => setState(() => _isFullTank = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Marque quando abastecer até completar o tanque. Isso ajuda a calcular o consumo entre abastecimentos.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seção Expansível: Mais Opções
            InkWell(
              onTap: () => setState(() => _showMoreOptions = !_showMoreOptions),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(_showMoreOptions ? Icons.expand_less : Icons.expand_more, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 6),
                    const Text(
                      'Mais opções (Posto, Motorista, Notas)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ),

            if (_showMoreOptions) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _stationController,
                decoration: InputDecoration(
                  labelText: 'Posto de Combustível',
                  hintText: 'Ex: Rafaela, Shell, Petrobras',
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _driverController,
                decoration: InputDecoration(
                  labelText: 'Motorista',
                  hintText: 'Ex: Rafaela',
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Observações',
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Botão Salvar Abastecimento
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _submit,
                child: const Text('Salvar abastecimento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. FORMULÁRIO DE SERVIÇO / DESPESA
// ==========================================
class ServiceExpenseFormScreen extends StatefulWidget {
  final CarVehicle vehicle;
  final int latestOdometer;
  final bool isService;
  final CarEvent? existingEvent;
  final Function(CarEvent) onSave;

  const ServiceExpenseFormScreen({
    super.key,
    required this.vehicle,
    required this.latestOdometer,
    required this.isService,
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
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final ev = widget.existingEvent;
    _selectedDate = ev != null ? ev.parsedDate : DateTime.now();
    _titleController = TextEditingController(text: ev?.title ?? '');
    _amountController = TextEditingController(text: ev != null && ev.amount > 0 ? ev.amount.toStringAsFixed(2).replaceAll('.', ',') : '');
    _odometerController = TextEditingController(text: ev != null ? ev.odometer.toString() : (widget.latestOdometer > 0 ? widget.latestOdometer.toString() : ''));
    _notesController = TextEditingController(text: ev?.note ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final odo = int.tryParse(_odometerController.text.replaceAll('.', '')) ?? widget.latestOdometer;
    final title = _titleController.text.trim();

    if (amount <= 0 || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a descrição e o valor.')),
      );
      return;
    }

    final ev = CarEvent(
      id: widget.existingEvent?.id ?? 'event-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicle.id,
      type: widget.isService ? 'service' : 'expense',
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      amount: amount,
      odometer: odo,
      title: title,
      category: widget.isService ? 'Serviço' : 'Despesa',
      note: _notesController.text.trim(),
    );

    widget.onSave(ev);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.isService ? 'Novo Serviço' : 'Nova Despesa', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Descrição (Ex: Troca de Óleo, Estacionamento)',
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor Total (R\$)',
                prefixText: 'R\$ ',
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _odometerController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Odômetro (km)',
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observações',
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submit,
                child: const Text('Salvar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. FORMULÁRIO DE LEMBRETE
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
  late TextEditingController _kmController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final rem = widget.existingReminder;
    _titleController = TextEditingController(text: rem?.title ?? '');
    _kmController = TextEditingController(text: rem != null && rem.targetOdometer > 0 ? rem.targetOdometer.toString() : (widget.latestOdometer + 10000).toString());
    _descController = TextEditingController(text: rem?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _kmController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final km = int.tryParse(_kmController.text.replaceAll('.', '')) ?? (widget.latestOdometer + 10000);

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o título do lembrete.')),
      );
      return;
    }

    final rem = CarReminder(
      id: widget.existingReminder?.id ?? 'rem-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicle.id,
      title: title,
      description: _descController.text.trim(),
      targetOdometer: km,
    );

    widget.onSave(rem);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Novo Lembrete', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Título da Revisão (Ex: Troca de Óleo)',
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quilometragem Alvo (km)',
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: 'Descrição ou Peças',
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submit,
                child: const Text('Salvar Lembrete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
