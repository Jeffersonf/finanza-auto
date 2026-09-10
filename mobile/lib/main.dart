import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const lime = Color(0xffc8f55a);
const aqua = Color(0xff5af5c8);
const page = Color(0xff08090d);
const surface = Color(0xff12151e);
const surface2 = Color(0xff1c202e);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const FinanzaAutoApp());
}

class FinanzaAutoApp extends StatelessWidget {
  const FinanzaAutoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Finanza · Carro',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: page,
          colorScheme: ColorScheme.fromSeed(seedColor: lime, brightness: Brightness.dark),
          fontFamily: 'sans',
          inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: const Color(0xff0d0f16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0x18000000))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0x1affffff))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: aqua)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        home: const CarHome(),
      );
}

class CarEvent {
  CarEvent({required this.id, required this.vehicleId, required this.type, required this.date, required this.amount, this.odometer = 0, this.fuelType = 'Gasolina', this.liters = 0, this.pricePerLiter = 0, this.title = '', this.category = 'Other', this.note = ''});
  String id, vehicleId, type, date, fuelType, title, category, note;
  double amount, odometer, liters, pricePerLiter;
  bool get fuel => type == 'fuel';
  factory CarEvent.fromMap(Map<String, dynamic> m) => CarEvent(id: '${m['id'] ?? ''}', vehicleId: '${m['vehicleId'] ?? ''}', type: '${m['type'] ?? 'expense'}', date: '${m['date'] ?? ''}'.substring(0, 10), amount: _number(m['amount']), odometer: _number(m['odometer']), fuelType: '${m['fuelType'] ?? 'Gasolina'}', liters: _number(m['liters']), pricePerLiter: _number(m['pricePerLiter']), title: '${m['title'] ?? ''}', category: '${m['category'] ?? 'Other'}', note: '${m['note'] ?? m['place'] ?? ''}');
  Map<String, dynamic> toMap() => {'id': id, 'vehicleId': vehicleId, 'type': type, 'date': date, 'amount': amount, 'odometer': odometer, 'fuelType': fuelType, 'liters': liters, 'pricePerLiter': pricePerLiter, 'title': title, 'category': category, 'note': note};
}

class CarVehicle {
  CarVehicle({required this.id, required this.name, this.model = '', this.plate = '', this.odometer = 0});
  String id, name, model, plate;
  double odometer;
  factory CarVehicle.fromMap(Map<String, dynamic> m) => CarVehicle(id: '${m['id'] ?? ''}', name: '${m['name'] ?? 'Meu carro'}', model: '${m['model'] ?? ''}', plate: '${m['plate'] ?? ''}', odometer: _number(m['odometer']));
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'model': model, 'plate': plate, 'odometer': odometer};
}

double _number(dynamic value) => double.tryParse('$value'.replaceAll(',', '.')) ?? 0;
String _money(num value) => NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(value);
String _date(String value) => DateFormat('dd/MM/yyyy').format(DateTime.tryParse('${value.substring(0, 10)}T12:00:00') ?? DateTime.now());
String _category(String value) => {'Maintenance': 'Manutenção', 'Insurance': 'Seguro', 'Tax': 'Imposto', 'Parking': 'Estacionamento', 'Wash': 'Lavagem', 'Fine': 'Multa', 'Other': 'Outro'}[value] ?? value;

class CarHome extends StatefulWidget {
  const CarHome({super.key});
  @override State<CarHome> createState() => _CarHomeState();
}

class _CarHomeState extends State<CarHome> {
  List<CarVehicle> vehicles = [];
  List<CarEvent> events = [];
  String activeVehicle = '', period = 'Tudo', typeFilter = 'Todos', sort = 'Mais recentes', query = '';
  bool loading = true;
  final search = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { search.dispose(); super.dispose(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('finanza_auto_flutter_state');
    Map<String, dynamic> data;
    if (saved != null) data = jsonDecode(saved) as Map<String, dynamic>;
    else data = jsonDecode(await rootBundle.loadString('assets/finanza-auto-backup.json')) as Map<String, dynamic>;
    final car = (data['car'] as Map).cast<String, dynamic>();
    vehicles = ((car['vehicles'] as List?) ?? []).map((e) => CarVehicle.fromMap((e as Map).cast<String, dynamic>())).toList();
    events = ((car['events'] as List?) ?? []).map((e) => CarEvent.fromMap((e as Map).cast<String, dynamic>())).toList();
    activeVehicle = '${car['activeVehicleId'] ?? (vehicles.isNotEmpty ? vehicles.first.id : '')}';
    if (vehicles.isEmpty) { vehicles = [CarVehicle(id: 'vehicle-1', name: 'Meu carro')]; activeVehicle = vehicles.first.id; }
    setState(() => loading = false);
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('finanza_auto_flutter_state', jsonEncode({'car': {'vehicles': vehicles.map((e) => e.toMap()).toList(), 'events': events.map((e) => e.toMap()).toList(), 'activeVehicleId': activeVehicle}}));
  }
  List<CarEvent> get filtered {
    var result = events.where((e) => activeVehicle == 'all' || e.vehicleId == activeVehicle).where((e) => typeFilter == 'Todos' || (typeFilter == 'Abastecimentos' ? e.fuel : !e.fuel)).where((e) => query.isEmpty || '${e.title} ${e.note} ${e.fuelType} ${e.category}'.toLowerCase().contains(query.toLowerCase())).toList();
    if (period != 'Tudo') { final now = DateTime.now(); final days = period == 'Mês atual' ? now.day : period == '30 dias' ? 30 : period == '90 dias' ? 90 : 365; final from = now.subtract(Duration(days: days)); result = result.where((e) => DateTime.tryParse(e.date)?.isAfter(from) ?? false).toList(); }
    result.sort((a, b) { final compare = sort == 'Maior valor' ? b.amount.compareTo(a.amount) : sort == 'Menor valor' ? a.amount.compareTo(b.amount) : sort == 'Maior km' ? b.odometer.compareTo(a.odometer) : sort == 'Menor km' ? a.odometer.compareTo(b.odometer) : b.date.compareTo(a.date); return compare; });
    return result;
  }
  CarVehicle get vehicle => vehicles.firstWhere((v) => v.id == activeVehicle, orElse: () => vehicles.first);
  double get total => filtered.fold(0, (sum, e) => sum + e.amount);
  double get fuelTotal => filtered.where((e) => e.fuel).fold(0, (sum, e) => sum + e.amount);
  double get expenseTotal => total - fuelTotal;
  double get liters => filtered.where((e) => e.fuel).fold(0, (sum, e) => sum + e.liters);
  double get distance { final fuel = [...filtered.where((e) => e.fuel && e.odometer > 0)]..sort((a, b) => a.odometer.compareTo(b.odometer)); return fuel.length > 1 ? fuel.last.odometer - fuel[fuel.length - 2].odometer : 0; }
  double get consumption => distance > 0 && filtered.where((e) => e.fuel).isNotEmpty ? distance / ([...filtered.where((e) => e.fuel)]..sort((a, b) => b.date.compareTo(a.date))).first.liters : 0;
  double get maxOdo => filtered.fold(0, (max, e) => e.odometer > max ? e.odometer : max);

  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: lime)));
    return Scaffold(
      drawer: _drawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Finanza  /  Carro', style: TextStyle(fontSize: 13, color: Color(0xffa4aab7))),
        actions: [
          if (MediaQuery.sizeOf(context).width > 700)
            Padding(
              padding: const EdgeInsets.only(right: 28),
              child: Center(child: Text('${events.length} registros locais', style: const TextStyle(fontSize: 12, color: Color(0xff737b8b)))),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(constraints.maxWidth < 600 ? 15 : 42, 20, constraints.maxWidth < 600 ? 15 : 42, 30),
              child: _content(constraints.maxWidth),
            ),
          ),
        ),
      ),
    );
  }
  Widget _drawer(BuildContext context) => Drawer(
        backgroundColor: const Color(0xff0d0f16),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _brand(),
              const SizedBox(height: 48),
              const Text('MÓDULO', style: TextStyle(color: Color(0xff626979), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              _nav(Icons.directions_car_outlined, 'Carro', true),
              _nav(Icons.build_outlined, 'Manutenção', false),
              _nav(Icons.insights_outlined, 'Evolução', false),
              _nav(Icons.receipt_long_outlined, 'Histórico', false),
              const Spacer(),
              const Divider(color: Color(0x1affffff)),
              const SizedBox(height: 12),
              Text('Dados locais', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 5),
              const Text('salvos neste dispositivo', style: TextStyle(color: Color(0xff626979), fontSize: 11)),
            ]),
          ),
        ),
      );
  Widget _brand() => Row(children: [Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(10)), child: const Text('F', style: TextStyle(color: Color(0xff10150a), fontWeight: FontWeight.w800, fontSize: 17)),), const SizedBox(width: 10), const Text('finanza.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21))]);
  Widget _nav(IconData icon, String label, bool active) => Container(margin: const EdgeInsets.only(bottom: 5), decoration: BoxDecoration(color: active ? const Color(0x19c8f55a) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: ListTile(dense: true, leading: Icon(icon, color: active ? lime : const Color(0xff858c9c), size: 20), title: Text(label, style: TextStyle(color: active ? lime : const Color(0xff858c9c), fontWeight: FontWeight.w600, fontSize: 14)), onTap: () => Navigator.pop(context)));
  Widget _content(double width) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_hero(width), const SizedBox(height: 16), _filters(width), const SizedBox(height: 16), _metrics(width), const SizedBox(height: 17), _panel('Manutenção preventiva', 'Acompanhe os próximos cuidados do veículo', _maintenance(width)), const SizedBox(height: 17), _panel('Evolução do carro', 'Gasto por mês no período filtrado', _chart()), const SizedBox(height: 17), _panel('Histórico do carro', 'Abastecimentos, manutenção, seguro, impostos e lavagens', _history()), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Finanza · Módulo Carro', style: TextStyle(color: Color(0xff626979), fontSize: 11)), Text('${events.length} registros · tudo salvo neste dispositivo', style: const TextStyle(color: Color(0xff626979), fontSize: 11))])]);
  Widget _hero(double width) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x25c8f55a)),
          gradient: const LinearGradient(colors: [Color(0x1bc8f55a), Color(0x095af5c8), Color(0x1412151e)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MÓDULO DE VEÍCULO', style: TextStyle(color: lime, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
          const SizedBox(height: 9),
          Text(vehicle.name, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
          const SizedBox(height: 6),
          Text([vehicle.model, vehicle.plate, '${NumberFormat.decimalPattern('pt_BR').format(maxOdo)} km'].where((e) => e.isNotEmpty).join('  ·  '), style: const TextStyle(color: Color(0xffa2a9b6), fontSize: 14)),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _button('+ Veículo', Icons.add, _vehicleSheet),
            _button('Editar veículo', Icons.edit_outlined, () => _vehicleSheet(vehicle)),
            _button('Importar CSV', Icons.upload_file_outlined, () => _snack('Os dados reais do Drivvo já estão carregados.')),
            _button('+ Despesa', Icons.receipt_long_outlined, () => _entrySheet(false)),
            _button('+ Abastecimento', Icons.local_gas_station_outlined, () => _entrySheet(true), primary: true),
          ]),
        ]),
      );
  Widget _button(String label, IconData icon, VoidCallback onTap, {bool primary = false}) => FilledButton.icon(onPressed: onTap, icon: Icon(icon, size: 16), label: Text(label), style: FilledButton.styleFrom(backgroundColor: primary ? lime : surface, foregroundColor: primary ? const Color(0xff10150a) : const Color(0xffc6ccd5), side: BorderSide(color: primary ? lime : const Color(0x20ffffff)), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));
  Widget _filters(double width) => Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xaa12151e), border: Border.all(color: const Color(0x10ffffff)), borderRadius: BorderRadius.circular(15)), child: Wrap(spacing: 8, runSpacing: 8, children: [_select(activeVehicle == 'all' ? 'Todos os veículos' : vehicle.name, vehicles.map((e) => e.name).toList() + ['Todos os veículos'], (v) { setState(() => activeVehicle = v == 'Todos os veículos' ? 'all' : vehicles.firstWhere((e) => e.name == v).id); }), _select(period, const ['Mês atual', '30 dias', '90 dias', 'Ano atual', 'Tudo'], (v) => setState(() => period = v)), _select(typeFilter, const ['Todos', 'Abastecimentos', 'Despesas'], (v) => setState(() => typeFilter = v)), _select(sort, const ['Mais recentes', 'Mais antigos', 'Maior valor', 'Menor valor', 'Maior km', 'Menor km'], (v) => setState(() => sort = v)), SizedBox(width: width > 700 ? 220 : width - 50, child: TextField(controller: search, onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'Buscar no histórico...', prefixIcon: Icon(Icons.search, size: 18), isDense: true))) ]));
  Widget _select(String value, List<String> values, ValueChanged<String> onChanged) => SizedBox(width: 170, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, isExpanded: true, items: values.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) onChanged(v); }, decoration: const InputDecoration(isDense: true)));
  Widget _metrics(double width) { final cards = [['Gastos totais', _money(total), '${filtered.length} registros no filtro', lime], ['Km rodados', distance > 0 ? '${distance.round()} km' : '—', distance > 0 ? 'último intervalo válido' : 'precisa de 2 abastecimentos', aqua], ['Consumo médio', consumption > 0 ? '${consumption.toStringAsFixed(1).replaceAll('.', ',')} km/l' : '—', liters > 0 ? '${liters.toStringAsFixed(1)} L registrados' : 'sem litros suficientes', lime], ['Custo por km', distance > 0 ? _money((fuelTotal + expenseTotal) / distance) : '—', 'combustível + despesas', const Color(0xfff5c85a)], ['Combustível', _money(fuelTotal), '${filtered.where((e) => e.fuel).length} abastecimentos', const Color(0xfff5c85a)], ['Despesas', _money(expenseTotal), '${filtered.where((e) => !e.fuel).length} lançamentos', const Color(0xfff5705a)], ['Ticket médio', filtered.isEmpty ? '—' : _money(total / filtered.length), 'por registro', aqua], ['Último lançamento', filtered.isEmpty ? '—' : _money(filtered.first.amount), filtered.isEmpty ? 'sem registros' : _date(filtered.first.date), const Color(0xfff5c85a)]]; return GridView.count(crossAxisCount: width < 560 ? 2 : width < 900 ? 3 : 4, childAspectRatio: width < 560 ? 1.45 : 1.6, crossAxisSpacing: 10, mainAxisSpacing: 10, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: cards.map((c) => _metric(c[0] as String, c[1] as String, c[2] as String, c[3] as Color)).toList()); }
  Widget _metric(String label, String value, String caption, Color color) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(15), border: Border(top: BorderSide(color: color.withOpacity(.6), width: 2), left: const BorderSide(color: Color(0x12ffffff)), right: const BorderSide(color: Color(0x12ffffff)), bottom: const BorderSide(color: Color(0x12ffffff)))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(color: Color(0xff939aaa), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6)), const Spacer(), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xff747c8c), fontSize: 11))]));
  Widget _panel(String title, String subtitle, Widget content) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0x16ffffff)), boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 25, offset: Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: Color(0xff9298a7), fontSize: 12)), const SizedBox(height: 18), content]));
  Widget _maintenance(double width) {
    final expense = filtered.where((e) => !e.fuel).toList()..sort((a, b) => b.amount.compareTo(a.amount));
    final cards = <List<String>>[
      ['Próxima revisão', '—', 'cadastre troca de óleo ou revisão'],
      ['Prazo por data', '—', 'sem referência no histórico'],
      ['Maior gasto', expense.isEmpty ? '—' : _money(expense.first.amount), expense.isEmpty ? 'sem despesas' : _category(expense.first.category)],
      ['Hodômetro atual', '${maxOdo.round()} km', 'maior leitura importada'],
      ['Gasto em despesas', _money(expenseTotal), '${expense.length} lançamentos no filtro'],
    ];
    return GridView.count(
      crossAxisCount: width < 560 ? 1 : 3,
      childAspectRatio: width < 560 ? 4.8 : 2.3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards.map((c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(c[0], style: const TextStyle(color: Color(0xff939aaa), fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(c[1], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          Text(c[2], style: const TextStyle(color: Color(0xff747c8c), fontSize: 10)),
        ]),
      )).toList(),
    );
  }
  Widget _chart() { final months = List.generate(6, (i) { final d = DateTime(DateTime.now().year, DateTime.now().month - (5 - i)); return DateFormat('MMM', 'pt_BR').format(d).replaceAll('.', ''); }); final values = List<double>.filled(6, 0); for (final e in filtered) { final date = DateTime.tryParse(e.date); if (date != null) { final index = 5 - (DateTime.now().year * 12 + DateTime.now().month - (date.year * 12 + date.month)); if (index >= 0 && index < 6) values[index] += e.amount; } } final max = values.fold<double>(100, (a, b) => a > b ? a : b); return SizedBox(height: 230, child: Column(children: [Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(6, (i) => Column(mainAxisAlignment: MainAxisAlignment.end, children: [Container(width: 16, height: values[i] == 0 ? 3 : 145 * values[i] / max, decoration: BoxDecoration(color: aqua, borderRadius: BorderRadius.circular(5))), const SizedBox(height: 8), Text(months[i], style: const TextStyle(color: Color(0xff727a8a), fontSize: 10))])))), const Divider(color: Color(0x18ffffff)), Align(alignment: Alignment.centerRight, child: Text('${_money(values.fold(0, (a, b) => a + b))} no período', style: const TextStyle(color: Color(0xfff4f5f7), fontWeight: FontWeight.w700, fontSize: 12))) ])); }
  Widget _history() {
    if (filtered.isEmpty) {
      return const Padding(padding: EdgeInsets.all(35), child: Center(child: Text('Nenhum registro neste filtro.', style: TextStyle(color: Color(0xff9298a7)))));
    }
    return Column(children: filtered.take(30).map((e) => ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      leading: CircleAvatar(backgroundColor: e.fuel ? const Color(0x195af5c8) : const Color(0x19f5705a), child: Icon(e.fuel ? Icons.local_gas_station_outlined : Icons.build_outlined, color: e.fuel ? aqua : const Color(0xffff9b8c), size: 19)),
      title: Text(e.fuel ? '${e.fuelType} · ${e.liters.toStringAsFixed(2)} L' : (e.title.isEmpty ? _category(e.category) : e.title), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text([_date(e.date), if (e.odometer > 0) '${e.odometer.round()} km', if (e.note.isNotEmpty) e.note].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xff9298a7), fontSize: 11)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_money(e.amount), style: const TextStyle(color: Color(0xfff5705a), fontWeight: FontWeight.w800, fontSize: 12)),
        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xff697282)), onPressed: () => _delete(e)),
      ]),
    )).toList());
  }
  Future<void> _delete(CarEvent event) async { if (await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Remover registro?'), content: const Text('Essa ação remove o lançamento deste dispositivo.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remover'))])) == true) { setState(() => events.removeWhere((e) => e.id == event.id)); await _save(); } }
  Future<void> _entrySheet(bool fuel) async {
    final liters = TextEditingController();
    final price = TextEditingController();
    final amount = TextEditingController();
    final odo = TextEditingController(text: vehicle.odometer.round().toString());
    final title = TextEditingController();
    final note = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff151925),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
        child: StatefulBuilder(
          builder: (c, setModal) => SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fuel ? 'Novo abastecimento' : 'Nova despesa', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Wrap(spacing: 12, runSpacing: 0, children: [
                SizedBox(width: 170, child: TextField(controller: odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hodômetro (km)'))),
                if (fuel) SizedBox(width: 170, child: TextField(controller: liters, onChanged: (_) => setModal(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Litros'))),
                if (fuel) SizedBox(width: 170, child: TextField(controller: price, onChanged: (_) => setModal(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço/litro'))),
                SizedBox(width: 170, child: TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: r'Total (R$)', hintText: fuel && liters.text.isNotEmpty && price.text.isNotEmpty ? (_number(liters.text) * _number(price.text)).toStringAsFixed(2) : null))),
                if (!fuel) SizedBox(width: 360, child: TextField(controller: title, decoration: const InputDecoration(labelText: 'Descrição'))),
                SizedBox(width: 360, child: TextField(controller: note, decoration: const InputDecoration(labelText: 'Observação'))),
              ]),
              const SizedBox(height: 20),
              Align(alignment: Alignment.centerRight, child: FilledButton(
                onPressed: () async {
                  final value = double.tryParse(amount.text.replaceAll(',', '.')) ?? (_number(liters.text) * _number(price.text));
                  if (value <= 0) return;
                  final e = CarEvent(id: 'local-${DateTime.now().microsecondsSinceEpoch}', vehicleId: activeVehicle, type: fuel ? 'fuel' : 'expense', date: DateFormat('yyyy-MM-dd').format(DateTime.now()), amount: value, odometer: _number(odo.text), liters: _number(liters.text), pricePerLiter: _number(price.text), fuelType: 'Etanol', title: title.text, category: fuel ? 'Combustivel' : 'Maintenance', note: note.text);
                  setState(() { events.insert(0, e); vehicle.odometer = e.odometer > vehicle.odometer ? e.odometer : vehicle.odometer; });
                  await _save();
                  if (c.mounted) Navigator.pop(c);
                },
                child: const Text('Salvar registro'),
              )),
            ]),
          ),
        ),
      ),
    );
  }
  Future<void> _vehicleSheet([CarVehicle? edit]) async {
    final name = TextEditingController(text: edit?.name);
    final model = TextEditingController(text: edit?.model);
    final plate = TextEditingController(text: edit?.plate);
    final odo = TextEditingController(text: edit?.odometer.round().toString());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff151925),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(edit == null ? 'Novo veículo' : 'Editar veículo', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: model, decoration: const InputDecoration(labelText: 'Modelo / ano'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: plate, decoration: const InputDecoration(labelText: 'Placa'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hodômetro atual')),
          const SizedBox(height: 18),
          Align(alignment: Alignment.centerRight, child: FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              setState(() {
                if (edit == null) {
                  final v = CarVehicle(id: 'local-${DateTime.now().microsecondsSinceEpoch}', name: name.text.trim(), model: model.text, plate: plate.text, odometer: _number(odo.text));
                  vehicles.add(v);
                  activeVehicle = v.id;
                } else {
                  edit.name = name.text.trim();
                  edit.model = model.text;
                  edit.plate = plate.text;
                  edit.odometer = _number(odo.text);
                }
              });
              await _save();
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Salvar veículo'),
          )),
        ]),
      ),
    );
  }
  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: lime, behavior: SnackBarBehavior.floating));
}
