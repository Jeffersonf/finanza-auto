import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Finanza Next modern theme, with the same light/dark tokens as the native app.
final ValueNotifier<bool> _darkMode = ValueNotifier<bool>(false);
bool get isDarkTheme => _darkMode.value;
Color get ink => isDarkTheme ? Color(0xff000000) : Color(0xfff2f2f7);
Color get panel => isDarkTheme ? Color(0xff1c1c1e) : Color(0xffffffff);
Color get panelSoft => isDarkTheme ? Color(0xff2c2c2e) : Color(0xffe5e5ea);
Color get panelRaised => isDarkTheme ? Color(0xff3a3a40) : Color(0xffffffff);
const lime = Color(0xffd2f668);
const mint = Color(0xff34c759);
const amber = Color(0xffff9f0a);
const coral = Color(0xffff453a);
const blue = Color(0xff0a84ff);
Color get textMain => isDarkTheme ? Color(0xfff7f7fa) : Color(0xff111114);
Color get textMuted => isDarkTheme ? Color(0xffb0b0b7) : Color(0xff77777e);
Color get textSoft => isDarkTheme ? Color(0xff636366) : Color(0xffaeaeb2);

class GlassPanel extends StatelessWidget {
  GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.tint,
    this.opacity = .66,
    this.blur = 20,
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
            border: Border.all(color: borderColor ?? (isDarkTheme ? Color(0x2bffffff) : Color(0x18000000))),
            boxShadow: shadows ?? [BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    // O Next usa um canvas limpo. O glass fica reservado aos componentes,
    // sem halos decorativos competindo com os dados.
    return SizedBox.shrink();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(FinanzaAutoApp());
}

class FinanzaAutoApp extends StatelessWidget {
  FinanzaAutoApp({super.key});

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
        textTheme: TextTheme(
          headlineLarge: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: dark ? Brightness.dark : Brightness.light).copyWith(
          primary: blue,
          onPrimary: Colors.white,
          secondary: mint,
          surface: panel,
          onSurface: textMain,
          surfaceVariant: panelSoft,
          onSurfaceVariant: textMuted,
          outline: isDarkTheme ? Color(0xff636366) : Color(0xffaeaeb2),
        ),
        appBarTheme: AppBarTheme(backgroundColor: ink, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panelSoft,
          labelStyle: TextStyle(color: textMuted),
          hintStyle: TextStyle(color: textSoft),
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: isDarkTheme ? Color(0x16ffffff) : Color(0x16000000))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: blue, width: 1.2)),
        ),
        dividerTheme: DividerThemeData(color: isDarkTheme ? Color(0x16ffffff) : Color(0x16000000), space: 1),
      ),
      home: CarHome(),
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
  CarVehicle({required this.id, required this.name, this.model = '', this.plate = '', this.odometer = 0});

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

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'model': model, 'plate': plate, 'odometer': odometer};
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

DateTime? _parseDate(String value) => DateTime.tryParse(value.length >= 10 ? '${value.substring(0, 10)}T12:00:00' : value);

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
  CarHome({super.key});

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

  @override
  void initState() {
    super.initState();
    _load();
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
      final bundledData = _tryDecodeMap(await rootBundle.loadString('assets/finanza-auto-backup.json')) ?? <String, dynamic>{};
      final savedData = _tryDecodeMap(saved);
      final bundledCar = _carMap(bundledData);
      final savedCar = savedData == null ? <String, dynamic>{} : _carMap(savedData);
      final savedEvents = _listValue(savedCar, ['events', 'items', 'records']);
      final bundledEvents = _listValue(bundledCar, ['events', 'items', 'records']);
      final useBundled = savedData == null || (savedData['dataInitialized'] != true && savedEvents.isEmpty && bundledEvents.isNotEmpty);
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
        if (loadedVehicles.length == 1 || !validVehicleIds.contains(event.vehicleId)) event.vehicleId = loadedVehicles.first.id;
      }
      final savedActive = '${_firstValue(car, ['activeVehicleId', 'active_vehicle_id']) ?? ''}';
      final selected = loadedVehicles.any((vehicle) => vehicle.id == savedActive) ? savedActive : loadedVehicles.first.id;
      debugPrint('Finanza Auto load: source=${useBundled ? 'bundle' : 'saved'} saved=${saved != null} vehicles=${loadedVehicles.length} events=${loadedEvents.length} selected=$selected firstEventVehicle=${loadedEvents.isEmpty ? '-' : loadedEvents.first.vehicleId}');
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

  CarVehicle get currentVehicle => vehicles.firstWhere((vehicle) => vehicle.id == activeVehicle, orElse: () => vehicles.first);

  List<CarEvent> get filteredEvents {
    var result = events.where((event) => activeVehicle == 'all' || event.vehicleId == activeVehicle).toList();
    if (typeFilter == 'Abastecimentos') result = result.where((event) => event.fuel).toList();
    if (typeFilter == 'Despesas') result = result.where((event) => !event.fuel).toList();
    if (categoryFilter != 'Todas') result = result.where((event) => event.fuel ? event.fuelType == categoryFilter : _categoryLabel(event.category) == categoryFilter).toList();
    if (search.trim().isNotEmpty) {
      final term = search.toLowerCase().trim();
      result = result.where((event) => '${event.title} ${event.note} ${event.fuelType} ${event.category}'.toLowerCase().contains(term)).toList();
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

  List<CarEvent> get allVehicleEvents => events.where((event) => activeVehicle == 'all' || event.vehicleId == activeVehicle).toList();
  double _total(List<CarEvent> list) => list.fold<double>(0, (sum, event) => sum + event.amount);
  double _fuelTotal(List<CarEvent> list) => _total(list.where((event) => event.fuel).toList());
  double _expenseTotal(List<CarEvent> list) => _total(list.where((event) => !event.fuel).toList());
  double _liters(List<CarEvent> list) => list.where((event) => event.fuel).fold<double>(0, (sum, event) => sum + event.liters);

  double _distance(List<CarEvent> list) {
    final readings = list.where((event) => event.fuel && event.odometer > 0).map((event) => event.odometer).toList();
    if (readings.length < 2) return 0;
    readings.sort();
    return readings.last - readings.first;
  }

  double _consumption(List<CarEvent> list) {
    final liters = _liters(list);
    final distance = _distance(list);
    return liters > 0 && distance > 0 ? distance / liters : 0;
  }

  double _maxOdometer(List<CarEvent> list) => list.fold<double>(0, (max, event) => event.odometer > max ? event.odometer : max);
  String get _tabTitle => ['Visão geral', 'Histórico', 'Análises', 'Meu carro'][tab];

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(body: Center(child: CircularProgressIndicator(color: lime)));
    return Scaffold(
      backgroundColor: ink,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _AmbientBackdrop()),
            Column(children: [
              _nextTopBar(),
              if (loadError.isNotEmpty) _errorBanner(),
              Expanded(child: IndexedStack(index: tab, children: [_homeTab(), _historyTab(), _analyticsTab(), _vehicleTab()])),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: _glassBottomNavigation(),
      floatingActionButton: FloatingActionButton(
        onPressed: _quickExpenseSheet,
        backgroundColor: blue,
        foregroundColor: Colors.white,
        child: Icon(Icons.bolt_rounded),
        tooltip: 'Lançamento rápido',
      ),
    );
  }

  Widget _topBar() {
    return Padding(padding: EdgeInsets.fromLTRB(20, 15, 14, 10), child: Row(children: [
      Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: Color(0x22c8f55a), blurRadius: 16)]), child: Text('F', style: TextStyle(color: Color(0xff101607), fontWeight: FontWeight.w900, fontSize: 21))),
      SizedBox(width: 11),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('finanza.', style: TextStyle(fontFamily: 'Syne', color: textMain, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.5)), Text(_tabTitle, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w500))]),
           Spacer(),
           IconButton(onPressed: _toggleTheme, tooltip: isDarkTheme ? 'Usar tema claro' : 'Usar tema escuro', icon: Icon(isDarkTheme ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: textMuted)),
           PopupMenuButton<String>(tooltip: 'Mais opções', color: panelRaised, icon: Icon(Icons.more_horiz_rounded, color: textMuted), onSelected: (value) { if (value == 'backup') _copyBackup(); if (value == 'restore') _restoreBackup(); if (value == 'vehicle') _vehicleSheet(); }, itemBuilder: (context) => [PopupMenuItem(value: 'backup', child: Text('Copiar backup local')), PopupMenuItem(value: 'restore', child: Text('Restaurar backup')), PopupMenuItem(value: 'vehicle', child: Text('Adicionar veículo'))]),
    ]));
  }

  Widget _nextTopBar() => Padding(
        padding: EdgeInsets.fromLTRB(20, 15, 14, 9),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MÓDULO DE VEÍCULO', style: TextStyle(color: isDarkTheme ? lime : Color(0xff3f7d00), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.15)),
            SizedBox(height: 5),
            Text(_tabTitle, style: TextStyle(fontFamily: 'Syne', color: textMain, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -.7)),
          ])),
          IconButton(onPressed: _toggleTheme, tooltip: isDarkTheme ? 'Usar tema claro' : 'Usar tema escuro', icon: Icon(isDarkTheme ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: textMuted)),
          PopupMenuButton<String>(tooltip: 'Mais opções', color: panelRaised, icon: Icon(Icons.more_horiz_rounded, color: textMuted), onSelected: (value) { if (value == 'backup') _copyBackup(); if (value == 'restore') _restoreBackup(); if (value == 'vehicle') _vehicleSheet(); }, itemBuilder: (context) => [PopupMenuItem(value: 'backup', child: Text('Copiar backup local')), PopupMenuItem(value: 'restore', child: Text('Restaurar backup')), PopupMenuItem(value: 'vehicle', child: Text('Adicionar veículo'))]),
        ]),
      );

  Widget _glassTopBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GlassPanel(
        radius: 22,
        opacity: .48,
        blur: 24,
        borderColor: Colors.white.withOpacity(.13),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: lime.withOpacity(.20), blurRadius: 20)]), child: Text('F', style: TextStyle(color: Color(0xff101607), fontWeight: FontWeight.w900, fontSize: 21))),
          SizedBox(width: 11),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('finanza.', style: TextStyle(fontFamily: 'Syne', color: textMain, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.5)), Text(_tabTitle, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w500))]),
          Spacer(),
          PopupMenuButton<String>(tooltip: 'Mais opções', color: panelRaised, icon: Icon(Icons.more_horiz_rounded, color: textMuted), onSelected: (value) { if (value == 'backup') _copyBackup(); if (value == 'restore') _restoreBackup(); if (value == 'vehicle') _vehicleSheet(); }, itemBuilder: (context) => [PopupMenuItem(value: 'backup', child: Text('Copiar backup local')), PopupMenuItem(value: 'restore', child: Text('Restaurar backup')), PopupMenuItem(value: 'vehicle', child: Text('Adicionar veículo'))]),
        ]),
      ),
    );
  }

  Widget _glassBottomNavigation() => SafeArea(top: false, child: Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 10), child: GlassPanel(radius: 25, opacity: isDarkTheme ? .82 : .90, blur: 28, borderColor: isDarkTheme ? Colors.white.withOpacity(.16) : Colors.black.withOpacity(.08), padding: EdgeInsets.all(5), child: NavigationBar(height: 62, selectedIndex: tab, onDestinationSelected: (index) => setState(() => tab = index), backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, elevation: 0, indicatorColor: isDarkTheme ? Color(0x803a3a40) : Color(0xff1c1c1e), labelTextStyle: MaterialStatePropertyAll(TextStyle(color: textMain, fontSize: 10, fontWeight: FontWeight.w600)), destinations: [NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded, color: Colors.white), label: 'Início'), NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: Colors.white), label: 'Histórico'), NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights, color: Colors.white), label: 'Análises'), NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car, color: Colors.white), label: 'Carro')]))));

  Widget _errorBanner() => Container(width: double.infinity, margin: EdgeInsets.fromLTRB(20, 0, 20, 8), padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(color: coral.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: coral.withOpacity(.25))), child: Row(children: [Icon(Icons.info_outline_rounded, color: coral, size: 17), SizedBox(width: 8), Expanded(child: Text(loadError, style: TextStyle(color: Color(0xffffb0a4), fontSize: 12)))]));

  Widget _bottomNavigation() => NavigationBar(height: 68, selectedIndex: tab, onDestinationSelected: (index) => setState(() => tab = index), backgroundColor: panel, surfaceTintColor: Colors.transparent, elevation: 0, indicatorColor: Color(0xff3a3a40), labelTextStyle: MaterialStatePropertyAll(TextStyle(color: textMain, fontSize: 10, fontWeight: FontWeight.w600)), destinations: [NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded, color: Colors.white), label: 'Início'), NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: Colors.white), label: 'Histórico'), NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights, color: Colors.white), label: 'Análises'), NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car, color: Colors.white), label: 'Carro')]);

  Widget _homeTab() {
    final list = filteredEvents;
    final total = _total(list);
    return RefreshIndicator(color: lime, backgroundColor: panel, onRefresh: _load, child: ListView(physics: AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _glassVehicleSwitcher(),
      SizedBox(height: 16),
      _heroCardGlass(list, total),
      SizedBox(height: 22),
      _sectionTitle('Resumo do período', 'Tudo que foi registrado no carro', trailing: _periodDropdown()),
      SizedBox(height: 11),
      _metricsGrid(list),
      SizedBox(height: 23),
      _sectionTitle('Atalhos', 'Registre um novo movimento em segundos'),
      SizedBox(height: 11),
      _quickActions(),
      SizedBox(height: 23),
      _sectionTitle('Evolução dos gastos', 'Últimos meses com dados registrados', trailing: Text(_shortMoney(total), style: TextStyle(color: lime, fontWeight: FontWeight.w800, fontSize: 13))),
      SizedBox(height: 11),
      _chartCard(list),
      SizedBox(height: 23),
      _sectionTitle('Lançamentos recentes', 'Os últimos movimentos do veículo', trailing: TextButton(onPressed: () => setState(() => tab = 1), child: Text('Ver todos'))),
      SizedBox(height: 8),
      _recentList(list),
    ]));
  }

  Widget _vehicleSwitcher() => Row(children: [Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: mint.withOpacity(.12), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.directions_car_rounded, size: 19, color: mint)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currentVehicle.name, style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w700)), Text(currentVehicle.model.isEmpty ? 'Seu veículo principal' : currentVehicle.model, style: TextStyle(color: textMuted, fontSize: 11))])), PopupMenuButton<String>(tooltip: 'Trocar veículo', onSelected: (value) async { setState(() => activeVehicle = value); await _save(); }, color: panelRaised, icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted), itemBuilder: (context) => vehicles.map((vehicle) => PopupMenuItem(value: vehicle.id, child: Text(vehicle.name))).toList())]);

  Widget _glassVehicleSwitcher() => GlassPanel(
        radius: 20,
        opacity: isDarkTheme ? .90 : .96,
        blur: 18,
        borderColor: isDarkTheme ? Colors.white.withOpacity(.10) : Colors.black.withOpacity(.07),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: mint.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: mint.withOpacity(.18))), child: Icon(Icons.directions_car_rounded, size: 19, color: mint)),
          SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currentVehicle.name, style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w700)), Text(currentVehicle.model.isEmpty ? 'Seu veículo principal' : currentVehicle.model, style: TextStyle(color: textMuted, fontSize: 11))])),
          PopupMenuButton<String>(tooltip: 'Trocar veículo', onSelected: (value) async { setState(() => activeVehicle = value); await _save(); }, color: panelRaised, icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted), itemBuilder: (context) => vehicles.map((vehicle) => PopupMenuItem(value: vehicle.id, child: Text(vehicle.name))).toList()),
        ]),
      );

  Widget _heroCard(List<CarEvent> list, double total) => Container(padding: EdgeInsets.fromLTRB(20, 20, 20, 17), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withOpacity(.14))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: lime.withOpacity(.13), borderRadius: BorderRadius.circular(9)), child: Text('VISÃO GERAL', style: TextStyle(color: lime, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1))), Spacer(), Icon(Icons.auto_awesome_rounded, color: textMain, size: 20)]), SizedBox(height: 20), Text(_money(total), style: TextStyle(fontFamily: 'Syne', color: textMain, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2)), SizedBox(height: 5), Text('${list.length} registros em ${period.toLowerCase()}', style: TextStyle(color: textMuted, fontSize: 12)), SizedBox(height: 18), Row(children: [Expanded(child: _heroStat('Combustível', _money(_fuelTotal(list)), amber)), Container(width: 1, height: 32, color: Colors.white.withOpacity(.12)), Expanded(child: Padding(padding: EdgeInsets.only(left: 16), child: _heroStat('Despesas', _money(_expenseTotal(list)), coral)))]), SizedBox(height: 17), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _entrySheet(fuel: true), icon: Icon(Icons.add_rounded, size: 18), label: Text('Registrar abastecimento'), style: FilledButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)), textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))))]));
  Widget _heroCardGlass(List<CarEvent> list, double total) => GlassPanel(
        radius: 28,
        opacity: .94,
        blur: 18,
        borderColor: Colors.white.withOpacity(.12),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff1c1c1e), Color(0xff202024)]),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withOpacity(.10))), child: Text('VISÃO GERAL', style: TextStyle(color: lime, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1))), Spacer(), Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withOpacity(.07), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18))]),
            SizedBox(height: 22),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_money(total), maxLines: 1, style: TextStyle(fontFamily: 'Syne', color: Colors.white, fontSize: 35, fontWeight: FontWeight.w800, letterSpacing: -1.2))),
            SizedBox(height: 5),
            Text('${list.length} registros em ${period.toLowerCase()}', style: TextStyle(color: Color(0xffaeaeb2), fontSize: 12)),
            SizedBox(height: 20),
            Row(children: [Expanded(child: _heroStat('Combustível', _money(_fuelTotal(list)), amber)), Container(width: 1, height: 32, color: Colors.white.withOpacity(.14)), Expanded(child: Padding(padding: EdgeInsets.only(left: 16), child: _heroStat('Despesas', _money(_expenseTotal(list)), coral)))]),
            SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _entrySheet(fuel: true), icon: Icon(Icons.add_rounded, size: 18), label: Text('Registrar abastecimento'), style: FilledButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)), textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)))),
        ]),
      );

  Widget _heroStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: isDarkTheme ? textMuted : Color(0xffaeaeb2), fontSize: 11)), SizedBox(height: 3), Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800))]);

  Widget _sectionTitle(String title, String subtitle, {Widget? trailing}) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontFamily: 'Syne', color: textMain, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.3)), SizedBox(height: 3), Text(subtitle, style: TextStyle(color: textMuted, fontSize: 11))])), if (trailing != null) trailing]);
  Widget _periodDropdown() => DropdownButtonHideUnderline(child: DropdownButton<String>(value: period, dropdownColor: panelRaised, icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 18), style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.w700), items: ['Tudo', 'Mês atual', '30 dias', '90 dias', 'Ano atual'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => period = value ?? period)));

  Widget _metricsGrid(List<CarEvent> list) {
    final distance = _distance(list);
    final consumption = _consumption(list);
    final cards = [
      _MetricData('Km acompanhados', distance > 0 ? '${distance.round()} km' : '—', distance > 0 ? 'entre abastecimentos' : 'sem leituras suficientes', mint, Icons.route_rounded),
      _MetricData('Consumo médio', consumption > 0 ? '${consumption.toStringAsFixed(1).replaceAll('.', ',')} km/l' : '—', _liters(list) > 0 ? '${_liters(list).toStringAsFixed(0)} L registrados' : 'sem litros registrados', lime, Icons.speed_rounded),
      _MetricData('Custo por km', distance > 0 ? _money(_total(list) / distance) : '—', 'combustível + despesas', amber, Icons.payments_outlined),
      _MetricData('Hodômetro', '${_maxOdometer(allVehicleEvents).round()} km', 'maior leitura importada', coral, Icons.dashboard_outlined),
    ];
    return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.27, children: cards.map(_glassMetricCard).toList());
  }

  Widget _glassMetricCard(_MetricData data) => GlassPanel(
        radius: 20,
        opacity: isDarkTheme ? .90 : .96,
        blur: 18,
        borderColor: data.color.withOpacity(.18),
        padding: EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 31, height: 31, alignment: Alignment.center, decoration: BoxDecoration(color: data.color.withOpacity(.14), borderRadius: BorderRadius.circular(11), border: Border.all(color: data.color.withOpacity(.18))), child: Icon(data.icon, color: data.color, size: 16)), Spacer(), Icon(Icons.arrow_outward_rounded, color: textSoft.withOpacity(.85), size: 14)]),
          Spacer(),
          Text(data.label.toUpperCase(), style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)),
          SizedBox(height: 4),
          Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: data.color, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.5)),
          SizedBox(height: 3),
          Text(data.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textSoft, fontSize: 10)),
        ]),
      );

  Widget _metricCard(_MetricData data) => Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 29, height: 29, alignment: Alignment.center, decoration: BoxDecoration(color: data.color.withOpacity(.12), borderRadius: BorderRadius.circular(9)), child: Icon(data.icon, color: data.color, size: 16)), Spacer(), Icon(Icons.arrow_outward_rounded, color: textSoft.withOpacity(.7), size: 14)]), Spacer(), Text(data.label.toUpperCase(), style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)), SizedBox(height: 4), Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: data.color, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.5)), SizedBox(height: 3), Text(data.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textSoft, fontSize: 10))]));

  Widget _quickActions() => Row(children: [Expanded(child: _glassQuickAction(Icons.local_gas_station_rounded, 'Abastecer', 'Combustível', mint, () => _entrySheet(fuel: true))), SizedBox(width: 10), Expanded(child: _glassQuickAction(Icons.build_rounded, 'Adicionar', 'Despesa', coral, () => _entrySheet(fuel: false))), SizedBox(width: 10), Expanded(child: _glassQuickAction(Icons.edit_rounded, 'Editar', 'Veículo', amber, () => _vehicleSheet(currentVehicle)))]);

  Widget _glassQuickAction(IconData icon, String title, String caption, Color color, VoidCallback action) => InkWell(onTap: action, borderRadius: BorderRadius.circular(18), child: GlassPanel(radius: 18, opacity: isDarkTheme ? .90 : .96, blur: 18, borderColor: color.withOpacity(.15), padding: EdgeInsets.fromLTRB(10, 13, 8, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(11), border: Border.all(color: color.withOpacity(.18))), child: Icon(icon, color: color, size: 18)), SizedBox(height: 11), Text(title, style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800)), SizedBox(height: 2), Text(caption, style: TextStyle(color: textSoft, fontSize: 10)), SizedBox(height: 2), Align(alignment: Alignment.centerRight, child: Icon(Icons.arrow_forward_rounded, color: color.withOpacity(.72), size: 14))])));
  Widget _quickAction(IconData icon, String title, String caption, Color color, VoidCallback action) => InkWell(onTap: action, borderRadius: BorderRadius.circular(16), child: Container(padding: EdgeInsets.fromLTRB(10, 13, 8, 12), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)), SizedBox(height: 11), Text(title, style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800)), SizedBox(height: 2), Text(caption, style: TextStyle(color: textSoft, fontSize: 10))])));

  Widget _chartCard(List<CarEvent> list) {
    final chart = _chartValues(list);
    final maxValue = chart.values.fold<double>(0, (max, value) => value > max ? value : max);
    return Container(padding: EdgeInsets.fromLTRB(16, 17, 16, 13), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(19), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: [if (maxValue == 0) SizedBox(height: 116, child: Center(child: Text('Ainda não há gastos neste período', style: TextStyle(color: textMuted, fontSize: 12)))) else SizedBox(height: 145, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceAround, children: chart.entries.map((entry) { final height = maxValue == 0 ? 4.0 : 102 * entry.value / maxValue; return Column(mainAxisAlignment: MainAxisAlignment.end, children: [Container(width: 24, height: height.clamp(4.0, 102.0).toDouble(), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [mint, lime]))), SizedBox(height: 8), Text(entry.key, style: TextStyle(color: textSoft, fontSize: 10))]); }).toList())), Divider(height: 20), Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: mint, shape: BoxShape.circle)), SizedBox(width: 7), Text('Gasto mensal', style: TextStyle(color: textMuted, fontSize: 11)), Spacer(), Text(_money(chart.values.fold<double>(0, (sum, value) => sum + value)), style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800))]) ]));
  }

  Map<String, double> _chartValues(List<CarEvent> list) {
    final dates = list.map((event) => _parseDate(event.date)).whereType<DateTime>().toList();
    final end = dates.isEmpty ? DateTime.now() : dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final result = <String, double>{};
    for (var index = 5; index >= 0; index--) {
      final date = DateTime(end.year, end.month - index, 1);
      final key = DateFormat('MMM', 'pt_BR').format(date).replaceAll('.', '');
      result[key] = list.where((event) { final eventDate = _parseDate(event.date); return eventDate != null && eventDate.year == date.year && eventDate.month == date.month; }).fold<double>(0, (sum, event) => sum + event.amount);
    }
    return result;
  }

  Widget _recentList(List<CarEvent> list) => list.isEmpty ? _emptyState('Nenhum lançamento ainda', 'Use um dos atalhos acima para começar.') : Column(children: list.take(5).map(_glassEventTile).toList());

  Widget _eventTile(CarEvent event) {
    final color = event.fuel ? mint : coral;
    final icon = event.fuel ? Icons.local_gas_station_rounded : _expenseIcon(event.category);
    return Container(margin: EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.06))), child: ListTile(onTap: () => _entrySheet(fuel: event.fuel, edit: event), contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 3), leading: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 19)), title: Text(event.fuel ? '${event.fuelType} · ${event.liters.toStringAsFixed(1)} L' : (event.title.isEmpty ? _categoryLabel(event.category) : event.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w700)), subtitle: Text([_dateLabel(event.date), if (event.odometer > 0) '${event.odometer.round()} km', if (event.note.isNotEmpty) event.note].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMuted, fontSize: 10)), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_money(event.amount), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('Editar', style: TextStyle(color: textSoft, fontSize: 9))])));
  }

  Widget _glassEventTile(CarEvent event) {
    final color = event.fuel ? mint : coral;
    final icon = event.fuel ? Icons.local_gas_station_rounded : _expenseIcon(event.category);
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _entrySheet(fuel: event.fuel, edit: event),
        borderRadius: BorderRadius.circular(18),
        child: GlassPanel(
          radius: 18,
          opacity: isDarkTheme ? .90 : .96,
          blur: 18,
          borderColor: color.withOpacity(.13),
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(children: [
            Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withOpacity(.16))), child: Icon(icon, color: color, size: 19)),
            SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.fuel ? '${event.fuelType} · ${event.liters.toStringAsFixed(1)} L' : (event.title.isEmpty ? _categoryLabel(event.category) : event.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text([_dateLabel(event.date), if (event.odometer > 0) '${event.odometer.round()} km', if (event.note.isNotEmpty) event.note].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMuted, fontSize: 10)),
            ])),
            SizedBox(width: 8),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_money(event.amount), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('Editar', style: TextStyle(color: textSoft, fontSize: 9))]),
          ]),
        ),
      ),
    );
  }

  Widget _historyTab() {
    final list = filteredEvents;
    return ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _pageIntro('Histórico completo', '${allVehicleEvents.length} registros salvos neste dispositivo', Icons.receipt_long_rounded, mint),
      SizedBox(height: 17),
      TextField(controller: searchController, onChanged: (value) => setState(() => search = value), decoration: InputDecoration(hintText: 'Buscar por posto, categoria ou descrição', prefixIcon: Icon(Icons.search_rounded, color: textMuted))),
      SizedBox(height: 12),
      _filterChips(),
      SizedBox(height: 12),
      Row(children: [Text('${list.length} resultados', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700)), Spacer(), _sortDropdown()]),
      SizedBox(height: 9),
      if (list.isEmpty) _emptyState('Nada encontrado', 'Tente mudar o filtro ou registrar um novo lançamento.') else ...list.map(_glassEventTile),
    ]);
  }

  Widget _filterChips() {
    final values = ['Todos', 'Abastecimentos', 'Despesas'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: values.map((value) {
          final selected = typeFilter == value;
          return Padding(
            padding: EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(value),
              selected: selected,
              onSelected: (_) => setState(() => typeFilter = value),
              selectedColor: lime,
              backgroundColor: panel,
              side: BorderSide(color: selected ? lime : Colors.white.withOpacity(.08)),
              labelStyle: TextStyle(color: selected ? Color(0xff101607) : textMuted, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sortDropdown() => DropdownButtonHideUnderline(child: DropdownButton<String>(value: sort, dropdownColor: panelRaised, icon: Icon(Icons.swap_vert_rounded, color: textMuted, size: 16), style: TextStyle(color: textMuted, fontSize: 11), items: ['Mais recentes', 'Mais antigos', 'Maior valor', 'Menor valor', 'Maior km', 'Menor km'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => sort = value ?? sort)));

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
    return ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _pageIntro('Análises do carro', 'Entenda para onde seu dinheiro está indo', Icons.insights_rounded, lime),
      SizedBox(height: 17),
      _analysisSummary(fuel, expense, list),
      SizedBox(height: 19),
      _sectionTitle('Gasto por mês', 'Acompanhe a evolução do custo total'),
      SizedBox(height: 10),
      _chartCard(list),
      SizedBox(height: 19),
      _sectionTitle('Combustível', 'Distribuição do que foi abastecido'),
      SizedBox(height: 10),
      _breakdownCard(orderedFuel, fuel, Icons.local_gas_station_rounded, mint),
      SizedBox(height: 19),
      _sectionTitle('Onde você abastece', 'Postos e locais mais frequentes'),
      SizedBox(height: 10),
      _placesCard(orderedPlaces),
      SizedBox(height: 19),
      _sectionTitle('Manutenção preventiva', 'Próximos cuidados para não esquecer'),
      SizedBox(height: 10),
      _maintenanceCard(list),
    ]);
  }

  Widget _analysisSummary(double fuel, double expense, List<CarEvent> list) => Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: [Row(children: [Expanded(child: _summaryValue('Total', _money(fuel + expense), textMain)), Expanded(child: _summaryValue('Combustível', _money(fuel), mint)), Expanded(child: _summaryValue('Despesas', _money(expense), coral))]), SizedBox(height: 18), Row(children: [Icon(Icons.info_outline_rounded, size: 15, color: textMuted), SizedBox(width: 7), Expanded(child: Text('${list.length} lançamentos analisados · ${_distance(list).round()} km acompanhados', style: TextStyle(color: textMuted, fontSize: 11)))]) ]));
  Widget _summaryValue(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: textMuted, fontSize: 10)), SizedBox(height: 5), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900))]);

  Widget _breakdownCard(List<MapEntry<String, double>> items, double total, IconData icon, Color color) {
    if (items.isEmpty) return _emptyState('Sem abastecimentos', 'Os dados aparecerão aqui quando forem registrados.');
    return Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: items.take(4).map((item) { final ratio = total > 0 ? item.value / total : 0.0; return Padding(padding: EdgeInsets.only(bottom: 13), child: Column(children: [Row(children: [Icon(icon, color: color, size: 16), SizedBox(width: 8), Text(item.key, style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w700)), Spacer(), Text(_money(item.value), style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700))]), SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: Colors.white.withOpacity(.07), color: color))])); }).toList()));
  }

  Widget _placesCard(List<MapEntry<String, int>> places) {
    if (places.isEmpty) return _emptyState('Sem locais registrados', 'O posto ou local aparece quando você informa uma observação.');
    return Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: places.take(5).toList().asMap().entries.map((entry) { final item = entry.value; return ListTile(dense: true, leading: CircleAvatar(radius: 15, backgroundColor: mint.withOpacity(.11), child: Text('${entry.key + 1}', style: TextStyle(color: mint, fontSize: 11, fontWeight: FontWeight.w800))), title: Text(item.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w700)), trailing: Text('${item.value}x', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700))); }).toList()));
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
    return Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: amber.withOpacity(.13), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.build_circle_outlined, color: amber, size: 19)), SizedBox(width: 10), Expanded(child: Text('Cuidados do veículo', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w800))), Icon(Icons.chevron_right_rounded, color: textSoft)]), SizedBox(height: 14), _maintenanceLine('Maior despesa registrada', expenses.isEmpty ? 'Nenhuma ainda' : '${_categoryLabel(expenses.first.category)} · ${_money(expenses.first.amount)}'), SizedBox(height: 8), _maintenanceLine('Último hodômetro conhecido', '${currentOdometer.round()} km'), SizedBox(height: 8), _maintenanceLine('Próxima revisão', serviceLabel) ]));
  }

  Widget _maintenanceLine(String label, String value) => Container(padding: EdgeInsets.symmetric(horizontal: 11, vertical: 10), decoration: BoxDecoration(color: panelSoft, borderRadius: BorderRadius.circular(11)), child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: textMuted, fontSize: 10))), SizedBox(width: 8), Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: textMain, fontSize: 10, fontWeight: FontWeight.w700)))]));

  Widget _vehicleTab() {
    final list = allVehicleEvents;
    return ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _pageIntro('Seu veículo', 'Cadastro, desempenho e dados locais', Icons.directions_car_rounded, amber),
      SizedBox(height: 17),
      Container(padding: EdgeInsets.all(19), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(.14))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 45, height: 45, alignment: Alignment.center, decoration: BoxDecoration(color: amber.withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.directions_car_rounded, color: amber, size: 25)), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currentVehicle.name, style: TextStyle(fontFamily: 'Syne', color: textMain, fontSize: 20, fontWeight: FontWeight.w700)), Text(currentVehicle.model.isEmpty ? 'Modelo não informado' : currentVehicle.model, style: TextStyle(color: textMuted, fontSize: 12))])), IconButton(onPressed: () => _vehicleSheet(currentVehicle), icon: Icon(Icons.edit_outlined, color: textMuted))]), SizedBox(height: 20), Row(children: [Expanded(child: _vehicleInfo('Hodômetro', '${_maxOdometer(list).round()} km')), Expanded(child: _vehicleInfo('Registros', '${list.length}')), Expanded(child: _vehicleInfo('Placa', currentVehicle.plate.isEmpty ? '—' : currentVehicle.plate))]) ])),
      SizedBox(height: 19),
      _sectionTitle('Meus veículos', 'Toque para alternar o veículo ativo', trailing: IconButton(onPressed: () => _vehicleSheet(), icon: Icon(Icons.add_circle_outline_rounded, color: lime))),
      SizedBox(height: 9),
      ...vehicles.map((vehicle) => _vehicleRow(vehicle)),
      SizedBox(height: 19),
      _sectionTitle('Dados e backup', 'Tudo fica salvo localmente no aparelho'),
      SizedBox(height: 9),
      Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: [Row(children: [Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: mint.withOpacity(.12), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.lock_outline_rounded, color: mint, size: 19)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dados somente neste dispositivo', style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Sem sincronização externa ou conta obrigatória.', style: TextStyle(color: textMuted, fontSize: 10))])), Icon(Icons.verified_user_outlined, color: mint, size: 18)]), SizedBox(height: 13), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _copyBackup, icon: Icon(Icons.content_copy_rounded, size: 16), label: Text('Copiar JSON'), style: OutlinedButton.styleFrom(foregroundColor: textMain, side: BorderSide(color: Color(0x25ffffff)), padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))), SizedBox(width: 9), Expanded(child: OutlinedButton.icon(onPressed: _restoreBackup, icon: Icon(Icons.restore_rounded, size: 16), label: Text('Restaurar'), style: OutlinedButton.styleFrom(foregroundColor: mint, side: BorderSide(color: mint.withOpacity(.35)), padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))]) ])),
      SizedBox(height: 13),
      Center(child: Text('Fonte: CSV Drivvo · ${events.length} registros importados', style: TextStyle(color: textSoft, fontSize: 10))),
    ]);
  }

  Widget _pageIntro(String title, String subtitle, IconData icon, Color color) => Row(children: [Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 21)), SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontFamily: 'Syne', color: textMain, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.6)), SizedBox(height: 3), Text(subtitle, style: TextStyle(color: textMuted, fontSize: 11))]))]);
  Widget _vehicleInfo(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: textMuted, fontSize: 10)), SizedBox(height: 5), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800))]);

  Widget _vehicleRow(CarVehicle vehicle) {
    final selected = vehicle.id == activeVehicle;
    return InkWell(
      onTap: () async {
        setState(() => activeVehicle = vehicle.id);
        await _save();
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(color: selected ? lime.withOpacity(.1) : panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? lime.withOpacity(.35) : Colors.white.withOpacity(.06))),
        child: Row(children: [
          Icon(Icons.directions_car_outlined, color: selected ? lime : textMuted, size: 20),
          SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vehicle.name, style: TextStyle(color: selected ? lime : textMain, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(vehicle.model.isEmpty ? 'Modelo não informado' : vehicle.model, style: TextStyle(color: textMuted, fontSize: 10)),
          ])),
          if (selected) Icon(Icons.check_circle_rounded, color: lime, size: 19),
          IconButton(onPressed: () => _vehicleSheet(vehicle), icon: Icon(Icons.more_horiz_rounded, color: textSoft, size: 19)),
        ]),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) => Container(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 27), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withOpacity(.06))), child: Column(children: [Icon(Icons.inbox_outlined, color: textSoft, size: 28), SizedBox(height: 9), Text(title, style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 11))]));
  IconData _expenseIcon(String category) => {'Maintenance': Icons.build_rounded, 'Insurance': Icons.shield_outlined, 'Tax': Icons.description_outlined, 'Parking': Icons.local_parking_rounded, 'Wash': Icons.water_drop_outlined, 'Fine': Icons.warning_amber_rounded}[category] ?? Icons.receipt_long_outlined;

  Future<void> _toggleTheme() async {
    _darkMode.value = !_darkMode.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('finanza_auto_dark_theme', isDarkTheme);
    if (mounted) _snack(isDarkTheme ? 'Tema escuro ativado.' : 'Tema claro ativado.');
  }

  Future<void> _copyBackup() async {
    final backup = JsonEncoder.withIndent('  ').convert({'app': 'Finanza Auto', 'version': '2.0', 'car': {'vehicles': vehicles.map((vehicle) => vehicle.toMap()).toList(), 'events': events.map((event) => event.toMap()).toList(), 'activeVehicleId': activeVehicle}});
    await Clipboard.setData(ClipboardData(text: backup));
    _snack('Backup copiado. Cole em um arquivo seguro para guardar.');
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
      if (decoded == null) throw FormatException('invalid backup');
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
        if (loadedVehicles.length == 1 || !validIds.contains(event.vehicleId)) event.vehicleId = loadedVehicles.first.id;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: panelRaised,
          title: Text('Restaurar backup?'),
          content: Text('${loadedEvents.length} registros e ${loadedVehicles.length} veículo(s) substituirão os dados atuais.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Restaurar')),
          ],
        ),
      );
      if (confirmed != true) return;
      final savedActive = '${_firstValue(car, ['activeVehicleId', 'active_vehicle_id']) ?? ''}';
      setState(() {
        vehicles = loadedVehicles;
        events = loadedEvents;
        activeVehicle = validIds.contains(savedActive) ? savedActive : loadedVehicles.first.id;
      });
      await _save();
      _snack('Backup restaurado com sucesso.');
    } catch (_) {
      _snack('O conteúdo copiado não é um backup válido do Finanza Auto.');
    }
  }

  Future<void> _deleteEvent(CarEvent event) async {
    final shouldDelete = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(backgroundColor: panelRaised, title: Text('Excluir lançamento?'), content: Text('Esta ação remove o registro somente deste dispositivo.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Excluir'))]));
    if (shouldDelete != true) return;
    setState(() => events.removeWhere((item) => item.id == event.id));
    await _save();
    _snack('Lançamento excluído.');
  }

  /*
  Future<void> _entrySheet({required bool fuel, CarEvent? edit}) async {
    final date = TextEditingController(text: edit?.date ?? _isoToday());
    final odo = TextEditingController(text: edit == null || edit.odometer == 0 ? '' : edit.odometer.round().toString());
    final liters = TextEditingController(text: edit == null || edit.liters == 0 ? '' : edit.liters.toString());
    final price = TextEditingController(text: edit == null || edit.pricePerLiter == 0 ? '' : edit.pricePerLiter.toString());
    final amount = TextEditingController(text: edit == null || edit.amount == 0 ? '' : edit.amount.toStringAsFixed(2));
    final title = TextEditingController(text: edit?.title ?? '');
    final note = TextEditingController(text: edit?.note ?? '');
    var selectedFuel = edit?.fuelType ?? 'Etanol';
    var selectedCategory = edit?.category ?? 'Maintenance';
    final categories = {'Maintenance': 'Manutenção', 'Insurance': 'Seguro', 'Tax': 'Imposto / documento', 'Parking': 'Estacionamento', 'Wash': 'Lavagem', 'Fine': 'Multa', 'Other': 'Outro'};
    try {
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: panel, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))), builder: (sheetContext) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18), child: StatefulBuilder(builder: (context, setModalState) {
        final calculated = _number(liters.text) * _number(price.text);
        return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))), SizedBox(height: 20), Row(children: [Expanded(child: Text(edit == null ? (fuel ? 'Novo abastecimento' : 'Nova despesa') : 'Editar lançamento', style: TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.5))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: Icon(Icons.close_rounded, color: textMuted))]), SizedBox(height: 5), Text(fuel ? 'Registre o abastecimento e acompanhe o consumo.' : 'Mantenha todas as despesas do carro no mesmo lugar.', style: TextStyle(color: textMuted, fontSize: 12)), SizedBox(height: 19), _formRow([Expanded(child: TextField(controller: date, readOnly: true, onTap: () async { final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(Duration(days: 365)), initialDate: _parseDate(date.text) ?? DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.dark(primary: lime, surface: panelRaised)), child: child!)); if (picked != null) { date.text = DateFormat('yyyy-MM-dd').format(picked); setModalState(() {}); } }, decoration: InputDecoration(labelText: 'Data', prefixIcon: Icon(Icons.calendar_today_outlined, size: 17)))), SizedBox(width: 10), Expanded(child: TextField(controller: odo, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Hodômetro', suffixText: 'km')))]), SizedBox(height: 10), if (fuel) ...[DropdownButtonFormField<String>(value: selectedFuel, decoration: InputDecoration(labelText: 'Combustível', prefixIcon: Icon(Icons.local_gas_station_outlined, size: 18)), items: ['Etanol', 'Gasolina', 'Diesel', 'GNV', 'Flex'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setModalState(() => selectedFuel = value ?? selectedFuel)), SizedBox(height: 10), _formRow([Expanded(child: TextField(controller: liters, onChanged: (_) => setModalState(() {}), keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Litros'))), SizedBox(width: 10), Expanded(child: TextField(controller: price, onChanged: (_) => setModalState(() {}), keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Preço / litro', prefixText: 'R\$ ')))]), SizedBox(height: 10), TextField(controller: amount, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Total pago', prefixText: 'R\$ ', hintText: calculated > 0 ? calculated.toStringAsFixed(2) : null)),] else ...[DropdownButtonFormField<String>(value: selectedCategory, decoration: InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined, size: 18)), items: categories.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setModalState(() => selectedCategory = value ?? selectedCategory)), SizedBox(height: 10), TextField(controller: amount, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Valor', prefixText: 'R\$ ')), SizedBox(height: 10), TextField(controller: title, decoration: InputDecoration(labelText: 'Descrição', hintText: 'Ex.: troca de óleo, IPVA, seguro'))], SizedBox(height: 10), TextField(controller: note, decoration: InputDecoration(labelText: fuel ? 'Posto ou observação' : 'Observação', hintText: fuel ? 'Ex.: Posto Central' : 'Detalhes opcionais')), SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { final value = _number(amount.text) > 0 ? _number(amount.text) : calculated; if (value <= 0) { _snack('Informe um valor válido.'); return; } final event = edit ?? CarEvent(id: 'local-${DateTime.now().microsecondsSinceEpoch}', vehicleId: activeVehicle, type: fuel ? 'fuel' : 'expense', date: date.text, amount: value); event.vehicleId = activeVehicle; event.type = fuel ? 'fuel' : 'expense'; event.date = date.text.isEmpty ? _isoToday() : date.text; event.amount = value; event.odometer = _number(odo.text); event.liters = _number(liters.text); event.pricePerLiter = _number(price.text); event.fuelType = selectedFuel; event.title = title.text.trim(); event.category = selectedCategory; event.note = note.text.trim(); setState(() { if (edit == null) events.insert(0, event); final vehicle = currentVehicle; if (event.odometer > vehicle.odometer) vehicle.odometer = event.odometer; }); await _save(); if (sheetContext.mounted) Navigator.pop(sheetContext); _snack(edit == null ? 'Lançamento salvo.' : 'Lançamento atualizado.'); }, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: Color(0xff111707), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: TextStyle(fontWeight: FontWeight.w800)), child: Text(edit == null ? 'Salvar lançamento' : 'Salvar alterações'))), if (edit != null) Padding(padding: EdgeInsets.only(top: 7), child: Center(child: TextButton.icon(onPressed: () { Navigator.pop(sheetContext); _deleteEvent(edit); }, icon: Icon(Icons.delete_outline_rounded, color: coral, size: 17), label: Text('Excluir lançamento', style: TextStyle(color: coral, fontSize: 12)))))]);;
      }))),
    );
    } finally {
      for (final controller in [date, odo, liters, price, amount, title, note]) {
        controller.dispose();
      }
    }
  }

  */
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18),
            child: StatefulBuilder(
              builder: (context, setModalState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))),
                  SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Text('Lançamento rápido', style: TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: Icon(Icons.close_rounded, color: textMuted)),
                  ]),
                  Text('Anote uma despesa agora e complete os detalhes depois, se quiser.', style: TextStyle(color: textMuted, fontSize: 12)),
                  SizedBox(height: 18),
                  TextField(controller: amount, autofocus: true, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Valor', prefixText: r'R$ ', prefixIcon: Icon(Icons.payments_outlined))),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(value: category, decoration: InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined, size: 18)), items: categories.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setModalState(() => category = value ?? category)),
                  SizedBox(height: 10),
                  TextField(controller: title, textInputAction: TextInputAction.done, decoration: InputDecoration(labelText: 'Descrição', hintText: 'Ex.: estacionamento, pedágio...')),
                  SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async {
                    final value = _number(amount.text);
                    if (value <= 0) {
                      _snack('Informe um valor válido.');
                      return;
                    }
                    final event = CarEvent(id: 'local-${DateTime.now().microsecondsSinceEpoch}', vehicleId: activeVehicle, type: 'expense', date: _isoToday(), amount: value, odometer: _maxOdometer(allVehicleEvents), title: title.text.trim().isEmpty ? _categoryLabel(category) : title.text.trim(), category: category, note: 'Lançamento rápido');
                    setState(() => events.insert(0, event));
                    await _save();
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    _snack('Despesa salva.');
                  }, icon: Icon(Icons.check_rounded), label: Text('Salvar agora'), style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: Color(0xff111707), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: TextStyle(fontWeight: FontWeight.w800)))),
                ],
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

  Widget _formRow(List<Widget> children) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);

  Future<void> _entrySheet({required bool fuel, CarEvent? edit}) async {
    final date = TextEditingController(text: edit?.date ?? _isoToday());
    final odo = TextEditingController(text: edit == null || edit.odometer == 0 ? '' : edit.odometer.round().toString());
    final liters = TextEditingController(text: edit == null || edit.liters == 0 ? '' : edit.liters.toString());
    final price = TextEditingController(text: edit == null || edit.pricePerLiter == 0 ? '' : edit.pricePerLiter.toString());
    final amount = TextEditingController(text: edit == null || edit.amount == 0 ? '' : edit.amount.toStringAsFixed(2));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final calculated = _number(liters.text) * _number(price.text);
                return SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))),
                    SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: Text(edit == null ? (fuel ? 'Novo abastecimento' : 'Nova despesa') : 'Editar lançamento', style: TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.5))),
                      IconButton(onPressed: () => Navigator.pop(sheetContext), icon: Icon(Icons.close_rounded, color: textMuted)),
                    ]),
                    Text(fuel ? 'Registre o abastecimento e acompanhe o consumo.' : 'Mantenha todas as despesas do carro no mesmo lugar.', style: TextStyle(color: textMuted, fontSize: 12)),
                    SizedBox(height: 19),
                    _formRow([
                      Expanded(child: TextField(controller: date, readOnly: true, onTap: () async {
                        final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(Duration(days: 365)), initialDate: _parseDate(date.text) ?? DateTime.now());
                        if (picked != null) {
                          date.text = DateFormat('yyyy-MM-dd').format(picked);
                          setModalState(() {});
                        }
                      }, decoration: InputDecoration(labelText: 'Data', prefixIcon: Icon(Icons.calendar_today_outlined, size: 17)))),
                      SizedBox(width: 10),
                      Expanded(child: TextField(controller: odo, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Hodômetro', suffixText: 'km'))),
                    ]),
                    SizedBox(height: 10),
                    if (fuel) ...[
                      DropdownButtonFormField<String>(value: selectedFuel, decoration: InputDecoration(labelText: 'Combustível', prefixIcon: Icon(Icons.local_gas_station_outlined, size: 18)), items: ['Etanol', 'Gasolina', 'Diesel', 'GNV', 'Flex'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setModalState(() => selectedFuel = value ?? selectedFuel)),
                      SizedBox(height: 10),
                      _formRow([
                        Expanded(child: TextField(controller: liters, onChanged: (_) => setModalState(() {}), keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Litros'))),
                        SizedBox(width: 10),
                        Expanded(child: TextField(controller: price, onChanged: (_) => setModalState(() {}), keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Preço / litro', prefixText: 'R\$ '))),
                      ]),
                      SizedBox(height: 10),
                      TextField(controller: amount, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Total pago', prefixText: 'R\$ ', hintText: calculated > 0 ? calculated.toStringAsFixed(2) : null)),
                    ] else ...[
                      DropdownButtonFormField<String>(value: selectedCategory, decoration: InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined, size: 18)), items: categories.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setModalState(() => selectedCategory = value ?? selectedCategory)),
                      SizedBox(height: 10),
                      TextField(controller: amount, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Valor', prefixText: 'R\$ ')),
                      SizedBox(height: 10),
                      TextField(controller: title, decoration: InputDecoration(labelText: 'Descrição', hintText: 'Ex.: troca de óleo, IPVA, seguro')),
                    ],
                    SizedBox(height: 10),
                    TextField(controller: note, decoration: InputDecoration(labelText: fuel ? 'Posto ou observação' : 'Observação', hintText: fuel ? 'Ex.: Posto Central' : 'Detalhes opcionais')),
                    SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
                      final value = _number(amount.text) > 0 ? _number(amount.text) : calculated;
                      if (value <= 0) {
                        _snack('Informe um valor válido.');
                        return;
                      }
                      final event = edit ?? CarEvent(id: 'local-${DateTime.now().microsecondsSinceEpoch}', vehicleId: activeVehicle, type: fuel ? 'fuel' : 'expense', date: date.text, amount: value);
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
                        if (event.odometer > currentVehicle.odometer) currentVehicle.odometer = event.odometer;
                      });
                      await _save();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      _snack(edit == null ? 'Lançamento salvo.' : 'Lançamento atualizado.');
                    }, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: Color(0xff111707), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: TextStyle(fontWeight: FontWeight.w800)), child: Text(edit == null ? 'Salvar lançamento' : 'Salvar alterações'))),
                    if (edit != null) Center(child: TextButton.icon(onPressed: () { Navigator.pop(sheetContext); _deleteEvent(edit); }, icon: Icon(Icons.delete_outline_rounded, color: coral, size: 17), label: Text('Excluir lançamento', style: TextStyle(color: coral, fontSize: 12)))),
                  ]),
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

  /*
  Future<void> _vehicleSheet([CarVehicle? edit]) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final model = TextEditingController(text: edit?.model ?? '');
    final plate = TextEditingController(text: edit?.plate ?? '');
    final odometer = TextEditingController(text: edit == null || edit.odometer == 0 ? '' : edit.odometer.round().toString());
    try {
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: panel, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))), builder: (sheetContext) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))), SizedBox(height: 20), Row(children: [Expanded(child: Text(edit == null ? 'Adicionar veículo' : 'Editar veículo', style: TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: Icon(Icons.close_rounded, color: textMuted))]), SizedBox(height: 5), Text('Cadastre os detalhes para identificar seus registros.', style: TextStyle(color: textMuted, fontSize: 12)), SizedBox(height: 19), TextField(controller: name, decoration: InputDecoration(labelText: 'Nome do veículo', hintText: 'Ex.: Meu carro')), SizedBox(height: 10), _formRow([Expanded(child: TextField(controller: model, decoration: InputDecoration(labelText: 'Modelo / ano'))), SizedBox(width: 10), Expanded(child: TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: 'Placa')))]), SizedBox(height: 10), TextField(controller: odometer, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Hodômetro atual', suffixText: 'km')), SizedBox(height: 21), SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { if (name.text.trim().isEmpty) { _snack('Informe um nome para o veículo.'); return; } setState(() { if (edit == null) { final vehicle = CarVehicle(id: 'local-${DateTime.now().microsecondsSinceEpoch}', name: name.text.trim(), model: model.text.trim(), plate: plate.text.trim(), odometer: _number(odometer.text)); vehicles.add(vehicle); activeVehicle = vehicle.id; } else { edit.name = name.text.trim(); edit.model = model.text.trim(); edit.plate = plate.text.trim(); edit.odometer = _number(odometer.text); } }); await _save(); if (sheetContext.mounted) Navigator.pop(sheetContext); _snack(edit == null ? 'Veículo adicionado.' : 'Veículo atualizado.'); }, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: Color(0xff111707), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: TextStyle(fontWeight: FontWeight.w800)), child: Text(edit == null ? 'Adicionar veículo' : 'Salvar alterações'))), if (edit != null && vehicles.length > 1) Center(child: TextButton.icon(onPressed: () async { Navigator.pop(sheetContext); await _deleteVehicle(edit); }, icon: Icon(Icons.delete_outline_rounded, color: coral, size: 17), label: Text('Excluir veículo', style: TextStyle(color: coral, fontSize: 12))))]))));
    } finally {
      for (final controller in [name, model, plate, odometer]) {
        controller.dispose();
      }
    }
  }

  */
  Future<void> _deleteVehicle(CarVehicle vehicle) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(backgroundColor: panelRaised, title: Text('Excluir veículo?'), content: Text('Os registros deste veículo também serão removidos.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Excluir'))]));
    if (confirmed != true) return;
    setState(() { vehicles.removeWhere((item) => item.id == vehicle.id); events.removeWhere((event) => event.vehicleId == vehicle.id); activeVehicle = vehicles.first.id; });
    await _save();
    _snack('Veículo excluído.');
  }

  Future<void> _vehicleSheet([CarVehicle? edit]) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final model = TextEditingController(text: edit?.model ?? '');
    final plate = TextEditingController(text: edit?.plate ?? '');
    final odometer = TextEditingController(text: edit == null || edit.odometer == 0 ? '' : edit.odometer.round().toString());
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))),
                SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Text(edit == null ? 'Adicionar veículo' : 'Editar veículo', style: TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.pop(sheetContext), icon: Icon(Icons.close_rounded, color: textMuted)),
                ]),
                Text('Cadastre os detalhes para identificar seus registros.', style: TextStyle(color: textMuted, fontSize: 12)),
                SizedBox(height: 19),
                TextField(controller: name, decoration: InputDecoration(labelText: 'Nome do veículo', hintText: 'Ex.: Meu carro')),
                SizedBox(height: 10),
                _formRow([
                  Expanded(child: TextField(controller: model, decoration: InputDecoration(labelText: 'Modelo / ano'))),
                  SizedBox(width: 10),
                  Expanded(child: TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: 'Placa'))),
                ]),
                SizedBox(height: 10),
                TextField(controller: odometer, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Hodômetro atual', suffixText: 'km')),
                SizedBox(height: 21),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
                  if (name.text.trim().isEmpty) {
                    _snack('Informe um nome para o veículo.');
                    return;
                  }
                  setState(() {
                    if (edit == null) {
                      final vehicle = CarVehicle(id: 'local-${DateTime.now().microsecondsSinceEpoch}', name: name.text.trim(), model: model.text.trim(), plate: plate.text.trim(), odometer: _number(odometer.text));
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
                  _snack(edit == null ? 'Veículo adicionado.' : 'Veículo atualizado.');
                }, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: Color(0xff111707), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: TextStyle(fontWeight: FontWeight.w800)), child: Text(edit == null ? 'Adicionar veículo' : 'Salvar alterações'))),
                if (edit != null && vehicles.length > 1) Center(child: TextButton.icon(onPressed: () async { Navigator.pop(sheetContext); await _deleteVehicle(edit); }, icon: Icon(Icons.delete_outline_rounded, color: coral, size: 17), label: Text('Excluir veículo', style: TextStyle(color: coral, fontSize: 12)))),
              ]),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: panelRaised, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: EdgeInsets.all(14)));
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

