import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'updater_service.dart';

const String appVersion = '1.1.4';
const int appBuildNumber = 6;

// Finanza Next design system tokens for Flutter
final ValueNotifier<bool> _darkMode = ValueNotifier<bool>(true);
bool get isDarkTheme => _darkMode.value;

Color get ink => isDarkTheme ? const Color(0xff000000) : const Color(0xfff4f5f8);
Color get panel => isDarkTheme ? const Color(0xff141416) : const Color(0xffffffff);
Color get panelSoft => isDarkTheme ? const Color(0xff1e1e22) : const Color(0xffeceef2);
Color get panelRaised => isDarkTheme ? const Color(0xff25252b) : const Color(0xffffffff);
Color get strokeColor => isDarkTheme ? const Color(0xff222226) : const Color(0x14000000);

const mint = Color(0xff34c759);
const amber = Color(0xffff9f0a);
const coral = Color(0xffff453a);
const blue = Color(0xff0a84ff);
const purple = Color(0xffaf52de);

Color get textMain => isDarkTheme ? const Color(0xffffffff) : const Color(0xff0f172a);
Color get textMuted => isDarkTheme ? const Color(0xff8e8e93) : const Color(0xff64748b);
Color get textSoft => isDarkTheme ? const Color(0xff66666a) : const Color(0xff94a3b8);

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.tint,
    this.opacity = .88,
    this.blur = 18,
    this.borderColor,
    this.gradient,
    this.shadows,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? tint;
  final double opacity;
  final double blur;
  final Color? borderColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? panel).withOpacity(opacity),
            gradient: gradient,
            borderRadius: shape,
            border: Border.all(color: borderColor ?? strokeColor),
            boxShadow: shadows ??
                [
                  BoxShadow(
                    color: isDarkTheme ? const Color(0x33000000) : const Color(0x0a000000),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const FinanzaAutoApp());
}

class FinanzaAutoApp extends StatelessWidget {
  const FinanzaAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _darkMode,
      builder: (context, dark, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Finanza · Carro',
        theme: ThemeData(
          useMaterial3: true,
          brightness: dark ? Brightness.dark : Brightness.light,
          fontFamily: 'DM Sans',
          scaffoldBackgroundColor: ink,
          textTheme: const TextTheme(
            headlineLarge: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w800),
            headlineMedium: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w800),
            titleLarge: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
            titleMedium: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
            bodyLarge: TextStyle(fontFamily: 'DM Sans'),
            bodyMedium: TextStyle(fontFamily: 'DM Sans'),
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: blue,
            brightness: dark ? Brightness.dark : Brightness.light,
          ).copyWith(
            primary: blue,
            onPrimary: Colors.white,
            secondary: mint,
            surface: panel,
            onSurface: textMain,
            surfaceContainerHighest: panelSoft,
            onSurfaceVariant: textMuted,
            outline: strokeColor,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: panelSoft,
            labelStyle: TextStyle(fontFamily: 'DM Sans', color: textMuted),
            hintStyle: TextStyle(fontFamily: 'DM Sans', color: textSoft),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: strokeColor),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: blue, width: 1.5),
            ),
          ),
          dividerTheme: DividerThemeData(color: strokeColor, space: 1),
        ),
        home: const CarHome(),
      ),
    );
  }
}

class CarEvent {
  CarEvent({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.date,
    required this.amount,
    this.odometer = 0,
    this.fuelType = 'Gasolina',
    this.liters = 0,
    this.pricePerLiter = 0,
    this.title = '',
    this.category = 'Other',
    this.note = '',
  });

  String id;
  String vehicleId;
  String type;
  String date;
  String fuelType;
  String title;
  String category;
  String note;
  double amount;
  double odometer;
  double liters;
  double pricePerLiter;

  bool get fuel => type == 'fuel';

  factory CarEvent.fromMap(Map<String, dynamic> map) {
    final rawType = '${_firstValue(map, ['type', 'kind']) ?? 'expense'}'.toLowerCase();
    return CarEvent(
      id: '${_firstValue(map, ['id', 'eventId']) ?? 'event-${DateTime.now().microsecondsSinceEpoch}'}',
      vehicleId: '${_firstValue(map, ['vehicleId', 'vehicle_id']) ?? 'vehicle-1'}',
      type: rawType == 'fuel' || rawType == 'abastecimento' ? 'fuel' : 'expense',
      date: _safeDate(_firstValue(map, ['date', 'eventDate', 'createdAt'])),
      amount: _number(_firstValue(map, ['amount', 'total', 'value'])),
      odometer: _number(_firstValue(map, ['odometer', 'odometerKm', 'km', 'mileage'])),
      fuelType: '${_firstValue(map, ['fuelType', 'fuel_type']) ?? 'Gasolina'}',
      liters: _number(_firstValue(map, ['liters', 'quantity'])),
      pricePerLiter: _number(_firstValue(map, ['pricePerLiter', 'price_per_liter'])),
      title: '${_firstValue(map, ['title', 'description', 'name']) ?? ''}',
      category: '${_firstValue(map, ['category', 'categoryId']) ?? 'Other'}',
      note: '${_firstValue(map, ['note', 'place', 'location']) ?? ''}',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicleId': vehicleId,
        'type': type,
        'date': date,
        'amount': amount,
        'odometer': odometer,
        'fuelType': fuelType,
        'liters': liters,
        'pricePerLiter': pricePerLiter,
        'title': title,
        'category': category,
        'note': note,
      };
}

class CarVehicle {
  CarVehicle({
    required this.id,
    required this.name,
    this.model = '',
    this.plate = '',
    this.odometer = 0,
  });

  String id;
  String name;
  String model;
  String plate;
  double odometer;

  factory CarVehicle.fromMap(Map<String, dynamic> map) => CarVehicle(
        id: '${_firstValue(map, ['id', 'vehicleId', 'vehicle_id']) ?? 'vehicle-${DateTime.now().microsecondsSinceEpoch}'}',
        name: '${_firstValue(map, ['name', 'title']) ?? 'Meu carro'}',
        model: '${_firstValue(map, ['model', 'modelYear', 'model_year']) ?? ''}',
        plate: '${_firstValue(map, ['plate', 'licensePlate', 'license_plate']) ?? ''}',
        odometer: _number(_firstValue(map, ['odometer', 'odometerKm', 'km', 'mileage'])),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'model': model,
        'plate': plate,
        'odometer': odometer,
      };
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

Map<String, dynamic>? _tryDecodeMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final map = _asMap(jsonDecode(raw));
    return map.isEmpty ? null : map;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _carMap(Map<String, dynamic> data) {
  for (final key in ['car', 'vehicle', 'vehicles']) {
    final candidate = _asMap(data[key]);
    if (candidate.isNotEmpty) return candidate;
  }
  return data;
}

List<dynamic> _listValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (data[key] is List) return data[key] as List;
  }
  return [];
}

dynamic _firstValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (data.containsKey(key) && data[key] != null) return data[key];
  }
  return null;
}

String _safeDate(dynamic value) {
  final raw = '$value'.trim();
  if (raw.isEmpty || raw == 'null') return _isoToday();
  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})').firstMatch(raw);
  if (brazilian != null) return '${brazilian.group(3)}-${brazilian.group(2)}-${brazilian.group(1)}';
  return raw.length >= 10 ? raw.substring(0, 10) : _isoToday();
}

double _number(dynamic value) => double.tryParse('$value'.replaceAll(',', '.')) ?? 0;
String _isoToday() => DateFormat('yyyy-MM-dd').format(DateTime.now());
String _money(num value) => NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(value);
String _shortMoney(num value) {
  if (value.abs() >= 100000) return 'R\$ ${(value / 1000).toStringAsFixed(0)} mil';
  if (value.abs() >= 10000) return 'R\$ ${(value / 1000).toStringAsFixed(1)} mil';
  return _money(value);
}

DateTime? _parseDate(String value) =>
    DateTime.tryParse(value.length >= 10 ? '${value.substring(0, 10)}T12:00:00' : value);

String _dateLabel(String value) {
  final date = _parseDate(value);
  if (date == null) return 'Sem data';
  return DateFormat('dd MMM yyyy', 'pt_BR').format(date).replaceAll('.', '');
}

String _categoryLabel(String value) => {
      'Maintenance': 'Manutenção',
      'Insurance': 'Seguro',
      'Tax': 'Imposto',
      'Parking': 'Estacionamento',
      'Wash': 'Lavagem',
      'Fine': 'Multa',
      'Other': 'Outro',
    }[value] ?? value;

class CarHome extends StatefulWidget {
  const CarHome({super.key});

  @override
  State<CarHome> createState() => _CarHomeState();
}

class _CarHomeState extends State<CarHome> {
  final searchController = TextEditingController();
  List<CarVehicle> vehicles = [];
  List<CarEvent> events = [];
  String activeVehicle = '';
  String period = 'Tudo';
  String typeFilter = 'Todos';
  String categoryFilter = 'Todas';
  String sort = 'Mais recentes';
  String search = '';
  String loadError = '';
  int tab = 0;
  bool loading = true;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppUpdates(manual: false);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getBool('finanza_auto_dark_theme');
      if (savedTheme != null) _darkMode.value = savedTheme;
      final saved = prefs.getString('finanza_auto_flutter_state');
      final bundledData =
          _tryDecodeMap(await rootBundle.loadString('assets/finanza-auto-backup.json')) ??
              <String, dynamic>{};
      final savedData = _tryDecodeMap(saved);
      final bundledCar = _carMap(bundledData);
      final savedCar = savedData == null ? <String, dynamic>{} : _carMap(savedData);
      final savedEvents = _listValue(savedCar, ['events', 'items', 'records']);
      final bundledEvents = _listValue(bundledCar, ['events', 'items', 'records']);
      final useBundled = savedData == null ||
          (savedData['dataInitialized'] != true && savedEvents.isEmpty && bundledEvents.isNotEmpty);
      final data = useBundled ? bundledData : savedData;
      final car = _carMap(data ?? bundledData);
      final rawVehicles = _listValue(car, ['vehicles', 'vehicleList', 'items']);
      final rawEvents = _listValue(car, ['events', 'items', 'records']);
      final loadedVehicles = <CarVehicle>[];
      final loadedEvents = <CarEvent>[];
      for (final item in rawVehicles) {
        if (item is Map) loadedVehicles.add(CarVehicle.fromMap(item.cast<String, dynamic>()));
      }
      for (final item in rawEvents) {
        if (item is Map) loadedEvents.add(CarEvent.fromMap(item.cast<String, dynamic>()));
      }
      if (loadedVehicles.isEmpty) loadedVehicles.add(CarVehicle(id: 'vehicle-1', name: 'Meu carro'));
      final validVehicleIds = loadedVehicles.map((vehicle) => vehicle.id).toSet();
      for (final event in loadedEvents) {
        if (loadedVehicles.length == 1 || !validVehicleIds.contains(event.vehicleId)) {
          event.vehicleId = loadedVehicles.first.id;
        }
      }
      final savedActive = '${_firstValue(car, ['activeVehicleId', 'active_vehicle_id']) ?? ''}';
      final selected = loadedVehicles.any((vehicle) => vehicle.id == savedActive)
          ? savedActive
          : loadedVehicles.first.id;
      debugPrint(
          'Finanza Auto load: source=${useBundled ? 'bundle' : 'saved'} saved=${saved != null} vehicles=${loadedVehicles.length} events=${loadedEvents.length} selected=$selected');
      if (!mounted) return;
      setState(() {
        vehicles = loadedVehicles;
        events = loadedEvents;
        activeVehicle = selected;
        loading = false;
        loadError = '';
      });
    } catch (error, stack) {
      debugPrint('Finanza Auto load error: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() {
        vehicles = [CarVehicle(id: 'vehicle-1', name: 'Meu carro')];
        activeVehicle = 'vehicle-1';
        events = [];
        loading = false;
        loadError = 'Não foi possível carregar o backup local.';
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'finanza_auto_flutter_state',
      jsonEncode({
        'app': 'Finanza Auto',
        'version': '2.0',
        'dataInitialized': true,
        'car': {
          'vehicles': vehicles.map((vehicle) => vehicle.toMap()).toList(),
          'events': events.map((event) => event.toMap()).toList(),
          'activeVehicleId': activeVehicle,
        },
      }),
    );
  }

  CarVehicle get currentVehicle =>
      vehicles.firstWhere((vehicle) => vehicle.id == activeVehicle, orElse: () => vehicles.first);

  List<CarEvent> get filteredEvents {
    var result =
        events.where((event) => activeVehicle == 'all' || event.vehicleId == activeVehicle).toList();
    if (typeFilter == 'Abastecimentos') result = result.where((event) => event.fuel).toList();
    if (typeFilter == 'Despesas') result = result.where((event) => !event.fuel).toList();
    if (categoryFilter != 'Todas') {
      result = result
          .where((event) =>
              event.fuel ? event.fuelType == categoryFilter : _categoryLabel(event.category) == categoryFilter)
          .toList();
    }
    if (search.trim().isNotEmpty) {
      final term = search.toLowerCase().trim();
      result = result
          .where((event) => '${event.title} ${event.note} ${event.fuelType} ${event.category}'
              .toLowerCase()
              .contains(term))
          .toList();
    }
    if (period != 'Tudo') {
      final now = DateTime.now();
      result = result.where((event) {
        final date = _parseDate(event.date);
        if (date == null) return false;
        if (period == 'Mês atual') return date.year == now.year && date.month == now.month;
        final days = period == '30 dias' ? 30 : period == '90 dias' ? 90 : 365;
        return !date.isBefore(now.subtract(Duration(days: days)));
      }).toList();
    }
    result.sort((a, b) {
      if (sort == 'Maior valor') return b.amount.compareTo(a.amount);
      if (sort == 'Menor valor') return a.amount.compareTo(b.amount);
      if (sort == 'Maior km') return b.odometer.compareTo(a.odometer);
      if (sort == 'Menor km') return a.odometer.compareTo(b.odometer);
      final comparison = b.date.compareTo(a.date);
      return sort == 'Mais antigos' ? -comparison : comparison;
    });
    return result;
  }

  List<CarEvent> get allVehicleEvents =>
      events.where((event) => activeVehicle == 'all' || event.vehicleId == activeVehicle).toList();

  double _total(List<CarEvent> list) =>
      list.fold<double>(0, (sum, event) => sum + event.amount);

  double _fuelTotal(List<CarEvent> list) =>
      _total(list.where((event) => event.fuel).toList());

  double _expenseTotal(List<CarEvent> list) =>
      _total(list.where((event) => !event.fuel).toList());

  double _liters(List<CarEvent> list) =>
      list.where((event) => event.fuel).fold<double>(0, (sum, event) => sum + event.liters);

  double _distance(List<CarEvent> list) {
    final readings =
        list.where((event) => event.fuel && event.odometer > 0).map((event) => event.odometer).toList();
    if (readings.length < 2) return 0;
    readings.sort();
    return readings.last - readings.first;
  }

  double _consumption(List<CarEvent> list) {
    final liters = _liters(list);
    final distance = _distance(list);
    return liters > 0 && distance > 0 ? distance / liters : 0;
  }

  double _maxOdometer(List<CarEvent> list) =>
      list.fold<double>(0, (max, event) => event.odometer > max ? event.odometer : max);

  String get _tabTitle => ['Visão geral', 'Histórico', 'Análises', 'Meu carro'][tab];

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia, Jefferson';
    if (hour < 18) return 'Boa tarde, Jefferson';
    return 'Boa noite, Jefferson';
  }

  String _periodBadgeText() {
    if (period == 'Mês atual') {
      try {
        return DateFormat('MMM', 'pt_BR')
            .format(DateTime.now())
            .toUpperCase()
            .replaceAll('.', '');
      } catch (_) {
        return 'MÊS';
      }
    }
    if (period == '30 dias') return '30D';
    if (period == '90 dias') return '90D';
    if (period == 'Ano atual') return '${DateTime.now().year}';
    return 'TUDO';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: ink,
        body: Center(child: CircularProgressIndicator(color: blue)),
      );
    }
    return Scaffold(
      backgroundColor: ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _nextTopBar(),
            if (loadError.isNotEmpty) _errorBanner(),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  _homeTab(),
                  _historyTab(),
                  _analyticsTab(),
                  _vehicleTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _glassBottomNavigation(),
    );
  }

  Widget _nextTopBar() {
    final isHome = tab == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHome ? 'Visão geral' : 'Finanza · Carro',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHome ? _greeting() : _tabTitle,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMain,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _quickActionChooserSheet,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
          if (isHome) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${currentVehicle.name} · ${_maxOdometer(allVehicleEvents).round()} km',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      color: textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _filterSheet,
                  tooltip: 'Filtros e veículo',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.tune_rounded, color: textMuted, size: 20),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _glassBottomNavigation() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF141416) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkTheme ? 0.35 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, 'Início'),
                _navItem(1, Icons.receipt_long_rounded, 'Histórico'),
                _navItem(2, Icons.insights_rounded, 'Análise'),
                _navItem(3, Icons.directions_car_rounded, 'Carro'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(int index, IconData icon, String label) {
    final active = tab == index;
    return GestureDetector(
      onTap: () => setState(() => tab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: active
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? (isDarkTheme ? const Color(0xFF25252B) : const Color(0xFF1E1E22))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active
                  ? Colors.white
                  : (isDarkTheme ? const Color(0xFF7E7E84) : const Color(0xFF8E8E93)),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: coral.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: coral.withOpacity(.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: coral, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loadError,
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  color: Color(0xffffb0a4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _homeTab() {
    final list = filteredEvents;
    final total = _total(list);
    return RefreshIndicator(
      color: blue,
      backgroundColor: panel,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _centralDeRecursosPill(),
          const SizedBox(height: 14),
          _heroCardGlass(list, total),
          const SizedBox(height: 14),
          _ritmoSemanalCard(list),
          const SizedBox(height: 14),
          _ritmoMensalCard(list),
          const SizedBox(height: 14),
          _chartCard(list),
          const SizedBox(height: 20),
          _ultimasTransacoesHeader(),
          const SizedBox(height: 10),
          _recentList(list),
        ],
      ),
    );
  }

  Widget _centralDeRecursosPill() => InkWell(
        onTap: _quickActionChooserSheet,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF141416) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDarkTheme ? const Color(0xFF222226) : const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  size: 20,
                  color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Central do veículo',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Planejamento, consumo e manutenções',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.history_rounded, size: 20, color: textMuted),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: textMuted),
            ],
          ),
        ),
      );

  Widget _heroCardGlass(List<CarEvent> list, double total) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'GASTOS NO PERÍODO',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF222226) : const Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _periodBadgeText(),
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      color: textMain,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _money(total),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  color: textMain,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Combustível',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _money(_fuelTotal(list)),
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Despesas',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _money(_expenseTotal(list)),
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
              color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
              height: 1,
            ),
            const SizedBox(height: 12),
            Text(
              '${list.length} lançamento(s) considerados no período.',
              style: TextStyle(
                fontFamily: 'DM Sans',
                color: isDarkTheme ? const Color(0xFF66666A) : const Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  Widget _ritmoSemanalCard(List<CarEvent> list) {
    final distance = _distance(list);
    final consumption = _consumption(list);
    final costPerKm = distance > 0 ? _total(list) / distance : 0.0;
    final fuelEvents = list.where((e) => e.fuel && e.pricePerLiter > 0).toList();
    final avgPrice = fuelEvents.isNotEmpty
        ? fuelEvents.fold<double>(0, (s, e) => s + e.pricePerLiter) / fuelEvents.length
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: textMain),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eficiência e consumo',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Indicadores de desempenho',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: textMuted),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _microCard(
                  label: 'Consumo médio',
                  value: consumption > 0
                      ? '${consumption.toStringAsFixed(1).replaceAll('.', ',')} km/l'
                      : '—',
                  valueColor: consumption > 0 ? const Color(0xFF4ADE80) : textMain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _microCard(
                  label: 'Custo por km',
                  value: costPerKm > 0
                      ? '-R\$ ${costPerKm.toStringAsFixed(2).replaceAll('.', ',')}'
                      : '—',
                  wineTint: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _microCard(
                  label: 'Km rodados',
                  value: distance > 0 ? '${distance.round()} km' : '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _microCard(
                  label: 'Preço médio / L',
                  value: avgPrice > 0
                      ? 'R\$ ${avgPrice.toStringAsFixed(2).replaceAll('.', ',')}'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${list.length} lançamento(s) considerados no período.',
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: isDarkTheme ? const Color(0xFF66666A) : const Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ritmoMensalCard(List<CarEvent> list) {
    final now = DateTime.now();
    final monthList = allVehicleEvents.where((e) {
      final d = _parseDate(e.date);
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
    final monthSpent = _total(monthList);
    final dailyAvg = monthSpent > 0 ? monthSpent / (now.day > 0 ? now.day : 1) : 0.0;
    final currentOdo = _maxOdometer(allVehicleEvents);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_circle_outlined, size: 18, color: textMain),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revisão e alertas',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Manutenção preventiva do Astra',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: textMuted),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _microCard(
                  label: 'Troca de óleo',
                  value: 'em 2.800 km',
                  wineTint: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _microCard(
                  label: 'Gasto no mês',
                  value: monthSpent > 0 ? '-${_money(monthSpent)}' : 'R\$ 0,00',
                  wineTint: monthSpent > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _microCard(
                  label: 'Média diária',
                  value: dailyAvg > 0 ? '-${_money(dailyAvg)}' : 'R\$ 0,00',
                  wineTint: dailyAvg > 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _microCard(
                  label: 'Hodômetro atual',
                  value: currentOdo > 0 ? '${currentOdo.round()} km' : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Próxima revisão recomendada aos ${(currentOdo > 0 ? (currentOdo + 2800).round() : 165000)} km.',
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: isDarkTheme ? const Color(0xFF66666A) : const Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _microCard({
    required String label,
    required String value,
    Color? valueColor,
    bool wineTint = false,
  }) {
    Color bg;
    Color labelCol;
    Color valCol;

    if (wineTint) {
      bg = isDarkTheme ? const Color(0xFF271416) : const Color(0xFFFEE2E2);
      labelCol = isDarkTheme ? const Color(0xFFFFAAAA) : const Color(0xFFDC2626);
      valCol = isDarkTheme ? const Color(0xFFFF5555) : const Color(0xFFB91C1C);
    } else {
      bg = isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF1F3F6);
      labelCol = textMuted;
      valCol = valueColor ?? textMain;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: labelCol,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: valCol,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle, {Widget? trailing}) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      );

  Widget _periodDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: strokeColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: period,
            dropdownColor: panelRaised,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 16),
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: textMain,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            items: ['Tudo', 'Mês atual', '30 dias', '90 dias', 'Ano atual']
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) => setState(() => period = value ?? period),
          ),
        ),
      );

  Widget _chartCard(List<CarEvent> list) {
    final chart = _chartValues(list);
    final maxValue = chart.values.fold<double>(0, (max, value) => value > max ? value : max);
    final totalChart = chart.values.fold<double>(0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 18, color: textMain),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolução mensal',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Gastos nos últimos 6 meses',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _shortMoney(totalChart),
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  color: textMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (maxValue == 0)
            SizedBox(
              height: 110,
              child: Center(
                child: Text(
                  'Ainda não há gastos registrados',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: chart.entries.map((entry) {
                  final height = maxValue == 0 ? 4.0 : 88 * entry.value / maxValue;
                  final isPositive = entry.value > 0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 28,
                        height: height.clamp(4.0, 88.0).toDouble(),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isPositive
                              ? (isDarkTheme ? const Color(0xFF2A2A32) : const Color(0xFFD1D5DB))
                              : (isDarkTheme ? const Color(0xFF1A1A1E) : const Color(0xFFF1F3F6)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          Divider(
            color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
            height: 1,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Total no período recente',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  color: textMuted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                _money(totalChart),
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  color: textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, double> _chartValues(List<CarEvent> list) {
    final dates = list.map((event) => _parseDate(event.date)).whereType<DateTime>().toList();
    final end = dates.isEmpty ? DateTime.now() : dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final result = <String, double>{};
    for (var index = 5; index >= 0; index--) {
      final date = DateTime(end.year, end.month - index, 1);
      final key = DateFormat('MMM', 'pt_BR').format(date).replaceAll('.', '');
      result[key] = list.where((event) {
        final eventDate = _parseDate(event.date);
        return eventDate != null && eventDate.year == date.year && eventDate.month == date.month;
      }).fold<double>(0, (sum, event) => sum + event.amount);
    }
    return result;
  }

  Widget _ultimasTransacoesHeader() => Row(
        children: [
          Text(
            'Últimos lançamentos',
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => tab = 1),
            child: Text(
              'Ver todos',
              style: TextStyle(
                fontFamily: 'DM Sans',
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );

  Widget _recentList(List<CarEvent> list) => list.isEmpty
      ? _emptyState('Nenhum lançamento ainda', 'Use o botão + no topo para começar.')
      : Column(children: list.take(5).map(_glassEventTile).toList());

  Widget _glassEventTile(CarEvent event) {
    final icon = event.fuel ? Icons.local_gas_station_rounded : _expenseIcon(event.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _entrySheet(fuel: event.fuel, edit: event),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF141416) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF1F3F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.fuel
                          ? '${event.fuelType} · ${event.liters.toStringAsFixed(1).replaceAll('.', ',')} L'
                          : (event.title.isEmpty ? _categoryLabel(event.category) : event.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _dateLabel(event.date),
                        if (event.odometer > 0) '${event.odometer.round()} km',
                        if (event.note.isNotEmpty) event.note,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '-${_money(event.amount)}',
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  color: Color(0xFFFF5555),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickActionChooserSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkTheme ? const Color(0xFF141416) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF333338) : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Central de Ações',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: Icon(Icons.close_rounded, color: textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _actionTile(
                icon: Icons.local_gas_station_rounded,
                title: 'Registrar abastecimento',
                subtitle: 'Litros, preço por litro, combustível e odômetro',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _entrySheet(fuel: true);
                },
              ),
              _actionTile(
                icon: Icons.build_rounded,
                title: 'Registrar manutenção ou serviço',
                subtitle: 'Troca de óleo, revisão, peças, oficina',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _entrySheet(fuel: false);
                },
              ),
              _actionTile(
                icon: Icons.receipt_long_rounded,
                title: 'Lançamento rápido de despesa',
                subtitle: 'Pedágio, lava-rápido, estacionamento ou taxas',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _quickExpenseSheet();
                },
              ),
              _actionTile(
                icon: Icons.directions_car_rounded,
                title: 'Gerenciar veículo e odômetro',
                subtitle: 'Atualizar quilometragem e configurações',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _vehicleSheet(currentVehicle);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkTheme ? const Color(0xFF26262C) : const Color(0x0F000000),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF27272E) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: textMain, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
              ],
            ),
          ),
        ),
      );

  Future<void> _filterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkTheme ? const Color(0xFF141416) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkTheme ? const Color(0xFF333338) : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtros e Veículo',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(Icons.close_rounded, color: textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'VEÍCULO ATIVO',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: vehicles.map((v) {
                    final isSel = activeVehicle == v.id;
                    return ChoiceChip(
                      label: Text(v.name),
                      selected: isSel,
                      onSelected: (val) async {
                        if (val) {
                          setState(() => activeVehicle = v.id);
                          setSheetState(() {});
                          await _save();
                        }
                      },
                      labelStyle: TextStyle(
                        fontFamily: 'DM Sans',
                        color: isSel ? Colors.white : textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      selectedColor: isDarkTheme ? const Color(0xFF25252B) : const Color(0xFF0F172A),
                      backgroundColor: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF1F3F6),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'PERÍODO',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Tudo', 'Mês atual', '30 dias', '90 dias', 'Ano atual'].map((p) {
                    final isSel = period == p;
                    return ChoiceChip(
                      label: Text(p),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) {
                          setState(() => period = p);
                          setSheetState(() {});
                        }
                      },
                      labelStyle: TextStyle(
                        fontFamily: 'DM Sans',
                        color: isSel ? Colors.white : textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      selectedColor: isDarkTheme ? const Color(0xFF25252B) : const Color(0xFF0F172A),
                      backgroundColor: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF1F3F6),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'TEMA',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _toggleTheme();
                          setSheetState(() {});
                        },
                        icon: Icon(
                          isDarkTheme ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 18,
                        ),
                        label: Text(isDarkTheme ? 'Mudar para tema claro' : 'Mudar para tema escuro'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textMain,
                          side: BorderSide(
                            color: isDarkTheme ? const Color(0xFF26262C) : const Color(0x1F000000),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _historyTab() {
    final list = filteredEvents;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        _pageIntro(
          'Histórico completo',
          '${allVehicleEvents.length} registros salvos neste dispositivo',
          Icons.receipt_long_rounded,
          blue,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          onChanged: (value) => setState(() => search = value),
          decoration: InputDecoration(
            hintText: 'Buscar por posto, categoria ou descrição...',
            prefixIcon: Icon(Icons.search_rounded, color: textMuted),
          ),
        ),
        const SizedBox(height: 12),
        _filterChips(),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '${list.length} resultados encontrados',
              style: TextStyle(
                fontFamily: 'DM Sans',
                color: textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _sortDropdown(),
          ],
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          _emptyState('Nada encontrado', 'Tente mudar o filtro ou registrar um novo lançamento.')
        else
          ...list.map(_glassEventTile),
      ],
    );
  }

  Widget _filterChips() {
    final values = ['Todos', 'Abastecimentos', 'Despesas'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: values.map((value) {
          final selected = typeFilter == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(value),
              selected: selected,
              onSelected: (_) => setState(() => typeFilter = value),
              selectedColor: blue.withOpacity(0.18),
              backgroundColor: panel,
              side: BorderSide(
                color: selected ? blue.withOpacity(0.6) : strokeColor,
              ),
              labelStyle: TextStyle(
                fontFamily: 'DM Sans',
                color: selected ? (isDarkTheme ? Colors.white : blue) : textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sortDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: strokeColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: sort,
            dropdownColor: panelRaised,
            icon: Icon(Icons.swap_vert_rounded, color: textMuted, size: 16),
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            items: ['Mais recentes', 'Mais antigos', 'Maior valor', 'Menor valor', 'Maior km', 'Menor km']
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) => setState(() => sort = value ?? sort),
          ),
        ),
      );

  Widget _analyticsTab() {
    final list = filteredEvents;
    final fuel = _fuelTotal(list);
    final expense = _expenseTotal(list);
    final fuelTypes = <String, double>{};
    final places = <String, int>{};
    for (final event in list.where((event) => event.fuel)) {
      fuelTypes[event.fuelType] = (fuelTypes[event.fuelType] ?? 0) + event.amount;
      if (event.note.trim().isNotEmpty) places[event.note.trim()] = (places[event.note.trim()] ?? 0) + 1;
    }
    final orderedPlaces = places.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final orderedFuel = fuelTypes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        _pageIntro(
          'Análises do carro',
          'Entenda para onde seu dinheiro está indo',
          Icons.insights_rounded,
          blue,
        ),
        const SizedBox(height: 16),
        _analysisSummary(fuel, expense, list),
        const SizedBox(height: 20),
        _sectionTitle('Gasto por mês', 'Acompanhe a evolução do custo total'),
        const SizedBox(height: 10),
        _chartCard(list),
        const SizedBox(height: 20),
        _sectionTitle('Combustível', 'Distribuição do que foi abastecido'),
        const SizedBox(height: 10),
        _breakdownCard(orderedFuel, fuel, Icons.local_gas_station_rounded, mint),
        const SizedBox(height: 20),
        _sectionTitle('Onde você abastece', 'Postos e locais mais frequentes'),
        const SizedBox(height: 10),
        _placesCard(orderedPlaces),
        const SizedBox(height: 20),
        _sectionTitle('Manutenção preventiva', 'Próximos cuidados para não esquecer'),
        const SizedBox(height: 10),
        _maintenanceCard(list),
      ],
    );
  }

  Widget _analysisSummary(double fuel, double expense, List<CarEvent> list) => GlassPanel(
        radius: 20,
        opacity: isDarkTheme ? .88 : .96,
        blur: 16,
        borderColor: strokeColor,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _summaryValue('Total', _money(fuel + expense), textMain)),
                Expanded(child: _summaryValue('Combustível', _money(fuel), mint)),
                Expanded(child: _summaryValue('Despesas', _money(expense), coral)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${list.length} lançamentos analisados · ${_distance(list).round()} km acompanhados',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      color: textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _summaryValue(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      );

  Widget _breakdownCard(
    List<MapEntry<String, double>> items,
    double total,
    IconData icon,
    Color color,
  ) {
    if (items.isEmpty) {
      return _emptyState('Sem abastecimentos', 'Os dados aparecerão aqui quando forem registrados.');
    }
    return GlassPanel(
      radius: 20,
      opacity: isDarkTheme ? .88 : .96,
      blur: 16,
      borderColor: strokeColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: items.take(4).map((item) {
          final ratio = total > 0 ? item.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      item.key,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _money(item.value),
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: strokeColor,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _placesCard(List<MapEntry<String, int>> places) {
    if (places.isEmpty) {
      return _emptyState(
        'Sem locais registrados',
        'O posto ou local aparece quando você informa uma observação.',
      );
    }
    return GlassPanel(
      radius: 20,
      opacity: isDarkTheme ? .88 : .96,
      blur: 16,
      borderColor: strokeColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: places.take(5).toList().asMap().entries.map((entry) {
          final item = entry.value;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: blue.withOpacity(.12),
              child: Text(
                '${entry.key + 1}',
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  color: blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              item.key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'DM Sans',
                color: textMain,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Text(
              '${item.value}x',
              style: TextStyle(
                fontFamily: 'DM Sans',
                color: textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _maintenanceCard(List<CarEvent> list) {
    final expenses = list.where((event) => !event.fuel).toList()..sort((a, b) => b.amount.compareTo(a.amount));
    final service = list.where((event) {
      if (event.fuel) return false;
      final text = '${event.title} ${event.note}'.toLowerCase();
      return ['oleo', 'óleo', 'filtro', 'revis', 'troca'].any(text.contains);
    }).toList()
      ..sort((a, b) => '${a.date}${a.odometer}'.compareTo('${b.date}${b.odometer}'));
    final latestService = service.isEmpty ? null : service.last;
    final currentOdometer = _maxOdometer(list);
    final nextService = latestService != null && latestService.odometer > 0 ? latestService.odometer + 5000 : 0.0;
    final serviceLabel = latestService == null || nextService == 0
        ? 'Registre troca de óleo ou revisão'
        : currentOdometer >= nextService
            ? 'Revisão atrasada · ${currentOdometer.round() - nextService.round()} km'
            : '${(nextService - currentOdometer).round()} km restantes';
    return GlassPanel(
      radius: 20,
      opacity: isDarkTheme ? .88 : .96,
      blur: 16,
      borderColor: strokeColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: amber.withOpacity(.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.build_circle_outlined, color: amber, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cuidados do veículo',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _maintenanceLine(
            'Maior despesa registrada',
            expenses.isEmpty
                ? 'Nenhuma ainda'
                : '${_categoryLabel(expenses.first.category)} · ${_money(expenses.first.amount)}',
          ),
          const SizedBox(height: 8),
          _maintenanceLine('Último hodômetro conhecido', '${currentOdometer.round()} km'),
          const SizedBox(height: 8),
          _maintenanceLine('Próxima revisão', serviceLabel),
        ],
      ),
    );
  }

  Widget _maintenanceLine(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: panelSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: strokeColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  color: textMuted,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  color: textMain,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _vehicleTab() {
    final list = allVehicleEvents;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        _pageIntro(
          'Seu veículo',
          'Cadastro, desempenho e dados locais',
          Icons.directions_car_rounded,
          amber,
        ),
        const SizedBox(height: 18),
        GlassPanel(
          radius: 24,
          opacity: isDarkTheme ? .88 : .96,
          blur: 18,
          borderColor: strokeColor,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: amber.withOpacity(.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: amber.withOpacity(.20)),
                    ),
                    child: const Icon(Icons.directions_car_rounded, color: amber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentVehicle.name,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            color: textMain,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentVehicle.model.isEmpty ? 'Modelo não informado' : currentVehicle.model,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _vehicleSheet(currentVehicle),
                    icon: Icon(Icons.edit_outlined, color: textMuted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: panelSoft.withOpacity(isDarkTheme ? 0.6 : 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: strokeColor),
                ),
                child: Row(
                  children: [
                    Expanded(child: _vehicleInfo('Hodômetro', '${_maxOdometer(list).round()} km')),
                    Container(width: 1, height: 28, color: strokeColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _vehicleInfo('Registros', '${list.length}'),
                      ),
                    ),
                    Container(width: 1, height: 28, color: strokeColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _vehicleInfo('Placa', currentVehicle.plate.isEmpty ? '—' : currentVehicle.plate),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _sectionTitle(
          'Meus veículos',
          'Toque para alternar o veículo ativo',
          trailing: IconButton(
            onPressed: () => _vehicleSheet(),
            icon: const Icon(Icons.add_circle_outline_rounded, color: blue),
          ),
        ),
        const SizedBox(height: 10),
        ...vehicles.map((vehicle) => _vehicleRow(vehicle)),
        const SizedBox(height: 22),
        _sectionTitle('Dados e backup', 'Tudo fica salvo localmente no aparelho'),
        const SizedBox(height: 10),
        GlassPanel(
          radius: 20,
          opacity: isDarkTheme ? .88 : .96,
          blur: 16,
          borderColor: strokeColor,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mint.withOpacity(.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: mint, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dados somente neste dispositivo',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            color: textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sem sincronização externa ou conta obrigatória.',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            color: textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_user_outlined, color: mint, size: 18),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyBackup,
                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                      label: const Text('Copiar JSON'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMain,
                        side: BorderSide(color: strokeColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _restoreBackup,
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: const Text('Restaurar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: blue,
                        side: BorderSide(color: blue.withOpacity(.35)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _sectionTitle('Atualizações do aplicativo', 'Mantenha o Finanza Auto sempre atualizado'),
        const SizedBox(height: 10),
        _appUpdateCard(),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Fonte: CSV Drivvo · ${events.length} registros importados',
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: textSoft,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _appUpdateCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cloud_sync_rounded, color: textMain, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Versão instalada: v$appVersion',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atualizações distribuídas diretamente via GitHub',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _checkingUpdate ? null : () => _checkAppUpdates(manual: true),
                    icon: _checkingUpdate
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: textMain),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(_checkingUpdate ? 'Verificando...' : 'Verificar atualizações'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textMain,
                      side: BorderSide(
                        color: isDarkTheme ? const Color(0xFF26262C) : const Color(0x1F000000),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                        fontFamily: 'DM Sans',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _checkAppUpdates({bool manual = false}) async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final info = await UpdaterService.checkUpdate(
        currentVersion: appVersion,
        currentBuild: appBuildNumber,
      );
      if (!mounted) return;
      if (info != null && info.hasUpdate) {
        _showUpdateDialog(info);
      } else if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFF0F172A),
            content: Text(
              'Você já está na versão mais recente (v$appVersion).',
              style: const TextStyle(fontFamily: 'DM Sans', color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo info) async {
    double progress = 0.0;
    bool downloading = false;
    String statusText = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkTheme ? const Color(0xFF141416) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkTheme ? const Color(0xFF333338) : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDarkTheme ? const Color(0xFF1E1E22) : const Color(0xFFF1F3F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: isDarkTheme ? Colors.white : Colors.black,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Nova versão disponível',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  color: textMain,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'v${info.version}',
                                  style: const TextStyle(
                                    fontFamily: 'DM Sans',
                                    color: Color(0xFF34C759),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Versão atual instalada: v$appVersion',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              color: textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF1A1A1E) : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkTheme ? const Color(0xFF222226) : const Color(0x14000000),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOVIDADES',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        info.releaseNotes,
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMain,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (downloading) ...[
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            statusText.isEmpty ? 'Baixando atualização...' : statusText,
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              color: textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              color: textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress > 0 ? progress : null,
                          minHeight: 6,
                          backgroundColor: isDarkTheme ? const Color(0xFF25252B) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: downloading
                            ? null
                            : () async {
                                setSheetState(() {
                                  downloading = true;
                                  statusText = 'Baixando APK...';
                                });
                                final filePath = await UpdaterService.downloadApk(
                                  info.downloadUrl,
                                  onProgress: (p) {
                                    setSheetState(() => progress = p);
                                  },
                                );
                                if (filePath != null) {
                                  setSheetState(() {
                                    statusText = 'Abrindo instalador...';
                                  });
                                  final installed = await UpdaterService.installApk(filePath);
                                  if (!installed && mounted) {
                                    await UpdaterService.openInBrowser(info.downloadUrl);
                                  }
                                } else {
                                  setSheetState(() {
                                    downloading = false;
                                    statusText = 'Falha no download direto. Tente pelo navegador.';
                                  });
                                  if (mounted) {
                                    await UpdaterService.openInBrowser(info.downloadUrl);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                          foregroundColor: isDarkTheme ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          downloading ? 'Instalando...' : 'Instalar atualização',
                          style: const TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => UpdaterService.openInBrowser(info.downloadUrl),
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text('Baixar pelo navegador'),
                        style: TextButton.styleFrom(
                          foregroundColor: textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: TextButton.styleFrom(
                        foregroundColor: textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        textStyle: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Depois'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageIntro(String title, String subtitle, IconData icon, Color color) => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(.18)),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    color: textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _vehicleInfo(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: textMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: textMain,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );

  Widget _vehicleRow(CarVehicle vehicle) {
    final selected = vehicle.id == activeVehicle;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          setState(() => activeVehicle = vehicle.id);
          await _save();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? blue.withOpacity(.12) : panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? blue.withOpacity(.45) : strokeColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.directions_car_outlined,
                color: selected ? blue : textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: selected ? blue : textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      vehicle.model.isEmpty ? 'Modelo não informado' : vehicle.model,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle_rounded, color: blue, size: 19),
              IconButton(
                onPressed: () => _vehicleSheet(vehicle),
                icon: Icon(Icons.more_horiz_rounded, color: textSoft, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: strokeColor),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: textSoft, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'DM Sans',
                color: textMain,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DM Sans',
                color: textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

  IconData _expenseIcon(String category) =>
      {
        'Maintenance': Icons.build_rounded,
        'Insurance': Icons.shield_outlined,
        'Tax': Icons.description_outlined,
        'Parking': Icons.local_parking_rounded,
        'Wash': Icons.water_drop_outlined,
        'Fine': Icons.warning_amber_rounded,
      }[category] ??
      Icons.receipt_long_outlined;

  Future<void> _toggleTheme() async {
    _darkMode.value = !_darkMode.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('finanza_auto_dark_theme', isDarkTheme);
    if (mounted) _snack(isDarkTheme ? 'Tema escuro ativado.' : 'Tema claro ativado.');
  }

  Future<void> _copyBackup() async {
    final backup = JsonEncoder.withIndent('  ').convert({
      'app': 'Finanza Auto',
      'version': '2.0',
      'car': {
        'vehicles': vehicles.map((vehicle) => vehicle.toMap()).toList(),
        'events': events.map((event) => event.toMap()).toList(),
        'activeVehicleId': activeVehicle,
      },
    });
    await Clipboard.setData(ClipboardData(text: backup));
    _snack('Backup copiado. Guarde o JSON em um arquivo seguro.');
  }

  Future<void> _restoreBackup() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) {
      _snack('Nenhum JSON encontrado na área de transferência.');
      return;
    }
    try {
      final decoded = _tryDecodeMap(raw);
      if (decoded == null) throw const FormatException('invalid backup');
      final car = _carMap(decoded);
      final loadedVehicles = <CarVehicle>[];
      final loadedEvents = <CarEvent>[];
      for (final item in _listValue(car, ['vehicles', 'vehicleList', 'items'])) {
        if (item is Map) loadedVehicles.add(CarVehicle.fromMap(item.cast<String, dynamic>()));
      }
      for (final item in _listValue(car, ['events', 'items', 'records'])) {
        if (item is Map) loadedEvents.add(CarEvent.fromMap(item.cast<String, dynamic>()));
      }
      if (loadedVehicles.isEmpty) loadedVehicles.add(CarVehicle(id: 'vehicle-1', name: 'Meu carro'));
      final validIds = loadedVehicles.map((vehicle) => vehicle.id).toSet();
      for (final event in loadedEvents) {
        if (loadedVehicles.length == 1 || !validIds.contains(event.vehicleId)) {
          event.vehicleId = loadedVehicles.first.id;
        }
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: panelRaised,
          title: const Text('Restaurar backup?'),
          content: Text(
            '${loadedEvents.length} registros e ${loadedVehicles.length} veículo(s) substituirão os dados atuais deste aparelho.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: blue),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() {
        vehicles = loadedVehicles;
        events = loadedEvents;
        activeVehicle = loadedVehicles.first.id;
      });
      await _save();
      _snack('Backup restaurado com sucesso!');
    } catch (_) {
      _snack('O conteúdo copiado não é um backup válido do Finanza Auto.');
    }
  }

  Future<void> _deleteEvent(CarEvent event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panelRaised,
        title: const Text('Excluir lançamento?'),
        content: const Text('Esta ação remove o registro somente deste dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: coral),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    setState(() => events.removeWhere((item) => item.id == event.id));
    await _save();
    _snack('Lançamento excluído.');
  }

  Future<void> _quickExpenseSheet() async {
    final amount = TextEditingController();
    final title = TextEditingController();
    var category = 'Other';
    final categories = <String, String>{
      'Maintenance': 'Manutenção',
      'Insurance': 'Seguro',
      'Tax': 'Imposto / documento',
      'Parking': 'Estacionamento',
      'Wash': 'Lavagem',
      'Fine': 'Multa',
      'Other': 'Outro',
    };
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: textSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Lançamento rápido',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              color: textMain,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close_rounded, color: textMuted),
                        ),
                      ],
                    ),
                    Text(
                      'Registre um gasto rápido sem preencher detalhes adicionais.',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Valor pago',
                        prefixText: 'R\$ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        prefixIcon: Icon(Icons.category_outlined, size: 18),
                      ),
                      items: categories.entries
                          .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                          .toList(),
                      onChanged: (value) => setModalState(() => category = value ?? category),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Descrição rápida (opcional)',
                        hintText: 'Ex.: Estacionamento shopping',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final value = _number(amount.text);
                          if (value <= 0) {
                            _snack('Informe um valor válido.');
                            return;
                          }
                          final event = CarEvent(
                            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                            vehicleId: activeVehicle,
                            type: 'expense',
                            date: _isoToday(),
                            amount: value,
                            odometer: _maxOdometer(allVehicleEvents),
                            title: title.text.trim().isEmpty ? _categoryLabel(category) : title.text.trim(),
                            category: category,
                            note: 'Lançamento rápido',
                          );
                          setState(() => events.insert(0, event));
                          await _save();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _snack('Despesa salva com sucesso.');
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Salvar agora'),
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      amount.dispose();
      title.dispose();
    }
  }

  Widget _formRow(List<Widget> children) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);

  Future<void> _entrySheet({required bool fuel, CarEvent? edit}) async {
    final date = TextEditingController(text: edit?.date ?? _isoToday());
    final odo = TextEditingController(
      text: edit == null || edit.odometer == 0 ? '' : edit.odometer.round().toString(),
    );
    final liters = TextEditingController(
      text: edit == null || edit.liters == 0 ? '' : edit.liters.toString(),
    );
    final price = TextEditingController(
      text: edit == null || edit.pricePerLiter == 0 ? '' : edit.pricePerLiter.toString(),
    );
    final amount = TextEditingController(
      text: edit == null || edit.amount == 0 ? '' : edit.amount.toStringAsFixed(2),
    );
    final title = TextEditingController(text: edit?.title ?? '');
    final note = TextEditingController(text: edit?.note ?? '');
    var selectedFuel = edit?.fuelType ?? 'Etanol';
    var selectedCategory = edit?.category ?? 'Maintenance';
    final categories = <String, String>{
      'Maintenance': 'Manutenção',
      'Insurance': 'Seguro',
      'Tax': 'Imposto / documento',
      'Parking': 'Estacionamento',
      'Wash': 'Lavagem',
      'Fine': 'Multa',
      'Other': 'Outro',
    };
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final calculated = _number(liters.text) * _number(price.text);
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: textSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              edit == null
                                  ? (fuel ? 'Novo abastecimento' : 'Nova despesa')
                                  : 'Editar lançamento',
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                color: textMain,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: Icon(Icons.close_rounded, color: textMuted),
                          ),
                        ],
                      ),
                      Text(
                        fuel
                            ? 'Registre o abastecimento para acompanhar o consumo médio.'
                            : 'Mantenha todas as despesas do carro organizadas em um só lugar.',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _formRow([
                        Expanded(
                          child: TextField(
                            controller: date,
                            readOnly: true,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                initialDate: _parseDate(date.text) ?? DateTime.now(),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.dark(
                                      primary: blue,
                                      surface: panelRaised,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                date.text = DateFormat('yyyy-MM-dd').format(picked);
                                setModalState(() {});
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Data',
                              prefixIcon: Icon(Icons.calendar_today_outlined, size: 17),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: odo,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Hodômetro',
                              suffixText: 'km',
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      if (fuel) ...[
                        DropdownButtonFormField<String>(
                          value: selectedFuel,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de combustível',
                            prefixIcon: Icon(Icons.local_gas_station_outlined, size: 18),
                          ),
                          items: ['Etanol', 'Gasolina', 'Diesel', 'GNV', 'Flex']
                              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) => setModalState(() => selectedFuel = value ?? selectedFuel),
                        ),
                        const SizedBox(height: 12),
                        _formRow([
                          Expanded(
                            child: TextField(
                              controller: liters,
                              onChanged: (_) => setModalState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Litros'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: price,
                              onChanged: (_) => setModalState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Preço / litro',
                                prefixText: 'R\$ ',
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Total pago',
                            prefixText: 'R\$ ',
                            hintText: calculated > 0 ? calculated.toStringAsFixed(2) : null,
                          ),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            prefixIcon: Icon(Icons.category_outlined, size: 18),
                          ),
                          items: categories.entries
                              .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                              .toList(),
                          onChanged: (value) => setModalState(() => selectedCategory = value ?? selectedCategory),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Valor pago', prefixText: 'R\$ '),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: title,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            hintText: 'Ex.: Troca de óleo, IPVA, Seguro...',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: note,
                        decoration: InputDecoration(
                          labelText: fuel ? 'Posto ou observação' : 'Observação adicional',
                          hintText: fuel ? 'Ex.: Posto Shell Centro' : 'Detalhes opcionais',
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final value = _number(amount.text) > 0 ? _number(amount.text) : calculated;
                            if (value <= 0) {
                              _snack('Informe um valor válido.');
                              return;
                            }
                            final event = edit ??
                                CarEvent(
                                  id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                                  vehicleId: activeVehicle,
                                  type: fuel ? 'fuel' : 'expense',
                                  date: date.text,
                                  amount: value,
                                );
                            event.vehicleId = activeVehicle;
                            event.type = fuel ? 'fuel' : 'expense';
                            event.date = date.text.isEmpty ? _isoToday() : date.text;
                            event.amount = value;
                            event.odometer = _number(odo.text);
                            event.liters = _number(liters.text);
                            event.pricePerLiter = _number(price.text);
                            event.fuelType = selectedFuel;
                            event.title = title.text.trim();
                            event.category = selectedCategory;
                            event.note = note.text.trim();
                            setState(() {
                              if (edit == null) events.insert(0, event);
                              final vehicle = currentVehicle;
                              if (event.odometer > vehicle.odometer) {
                                vehicle.odometer = event.odometer;
                              }
                            });
                            await _save();
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                            _snack(edit == null ? 'Lançamento salvo com sucesso.' : 'Lançamento atualizado.');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          child: Text(edit == null ? 'Salvar lançamento' : 'Salvar alterações'),
                        ),
                      ),
                      if (edit != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _deleteEvent(edit);
                              },
                              icon: const Icon(Icons.delete_outline_rounded, color: coral, size: 17),
                              label: const Text(
                                'Excluir lançamento',
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  color: coral,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    } finally {
      for (final controller in [date, odo, liters, price, amount, title, note]) {
        controller.dispose();
      }
    }
  }

  Future<void> _deleteVehicle(CarVehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panelRaised,
        title: const Text('Excluir veículo?'),
        content: const Text('Os registros vinculados a este veículo também serão removidos deste dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: coral),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      vehicles.removeWhere((item) => item.id == vehicle.id);
      events.removeWhere((event) => event.vehicleId == vehicle.id);
      activeVehicle = vehicles.first.id;
    });
    await _save();
    _snack('Veículo excluído.');
  }

  Future<void> _vehicleSheet([CarVehicle? edit]) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final model = TextEditingController(text: edit?.model ?? '');
    final plate = TextEditingController(text: edit?.plate ?? '');
    final odometer = TextEditingController(
      text: edit == null || edit.odometer == 0 ? '' : edit.odometer.round().toString(),
    );
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          edit == null ? 'Adicionar veículo' : 'Editar veículo',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            color: textMain,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close_rounded, color: textMuted),
                      ),
                    ],
                  ),
                  Text(
                    'Cadastre os dados para organizar o histórico dos seus veículos.',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      color: textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nome do veículo',
                      hintText: 'Ex.: Astra, Gol, Moto...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _formRow([
                    Expanded(
                      child: TextField(
                        controller: model,
                        decoration: const InputDecoration(
                          labelText: 'Modelo / ano',
                          hintText: 'Ex.: 2.0 2011',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: plate,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Placa',
                          hintText: 'ABC1D23',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: odometer,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hodômetro atual',
                      suffixText: 'km',
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (name.text.trim().isEmpty) {
                          _snack('Informe um nome para o veículo.');
                          return;
                        }
                        setState(() {
                          if (edit == null) {
                            final vehicle = CarVehicle(
                              id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                              name: name.text.trim(),
                              model: model.text.trim(),
                              plate: plate.text.trim(),
                              odometer: _number(odometer.text),
                            );
                            vehicles.add(vehicle);
                            activeVehicle = vehicle.id;
                          } else {
                            edit.name = name.text.trim();
                            edit.model = model.text.trim();
                            edit.plate = plate.text.trim();
                            edit.odometer = _number(odometer.text);
                          }
                        });
                        await _save();
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        _snack(edit == null ? 'Veículo adicionado com sucesso.' : 'Veículo atualizado.');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      child: Text(edit == null ? 'Adicionar veículo' : 'Salvar alterações'),
                    ),
                  ),
                  if (edit != null && vehicles.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await _deleteVehicle(edit);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: coral, size: 17),
                          label: const Text(
                            'Excluir veículo',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              color: coral,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      for (final controller in [name, model, plate, odometer]) {
        controller.dispose();
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
        ),
        backgroundColor: panelRaised,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _MetricData {
  _MetricData(this.label, this.value, this.caption, this.color, this.icon);
  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;
}
