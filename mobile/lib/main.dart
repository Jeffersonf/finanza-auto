import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ink = Color(0xff080a0f);
const panel = Color(0xff121722);
const panelSoft = Color(0xff181e2b);
const panelRaised = Color(0xff20283a);
const lime = Color(0xffc8f55a);
const mint = Color(0xff5af5c8);
const amber = Color(0xffffc857);
const coral = Color(0xffff806b);
const textMain = Color(0xfff5f7fb);
const textMuted = Color(0xff9aa4b5);
const textSoft = Color(0xff687388);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const FinanzaAutoApp());
}

class FinanzaAutoApp extends StatelessWidget {
  const FinanzaAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finanza · Carro',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: ink,
        colorScheme: ColorScheme.fromSeed(seedColor: lime, brightness: Brightness.dark).copyWith(
          primary: lime,
          onPrimary: const Color(0xff111707),
          secondary: mint,
          surface: panel,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: ink, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff0e131c),
          labelStyle: const TextStyle(color: textMuted),
          hintStyle: const TextStyle(color: textSoft),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0x16ffffff))),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: mint, width: 1.2)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0x16ffffff), space: 1),
      ),
      home: const CarHome(),
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
  return const [];
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
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: lime)));
    return Scaffold(
      backgroundColor: ink,
      body: SafeArea(child: Column(children: [
        _topBar(),
        if (loadError.isNotEmpty) _errorBanner(),
        Expanded(child: IndexedStack(index: tab, children: [_homeTab(), _historyTab(), _analyticsTab(), _vehicleTab()])),
      ])),
      bottomNavigationBar: _bottomNavigation(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickExpenseSheet,
        backgroundColor: lime,
        foregroundColor: const Color(0xff111707),
        icon: const Icon(Icons.bolt_rounded),
        label: const Text('Lançamento rápido', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _topBar() {
    return Padding(padding: const EdgeInsets.fromLTRB(20, 15, 14, 10), child: Row(children: [
      Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x22c8f55a), blurRadius: 16)]), child: const Text('F', style: TextStyle(color: Color(0xff101607), fontWeight: FontWeight.w900, fontSize: 21))),
      const SizedBox(width: 11),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('finanza.', style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.5)), Text(_tabTitle, style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w500))]),
      const Spacer(),
      PopupMenuButton<String>(tooltip: 'Mais opções', color: panelRaised, icon: const Icon(Icons.more_horiz_rounded, color: textMuted), onSelected: (value) { if (value == 'backup') _copyBackup(); if (value == 'restore') _restoreBackup(); if (value == 'vehicle') _vehicleSheet(); }, itemBuilder: (context) => const [PopupMenuItem(value: 'backup', child: Text('Copiar backup local')), PopupMenuItem(value: 'restore', child: Text('Restaurar backup')), PopupMenuItem(value: 'vehicle', child: Text('Adicionar veículo'))]),
    ]));
  }

  Widget _errorBanner() => Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(20, 0, 20, 8), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(color: coral.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: coral.withOpacity(.25))), child: Row(children: [const Icon(Icons.info_outline_rounded, color: coral, size: 17), const SizedBox(width: 8), Expanded(child: Text(loadError, style: const TextStyle(color: Color(0xffffb0a4), fontSize: 12)))]));

  Widget _bottomNavigation() => NavigationBar(height: 72, selectedIndex: tab, onDestinationSelected: (index) => setState(() => tab = index), backgroundColor: const Color(0xff0d1119), indicatorColor: lime.withOpacity(.16), labelTextStyle: const MaterialStatePropertyAll(TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), destinations: const [NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded, color: lime), label: 'Início'), NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: lime), label: 'Histórico'), NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights, color: lime), label: 'Análises'), NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car, color: lime), label: 'Carro')]);

  Widget _homeTab() {
    final list = filteredEvents;
    final total = _total(list);
    return RefreshIndicator(color: lime, backgroundColor: panel, onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _vehicleSwitcher(),
      const SizedBox(height: 16),
      _heroCard(list, total),
      const SizedBox(height: 22),
      _sectionTitle('Resumo do período', 'Tudo que foi registrado no carro', trailing: _periodDropdown()),
      const SizedBox(height: 11),
      _metricsGrid(list),
      const SizedBox(height: 23),
      _sectionTitle('Atalhos', 'Registre um novo movimento em segundos'),
      const SizedBox(height: 11),
      _quickActions(),
      const SizedBox(height: 23),
      _sectionTitle('Evolução dos gastos', 'Últimos meses com dados registrados', trailing: Text(_shortMoney(total), style: const TextStyle(color: lime, fontWeight: FontWeight.w800, fontSize: 13))),
      const SizedBox(height: 11),
      _chartCard(list),
      const SizedBox(height: 23),
      _sectionTitle('Lançamentos recentes', 'Os últimos movimentos do veículo', trailing: TextButton(onPressed: () => setState(() => tab = 1), child: const Text('Ver todos'))),
      const SizedBox(height: 8),
      _recentList(list),
    ]));
  }

  Widget _vehicleSwitcher() => Row(children: [Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: mint.withOpacity(.12), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.directions_car_rounded, size: 19, color: mint)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currentVehicle.name, style: const TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w700)), Text(currentVehicle.model.isEmpty ? 'Seu veículo principal' : currentVehicle.model, style: const TextStyle(color: textMuted, fontSize: 11))])), PopupMenuButton<String>(tooltip: 'Trocar veículo', onSelected: (value) async { setState(() => activeVehicle = value); await _save(); }, color: panelRaised, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textMuted), itemBuilder: (context) => vehicles.map((vehicle) => PopupMenuItem(value: vehicle.id, child: Text(vehicle.name))).toList())]);

  Widget _heroCard(List<CarEvent> list, double total) => Container(padding: const EdgeInsets.fromLTRB(20, 20, 20, 17), decoration: BoxDecoration(borderRadius: BorderRadius.circular(25), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff26361e), Color(0xff17221e), Color(0xff141925)]), border: Border.all(color: lime.withOpacity(.23)), boxShadow: const [BoxShadow(color: Color(0x1dc8f55a), blurRadius: 28, offset: Offset(0, 14))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: lime.withOpacity(.13), borderRadius: BorderRadius.circular(9)), child: const Text('VISÃO GERAL', style: TextStyle(color: lime, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1))), const Spacer(), const Icon(Icons.auto_awesome_rounded, color: Color(0xffefffbf), size: 20)]), const SizedBox(height: 20), Text(_money(total), style: const TextStyle(color: textMain, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)), const SizedBox(height: 5), Text('${list.length} registros em ${period.toLowerCase()}', style: const TextStyle(color: Color(0xffb6c7a5), fontSize: 12)), const SizedBox(height: 18), Row(children: [Expanded(child: _heroStat('Combustível', _money(_fuelTotal(list)), amber)), Container(width: 1, height: 32, color: Colors.white.withOpacity(.12)), Expanded(child: Padding(padding: const EdgeInsets.only(left: 16), child: _heroStat('Despesas', _money(_expenseTotal(list)), coral)))]), const SizedBox(height: 17), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _entrySheet(fuel: true), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Registrar abastecimento'), style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: const Color(0xff111707), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))))]));
  Widget _heroStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: textMuted, fontSize: 11)), const SizedBox(height: 3), Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800))]);

  Widget _sectionTitle(String title, String subtitle, {Widget? trailing}) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.3)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: textMuted, fontSize: 11))])), if (trailing != null) trailing]);
  Widget _periodDropdown() => DropdownButtonHideUnderline(child: DropdownButton<String>(value: period, dropdownColor: panelRaised, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 18), style: const TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.w700), items: const ['Tudo', 'Mês atual', '30 dias', '90 dias', 'Ano atual'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => period = value ?? period)));

  Widget _metricsGrid(List<CarEvent> list) {
    final distance = _distance(list);
    final consumption = _consumption(list);
    final cards = [
      _MetricData('Km acompanhados', distance > 0 ? '${distance.round()} km' : '—', distance > 0 ? 'entre abastecimentos' : 'sem leituras suficientes', mint, Icons.route_rounded),
      _MetricData('Consumo médio', consumption > 0 ? '${consumption.toStringAsFixed(1).replaceAll('.', ',')} km/l' : '—', _liters(list) > 0 ? '${_liters(list).toStringAsFixed(0)} L registrados' : 'sem litros registrados', lime, Icons.speed_rounded),
      _MetricData('Custo por km', distance > 0 ? _money(_total(list) / distance) : '—', 'combustível + despesas', amber, Icons.payments_outlined),
      _MetricData('Hodômetro', '${_maxOdometer(allVehicleEvents).round()} km', 'maior leitura importada', coral, Icons.dashboard_outlined),
    ];
    return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.27, children: cards.map(_metricCard).toList());
  }

  Widget _metricCard(_MetricData data) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 29, height: 29, alignment: Alignment.center, decoration: BoxDecoration(color: data.color.withOpacity(.12), borderRadius: BorderRadius.circular(9)), child: Icon(data.icon, color: data.color, size: 16)), const Spacer(), Icon(Icons.arrow_outward_rounded, color: textSoft.withOpacity(.7), size: 14)]), const Spacer(), Text(data.label.toUpperCase(), style: const TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)), const SizedBox(height: 4), Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: data.color, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.5)), const SizedBox(height: 3), Text(data.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textSoft, fontSize: 10))]));

  Widget _quickActions() => Row(children: [Expanded(child: _quickAction(Icons.local_gas_station_rounded, 'Abastecer', 'Combustível', mint, () => _entrySheet(fuel: true))), const SizedBox(width: 10), Expanded(child: _quickAction(Icons.build_rounded, 'Adicionar', 'Despesa', coral, () => _entrySheet(fuel: false))), const SizedBox(width: 10), Expanded(child: _quickAction(Icons.edit_rounded, 'Editar', 'Veículo', amber, () => _vehicleSheet(currentVehicle)))]);
  Widget _quickAction(IconData icon, String title, String caption, Color color, VoidCallback action) => InkWell(onTap: action, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.fromLTRB(10, 13, 8, 12), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)), const SizedBox(height: 11), Text(title, style: const TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(caption, style: const TextStyle(color: textSoft, fontSize: 10))])));

  Widget _chartCard(List<CarEvent> list) {
    final chart = _chartValues(list);
    final maxValue = chart.values.fold<double>(0, (max, value) => value > max ? value : max);
    return Container(padding: const EdgeInsets.fromLTRB(16, 17, 16, 13), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(19), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: [if (maxValue == 0) const SizedBox(height: 116, child: Center(child: Text('Ainda não há gastos neste período', style: TextStyle(color: textMuted, fontSize: 12)))) else SizedBox(height: 145, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceAround, children: chart.entries.map((entry) { final height = maxValue == 0 ? 4.0 : 102 * entry.value / maxValue; return Column(mainAxisAlignment: MainAxisAlignment.end, children: [Container(width: 24, height: height.clamp(4.0, 102.0).toDouble(), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [mint, lime]))), const SizedBox(height: 8), Text(entry.key, style: const TextStyle(color: textSoft, fontSize: 10))]); }).toList())), const Divider(height: 20), Row(children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: mint, shape: BoxShape.circle)), const SizedBox(width: 7), const Text('Gasto mensal', style: TextStyle(color: textMuted, fontSize: 11)), const Spacer(), Text(_money(chart.values.fold<double>(0, (sum, value) => sum + value)), style: const TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800))]) ]));
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

  Widget _recentList(List<CarEvent> list) => list.isEmpty ? _emptyState('Nenhum lançamento ainda', 'Use um dos atalhos acima para começar.') : Column(children: list.take(5).map(_eventTile).toList());

  Widget _eventTile(CarEvent event) {
    final color = event.fuel ? mint : coral;
    final icon = event.fuel ? Icons.local_gas_station_rounded : _expenseIcon(event.category);
    return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.06))), child: ListTile(onTap: () => _entrySheet(fuel: event.fuel, edit: event), contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3), leading: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 19)), title: Text(event.fuel ? '${event.fuelType} · ${event.liters.toStringAsFixed(1)} L' : (event.title.isEmpty ? _categoryLabel(event.category) : event.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w700)), subtitle: Text([_dateLabel(event.date), if (event.odometer > 0) '${event.odometer.round()} km', if (event.note.isNotEmpty) event.note].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textMuted, fontSize: 10)), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_money(event.amount), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 3), const Text('Editar', style: TextStyle(color: textSoft, fontSize: 9))])));
  }

  Widget _historyTab() {
    final list = filteredEvents;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _pageIntro('Histórico completo', '${allVehicleEvents.length} registros salvos neste dispositivo', Icons.receipt_long_rounded, mint),
      const SizedBox(height: 17),
      TextField(controller: searchController, onChanged: (value) => setState(() => search = value), decoration: const InputDecoration(hintText: 'Buscar por posto, categoria ou descrição', prefixIcon: Icon(Icons.search_rounded, color: textMuted))),
      const SizedBox(height: 12),
      _filterChips(),
      const SizedBox(height: 12),
      Row(children: [Text('${list.length} resultados', style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700)), const Spacer(), _sortDropdown()]),
      const SizedBox(height: 9),
      if (list.isEmpty) _emptyState('Nada encontrado', 'Tente mudar o filtro ou registrar um novo lançamento.') else ...list.map(_eventTile),
    ]);
  }

  Widget _filterChips() {
    const values = ['Todos', 'Abastecimentos', 'Despesas'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: values.map((value) {
          final selected = typeFilter == value;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(value),
              selected: selected,
              onSelected: (_) => setState(() => typeFilter = value),
              selectedColor: lime,
              backgroundColor: panel,
              side: BorderSide(color: selected ? lime : Colors.white.withOpacity(.08)),
              labelStyle: TextStyle(color: selected ? const Color(0xff101607) : textMuted, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sortDropdown() => DropdownButtonHideUnderline(child: DropdownButton<String>(value: sort, dropdownColor: panelRaised, icon: const Icon(Icons.swap_vert_rounded, color: textMuted, size: 16), style: const TextStyle(color: textMuted, fontSize: 11), items: const ['Mais recentes', 'Mais antigos', 'Maior valor', 'Menor valor', 'Maior km', 'Menor km'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => sort = value ?? sort)));

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
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _pageIntro('Análises do carro', 'Entenda para onde seu dinheiro está indo', Icons.insights_rounded, lime),
      const SizedBox(height: 17),
      _analysisSummary(fuel, expense, list),
      const SizedBox(height: 19),
      _sectionTitle('Gasto por mês', 'Acompanhe a evolução do custo total'),
      const SizedBox(height: 10),
      _chartCard(list),
      const SizedBox(height: 19),
      _sectionTitle('Combustível', 'Distribuição do que foi abastecido'),
      const SizedBox(height: 10),
      _breakdownCard(orderedFuel, fuel, Icons.local_gas_station_rounded, mint),
      const SizedBox(height: 19),
      _sectionTitle('Onde você abastece', 'Postos e locais mais frequentes'),
      const SizedBox(height: 10),
      _placesCard(orderedPlaces),
      const SizedBox(height: 19),
      _sectionTitle('Manutenção preventiva', 'Próximos cuidados para não esquecer'),
      const SizedBox(height: 10),
      _maintenanceCard(list),
    ]);
  }

  Widget _analysisSummary(double fuel, double expense, List<CarEvent> list) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: [Row(children: [Expanded(child: _summaryValue('Total', _money(fuel + expense), textMain)), Expanded(child: _summaryValue('Combustível', _money(fuel), mint)), Expanded(child: _summaryValue('Despesas', _money(expense), coral))]), const SizedBox(height: 18), Row(children: [const Icon(Icons.info_outline_rounded, size: 15, color: textMuted), const SizedBox(width: 7), Expanded(child: Text('${list.length} lançamentos analisados · ${_distance(list).round()} km acompanhados', style: const TextStyle(color: textMuted, fontSize: 11)))]) ]));
  Widget _summaryValue(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: textMuted, fontSize: 10)), const SizedBox(height: 5), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900))]);

  Widget _breakdownCard(List<MapEntry<String, double>> items, double total, IconData icon, Color color) {
    if (items.isEmpty) return _emptyState('Sem abastecimentos', 'Os dados aparecerão aqui quando forem registrados.');
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: items.take(4).map((item) { final ratio = total > 0 ? item.value / total : 0.0; return Padding(padding: const EdgeInsets.only(bottom: 13), child: Column(children: [Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 8), Text(item.key, style: const TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w700)), const Spacer(), Text(_money(item.value), style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700))]), const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: Colors.white.withOpacity(.07), color: color))])); }).toList()));
  }

  Widget _placesCard(List<MapEntry<String, int>> places) {
    if (places.isEmpty) return _emptyState('Sem locais registrados', 'O posto ou local aparece quando você informa uma observação.');
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: places.take(5).toList().asMap().entries.map((entry) { final item = entry.value; return ListTile(dense: true, leading: CircleAvatar(radius: 15, backgroundColor: mint.withOpacity(.11), child: Text('${entry.key + 1}', style: const TextStyle(color: mint, fontSize: 11, fontWeight: FontWeight.w800))), title: Text(item.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w700)), trailing: Text('${item.value}x', style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700))); }).toList()));
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
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: amber.withOpacity(.13), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.build_circle_outlined, color: amber, size: 19)), const SizedBox(width: 10), const Expanded(child: Text('Cuidados do veículo', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w800))), const Icon(Icons.chevron_right_rounded, color: textSoft)]), const SizedBox(height: 14), _maintenanceLine('Maior despesa registrada', expenses.isEmpty ? 'Nenhuma ainda' : '${_categoryLabel(expenses.first.category)} · ${_money(expenses.first.amount)}'), const SizedBox(height: 8), _maintenanceLine('Último hodômetro conhecido', '${currentOdometer.round()} km'), const SizedBox(height: 8), _maintenanceLine('Próxima revisão', serviceLabel) ]));
  }

  Widget _maintenanceLine(String label, String value) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), decoration: BoxDecoration(color: panelSoft, borderRadius: BorderRadius.circular(11)), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: textMuted, fontSize: 10))), const SizedBox(width: 8), Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: textMain, fontSize: 10, fontWeight: FontWeight.w700)))]));

  Widget _vehicleTab() {
    final list = allVehicleEvents;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _pageIntro('Seu veículo', 'Cadastro, desempenho e dados locais', Icons.directions_car_rounded, amber),
      const SizedBox(height: 17),
      Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff202b3b), Color(0xff151b27)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: amber.withOpacity(.22))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 45, height: 45, alignment: Alignment.center, decoration: BoxDecoration(color: amber.withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.directions_car_rounded, color: amber, size: 25)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currentVehicle.name, style: const TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.w900)), Text(currentVehicle.model.isEmpty ? 'Modelo não informado' : currentVehicle.model, style: const TextStyle(color: textMuted, fontSize: 12))])), IconButton(onPressed: () => _vehicleSheet(currentVehicle), icon: const Icon(Icons.edit_outlined, color: textMuted))]), const SizedBox(height: 20), Row(children: [Expanded(child: _vehicleInfo('Hodômetro', '${_maxOdometer(list).round()} km')), Expanded(child: _vehicleInfo('Registros', '${list.length}')), Expanded(child: _vehicleInfo('Placa', currentVehicle.plate.isEmpty ? '—' : currentVehicle.plate))]) ])),
      const SizedBox(height: 19),
      _sectionTitle('Meus veículos', 'Toque para alternar o veículo ativo', trailing: IconButton(onPressed: () => _vehicleSheet(), icon: const Icon(Icons.add_circle_outline_rounded, color: lime))),
      const SizedBox(height: 9),
      ...vehicles.map((vehicle) => _vehicleRow(vehicle)),
      const SizedBox(height: 19),
      _sectionTitle('Dados e backup', 'Tudo fica salvo localmente no aparelho'),
      const SizedBox(height: 9),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))), child: Column(children: [Row(children: [Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: mint.withOpacity(.12), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.lock_outline_rounded, color: mint, size: 19)), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dados somente neste dispositivo', style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Sem sincronização externa ou conta obrigatória.', style: TextStyle(color: textMuted, fontSize: 10))])), const Icon(Icons.verified_user_outlined, color: mint, size: 18)]), const SizedBox(height: 13), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _copyBackup, icon: const Icon(Icons.content_copy_rounded, size: 16), label: const Text('Copiar JSON'), style: OutlinedButton.styleFrom(foregroundColor: textMain, side: const BorderSide(color: Color(0x25ffffff)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))), const SizedBox(width: 9), Expanded(child: OutlinedButton.icon(onPressed: _restoreBackup, icon: const Icon(Icons.restore_rounded, size: 16), label: const Text('Restaurar'), style: OutlinedButton.styleFrom(foregroundColor: mint, side: BorderSide(color: mint.withOpacity(.35)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))]) ])),
      const SizedBox(height: 13),
      Center(child: Text('Fonte: CSV Drivvo · ${events.length} registros importados', style: const TextStyle(color: textSoft, fontSize: 10))),
    ]);
  }

  Widget _pageIntro(String title, String subtitle, IconData icon, Color color) => Row(children: [Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 21)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.6)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: textMuted, fontSize: 11))]))]);
  Widget _vehicleInfo(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: textMuted, fontSize: 10)), const SizedBox(height: 5), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w800))]);

  Widget _vehicleRow(CarVehicle vehicle) {
    final selected = vehicle.id == activeVehicle;
    return InkWell(
      onTap: () async {
        setState(() => activeVehicle = vehicle.id);
        await _save();
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(color: selected ? lime.withOpacity(.1) : panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? lime.withOpacity(.35) : Colors.white.withOpacity(.06))),
        child: Row(children: [
          Icon(Icons.directions_car_outlined, color: selected ? lime : textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vehicle.name, style: TextStyle(color: selected ? lime : textMain, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(vehicle.model.isEmpty ? 'Modelo não informado' : vehicle.model, style: const TextStyle(color: textMuted, fontSize: 10)),
          ])),
          if (selected) const Icon(Icons.check_circle_rounded, color: lime, size: 19),
          IconButton(onPressed: () => _vehicleSheet(vehicle), icon: const Icon(Icons.more_horiz_rounded, color: textSoft, size: 19)),
        ]),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) => Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 27), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withOpacity(.06))), child: Column(children: [const Icon(Icons.inbox_outlined, color: textSoft, size: 28), const SizedBox(height: 9), Text(title, style: const TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: textMuted, fontSize: 11))]));
  IconData _expenseIcon(String category) => {'Maintenance': Icons.build_rounded, 'Insurance': Icons.shield_outlined, 'Tax': Icons.description_outlined, 'Parking': Icons.local_parking_rounded, 'Wash': Icons.water_drop_outlined, 'Fine': Icons.warning_amber_rounded}[category] ?? Icons.receipt_long_outlined;

  Future<void> _copyBackup() async {
    final backup = const JsonEncoder.withIndent('  ').convert({'app': 'Finanza Auto', 'version': '2.0', 'car': {'vehicles': vehicles.map((vehicle) => vehicle.toMap()).toList(), 'events': events.map((event) => event.toMap()).toList(), 'activeVehicleId': activeVehicle}});
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
        if (loadedVehicles.length == 1 || !validIds.contains(event.vehicleId)) event.vehicleId = loadedVehicles.first.id;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: panelRaised,
          title: const Text('Restaurar backup?'),
          content: Text('${loadedEvents.length} registros e ${loadedVehicles.length} veículo(s) substituirão os dados atuais.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restaurar')),
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
    final shouldDelete = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(backgroundColor: panelRaised, title: const Text('Excluir lançamento?'), content: const Text('Esta ação remove o registro somente deste dispositivo.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir'))]));
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
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: panel, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))), builder: (sheetContext) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18), child: StatefulBuilder(builder: (context, setModalState) {
        final calculated = _number(liters.text) * _number(price.text);
        return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))), const SizedBox(height: 20), Row(children: [Expanded(child: Text(edit == null ? (fuel ? 'Novo abastecimento' : 'Nova despesa') : 'Editar lançamento', style: const TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.5))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded, color: textMuted))]), const SizedBox(height: 5), Text(fuel ? 'Registre o abastecimento e acompanhe o consumo.' : 'Mantenha todas as despesas do carro no mesmo lugar.', style: const TextStyle(color: textMuted, fontSize: 12)), const SizedBox(height: 19), _formRow([Expanded(child: TextField(controller: date, readOnly: true, onTap: () async { final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _parseDate(date.text) ?? DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: lime, surface: panelRaised)), child: child!)); if (picked != null) { date.text = DateFormat('yyyy-MM-dd').format(picked); setModalState(() {}); } }, decoration: const InputDecoration(labelText: 'Data', prefixIcon: Icon(Icons.calendar_today_outlined, size: 17)))), const SizedBox(width: 10), Expanded(child: TextField(controller: odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hodômetro', suffixText: 'km')))]), const SizedBox(height: 10), if (fuel) ...[DropdownButtonFormField<String>(value: selectedFuel, decoration: const InputDecoration(labelText: 'Combustível', prefixIcon: Icon(Icons.local_gas_station_outlined, size: 18)), items: const ['Etanol', 'Gasolina', 'Diesel', 'GNV', 'Flex'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setModalState(() => selectedFuel = value ?? selectedFuel)), const SizedBox(height: 10), _formRow([Expanded(child: TextField(controller: liters, onChanged: (_) => setModalState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Litros'))), const SizedBox(width: 10), Expanded(child: TextField(controller: price, onChanged: (_) => setModalState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço / litro', prefixText: 'R\$ ')))]), const SizedBox(height: 10), TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Total pago', prefixText: 'R\$ ', hintText: calculated > 0 ? calculated.toStringAsFixed(2) : null)),] else ...[DropdownButtonFormField<String>(value: selectedCategory, decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined, size: 18)), items: categories.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setModalState(() => selectedCategory = value ?? selectedCategory)), const SizedBox(height: 10), TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ ')), const SizedBox(height: 10), TextField(controller: title, decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: troca de óleo, IPVA, seguro'))], const SizedBox(height: 10), TextField(controller: note, decoration: InputDecoration(labelText: fuel ? 'Posto ou observação' : 'Observação', hintText: fuel ? 'Ex.: Posto Central' : 'Detalhes opcionais')), const SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { final value = _number(amount.text) > 0 ? _number(amount.text) : calculated; if (value <= 0) { _snack('Informe um valor válido.'); return; } final event = edit ?? CarEvent(id: 'local-${DateTime.now().microsecondsSinceEpoch}', vehicleId: activeVehicle, type: fuel ? 'fuel' : 'expense', date: date.text, amount: value); event.vehicleId = activeVehicle; event.type = fuel ? 'fuel' : 'expense'; event.date = date.text.isEmpty ? _isoToday() : date.text; event.amount = value; event.odometer = _number(odo.text); event.liters = _number(liters.text); event.pricePerLiter = _number(price.text); event.fuelType = selectedFuel; event.title = title.text.trim(); event.category = selectedCategory; event.note = note.text.trim(); setState(() { if (edit == null) events.insert(0, event); final vehicle = currentVehicle; if (event.odometer > vehicle.odometer) vehicle.odometer = event.odometer; }); await _save(); if (sheetContext.mounted) Navigator.pop(sheetContext); _snack(edit == null ? 'Lançamento salvo.' : 'Lançamento atualizado.'); }, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: const Color(0xff111707), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800)), child: Text(edit == null ? 'Salvar lançamento' : 'Salvar alterações'))), if (edit != null) Padding(padding: const EdgeInsets.only(top: 7), child: Center(child: TextButton.icon(onPressed: () { Navigator.pop(sheetContext); _deleteEvent(edit); }, icon: const Icon(Icons.delete_outline_rounded, color: coral, size: 17), label: const Text('Excluir lançamento', style: TextStyle(color: coral, fontSize: 12)))))]);;
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
    const categories = <String, String>{
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18),
            child: StatefulBuilder(
              builder: (context, setModalState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Expanded(child: Text('Lançamento rápido', style: TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded, color: textMuted)),
                  ]),
                  const Text('Anote uma despesa agora e complete os detalhes depois, se quiser.', style: TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 18),
                  TextField(controller: amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ ', prefixIcon: Icon(Icons.payments_outlined))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined, size: 18)), items: categories.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setModalState(() => category = value ?? category)),
                  const SizedBox(height: 10),
                  TextField(controller: title, textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: estacionamento, pedágio...')),
                  const SizedBox(height: 20),
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
                  }, icon: const Icon(Icons.check_rounded), label: const Text('Salvar agora'), style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: const Color(0xff111707), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800)))),
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final calculated = _number(liters.text) * _number(price.text);
                return SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: Text(edit == null ? (fuel ? 'Novo abastecimento' : 'Nova despesa') : 'Editar lançamento', style: const TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.5))),
                      IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded, color: textMuted)),
                    ]),
                    Text(fuel ? 'Registre o abastecimento e acompanhe o consumo.' : 'Mantenha todas as despesas do carro no mesmo lugar.', style: const TextStyle(color: textMuted, fontSize: 12)),
                    const SizedBox(height: 19),
                    _formRow([
                      Expanded(child: TextField(controller: date, readOnly: true, onTap: () async {
                        final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _parseDate(date.text) ?? DateTime.now());
                        if (picked != null) {
                          date.text = DateFormat('yyyy-MM-dd').format(picked);
                          setModalState(() {});
                        }
                      }, decoration: const InputDecoration(labelText: 'Data', prefixIcon: Icon(Icons.calendar_today_outlined, size: 17)))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hodômetro', suffixText: 'km'))),
                    ]),
                    const SizedBox(height: 10),
                    if (fuel) ...[
                      DropdownButtonFormField<String>(value: selectedFuel, decoration: const InputDecoration(labelText: 'Combustível', prefixIcon: Icon(Icons.local_gas_station_outlined, size: 18)), items: const ['Etanol', 'Gasolina', 'Diesel', 'GNV', 'Flex'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setModalState(() => selectedFuel = value ?? selectedFuel)),
                      const SizedBox(height: 10),
                      _formRow([
                        Expanded(child: TextField(controller: liters, onChanged: (_) => setModalState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Litros'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: price, onChanged: (_) => setModalState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço / litro', prefixText: 'R\$ '))),
                      ]),
                      const SizedBox(height: 10),
                      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Total pago', prefixText: 'R\$ ', hintText: calculated > 0 ? calculated.toStringAsFixed(2) : null)),
                    ] else ...[
                      DropdownButtonFormField<String>(value: selectedCategory, decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined, size: 18)), items: categories.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setModalState(() => selectedCategory = value ?? selectedCategory)),
                      const SizedBox(height: 10),
                      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ ')),
                      const SizedBox(height: 10),
                      TextField(controller: title, decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: troca de óleo, IPVA, seguro')),
                    ],
                    const SizedBox(height: 10),
                    TextField(controller: note, decoration: InputDecoration(labelText: fuel ? 'Posto ou observação' : 'Observação', hintText: fuel ? 'Ex.: Posto Central' : 'Detalhes opcionais')),
                    const SizedBox(height: 20),
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
                    }, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: const Color(0xff111707), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800)), child: Text(edit == null ? 'Salvar lançamento' : 'Salvar alterações'))),
                    if (edit != null) Center(child: TextButton.icon(onPressed: () { Navigator.pop(sheetContext); _deleteEvent(edit); }, icon: const Icon(Icons.delete_outline_rounded, color: coral, size: 17), label: const Text('Excluir lançamento', style: TextStyle(color: coral, fontSize: 12)))),
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
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: panel, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))), builder: (sheetContext) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))), const SizedBox(height: 20), Row(children: [Expanded(child: Text(edit == null ? 'Adicionar veículo' : 'Editar veículo', style: const TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded, color: textMuted))]), const SizedBox(height: 5), const Text('Cadastre os detalhes para identificar seus registros.', style: TextStyle(color: textMuted, fontSize: 12)), const SizedBox(height: 19), TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do veículo', hintText: 'Ex.: Meu carro')), const SizedBox(height: 10), _formRow([Expanded(child: TextField(controller: model, decoration: const InputDecoration(labelText: 'Modelo / ano'))), const SizedBox(width: 10), Expanded(child: TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Placa')))]), const SizedBox(height: 10), TextField(controller: odometer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hodômetro atual', suffixText: 'km')), const SizedBox(height: 21), SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { if (name.text.trim().isEmpty) { _snack('Informe um nome para o veículo.'); return; } setState(() { if (edit == null) { final vehicle = CarVehicle(id: 'local-${DateTime.now().microsecondsSinceEpoch}', name: name.text.trim(), model: model.text.trim(), plate: plate.text.trim(), odometer: _number(odometer.text)); vehicles.add(vehicle); activeVehicle = vehicle.id; } else { edit.name = name.text.trim(); edit.model = model.text.trim(); edit.plate = plate.text.trim(); edit.odometer = _number(odometer.text); } }); await _save(); if (sheetContext.mounted) Navigator.pop(sheetContext); _snack(edit == null ? 'Veículo adicionado.' : 'Veículo atualizado.'); }, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: const Color(0xff111707), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800)), child: Text(edit == null ? 'Adicionar veículo' : 'Salvar alterações'))), if (edit != null && vehicles.length > 1) Center(child: TextButton.icon(onPressed: () async { Navigator.pop(sheetContext); await _deleteVehicle(edit); }, icon: const Icon(Icons.delete_outline_rounded, color: coral, size: 17), label: const Text('Excluir veículo', style: TextStyle(color: coral, fontSize: 12))))]))));
    } finally {
      for (final controller in [name, model, plate, odometer]) {
        controller.dispose();
      }
    }
  }

  */
  Future<void> _deleteVehicle(CarVehicle vehicle) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(backgroundColor: panelRaised, title: const Text('Excluir veículo?'), content: const Text('Os registros deste veículo também serão removidos.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir'))]));
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 18),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: textSoft, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Text(edit == null ? 'Adicionar veículo' : 'Editar veículo', style: const TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded, color: textMuted)),
                ]),
                const Text('Cadastre os detalhes para identificar seus registros.', style: TextStyle(color: textMuted, fontSize: 12)),
                const SizedBox(height: 19),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do veículo', hintText: 'Ex.: Meu carro')),
                const SizedBox(height: 10),
                _formRow([
                  Expanded(child: TextField(controller: model, decoration: const InputDecoration(labelText: 'Modelo / ano'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Placa'))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: odometer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hodômetro atual', suffixText: 'km')),
                const SizedBox(height: 21),
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
                }, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: const Color(0xff111707), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800)), child: Text(edit == null ? 'Adicionar veículo' : 'Salvar alterações'))),
                if (edit != null && vehicles.length > 1) Center(child: TextButton.icon(onPressed: () async { Navigator.pop(sheetContext); await _deleteVehicle(edit); }, icon: const Icon(Icons.delete_outline_rounded, color: coral, size: 17), label: const Text('Excluir veículo', style: TextStyle(color: coral, fontSize: 12)))),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: panelRaised, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(14)));
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.caption, this.color, this.icon);
  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;
}
