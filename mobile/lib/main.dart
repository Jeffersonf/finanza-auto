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
const String appVersion = '2.3.7';
const int appBuildNumber = 29;
const String cloudflareSyncUrl = 'https://finanza-auto.jeffef.workers.dev/api/sync';

/// Dynamic Theme State Notifiers
final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

/// Strongly-typed automotive accent color definition
class AppPrimaryColor {
  final String name;
  final Color color;
  final String id;

  const AppPrimaryColor({
    required this.name,
    required this.color,
    required this.id,
  });
}

/// Curated Automotive Primary Palette
const List<AppPrimaryColor> appPrimaryColors = [
  AppPrimaryColor(name: 'Azul Cobalt', color: Color(0xFF2563EB), id: 'cobalt'),
  AppPrimaryColor(name: 'Vermelho Sport', color: Color(0xFFDC2626), id: 'red'),
  AppPrimaryColor(name: 'Laranja Sunset', color: Color(0xFFEA580C), id: 'orange'),
  AppPrimaryColor(name: 'Âmbar Racing', color: Color(0xFFD97706), id: 'amber'),
  AppPrimaryColor(name: 'Roxo Precision', color: Color(0xFF7C3AED), id: 'purple'),
  AppPrimaryColor(name: 'Ciano Elétrico', color: Color(0xFF0891B2), id: 'cyan'),
  AppPrimaryColor(name: 'Grafite Slate', color: Color(0xFF475569), id: 'slate'),
];
final ValueNotifier<AppPrimaryColor> primaryColorNotifier = ValueNotifier<AppPrimaryColor>(appPrimaryColors.first);

/// App Theme Tokens (AutoLog - Dynamic Primary & Âmbar)
class AppTheme {
  // Surfaces & Backgrounds
  static Color get background => isDarkMode.value ? const Color(0xFF0A0E14) : const Color(0xFFF8FAFC);
  static Color get card => isDarkMode.value ? const Color(0xFF131924) : const Color(0xFFFFFFFF);
  static Color get cardSubtle => isDarkMode.value ? const Color(0xFF1A2232) : const Color(0xFFF1F5F9);
  static Color get border => isDarkMode.value ? const Color(0xFF263248) : const Color(0xFFE2E8F0);
  static Color get trackLine => isDarkMode.value ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

  // Dynamic Primary Accent
  static Color get primary => primaryColorNotifier.value.color;
  static Color get primaryHover => primaryColorNotifier.value.color;
  static const Color primaryForeground = Colors.white;
  static Color get primarySoft => isDarkMode.value
      ? primaryColorNotifier.value.color.withValues(alpha: 0.18)
      : primaryColorNotifier.value.color.withValues(alpha: 0.12);
  static Color get primarySoftText => isDarkMode.value
      ? (primaryColorNotifier.value.color == const Color(0xFF2563EB) ? const Color(0xFF93C5FD) : primaryColorNotifier.value.color)
      : primaryColorNotifier.value.color;
  static Color get textOnDarkGreen => const Color(0xFFBFDBFE); // Soft highlight for primary card

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
  static Color get economyGreen => primaryColorNotifier.value.color;
}

/// Vehicle Model (Preserving Chevrolet Astra specs: 52L tank, ~164.154 km)
class CarVehicle {
  String id;
  String name;
  String model;
  String brand;
  String plate;
  int odometer;
  double tankCapacity;
  int serviceIntervalKm;
  double targetConsumption;

  CarVehicle({
    required this.id,
    required this.name,
    this.model = '',
    this.brand = 'Chevrolet',
    this.plate = '',
    this.odometer = 0,
    this.tankCapacity = 52.0,
    this.serviceIntervalKm = 10000,
    this.targetConsumption = 7.5,
  });

  factory CarVehicle.fromMap(Map<String, dynamic> map) {
    final modelStr = (map['model'] ?? 'Chevrolet Astra').toString();
    var brandStr = (map['brand'] ?? '').toString();
    if (brandStr.isEmpty) {
      final lower = modelStr.toLowerCase();
      if (lower.contains('chevrolet') || lower.contains('astra') || lower.contains('gm') || lower.contains('onix') || lower.contains('corsa') || lower.contains('vectra')) {
        brandStr = 'Chevrolet';
      } else if (lower.contains('volkswagen') || lower.contains('vw') || lower.contains('gol') || lower.contains('polo') || lower.contains('golf')) {
        brandStr = 'Volkswagen';
      } else if (lower.contains('fiat') || lower.contains('uno') || lower.contains('palio') || lower.contains('strada') || lower.contains('argo')) {
        brandStr = 'Fiat';
      } else if (lower.contains('ford') || lower.contains('ka') || lower.contains('fiesta') || lower.contains('ranger')) {
        brandStr = 'Ford';
      } else if (lower.contains('toyota') || lower.contains('corolla') || lower.contains('hilux')) {
        brandStr = 'Toyota';
      } else if (lower.contains('honda') || lower.contains('civic') || lower.contains('fit')) {
        brandStr = 'Honda';
      } else if (lower.contains('hyundai') || lower.contains('hb20') || lower.contains('creta')) {
        brandStr = 'Hyundai';
      } else if (lower.contains('renault') || lower.contains('sandero') || lower.contains('duster')) {
        brandStr = 'Renault';
      } else {
        brandStr = 'Chevrolet';
      }
    }
    return CarVehicle(
      id: (map['id'] ?? 'drivvo-car').toString(),
      name: (map['name'] ?? 'Astra').toString(),
      model: modelStr,
      brand: brandStr,
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
    'brand': brand,
    'plate': plate,
    'odometer': odometer,
    'tankCapacity': tankCapacity,
    'serviceIntervalKm': serviceIntervalKm,
    'targetConsumption': targetConsumption,
  };
}

/// Authentic Automotive Brand Logo Badge
class CarBrandLogo extends StatelessWidget {
  final String brandOrModel;
  final double size;

  const CarBrandLogo({
    super.key,
    required this.brandOrModel,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final lower = brandOrModel.toLowerCase();

    Widget logoContent;
    if (lower.contains('chevrolet') || lower.contains('astra') || lower.contains('gm') || lower.contains('onix') || lower.contains('corsa') || lower.contains('vectra') || lower.contains('tracker') || lower.contains('s10')) {
      logoContent = CustomPaint(
        size: Size(size * 0.74, size * 0.44),
        painter: ChevroletBowtiePainter(),
      );
    } else if (lower.contains('volkswagen') || lower.contains('vw') || lower.contains('gol') || lower.contains('polo') || lower.contains('golf') || lower.contains('t-cross')) {
      logoContent = CustomPaint(
        size: Size(size * 0.62, size * 0.62),
        painter: VolkswagenLogoPainter(),
      );
    } else if (lower.contains('fiat') || lower.contains('uno') || lower.contains('palio') || lower.contains('strada') || lower.contains('argo') || lower.contains('toro')) {
      logoContent = CustomPaint(
        size: Size(size * 0.62, size * 0.62),
        painter: FiatLogoPainter(),
      );
    } else if (lower.contains('ford') || lower.contains('ka') || lower.contains('fiesta') || lower.contains('ranger') || lower.contains('focus')) {
      logoContent = CustomPaint(
        size: Size(size * 0.72, size * 0.42),
        painter: FordLogoPainter(),
      );
    } else if (lower.contains('toyota') || lower.contains('corolla') || lower.contains('hilux') || lower.contains('yaris') || lower.contains('etios')) {
      logoContent = CustomPaint(
        size: Size(size * 0.68, size * 0.50),
        painter: ToyotaLogoPainter(),
      );
    } else if (lower.contains('honda') || lower.contains('civic') || lower.contains('fit') || lower.contains('hr-v') || lower.contains('city')) {
      logoContent = CustomPaint(
        size: Size(size * 0.60, size * 0.56),
        painter: HondaLogoPainter(),
      );
    } else {
      logoContent = Icon(Icons.directions_car, color: AppTheme.primary, size: size * 0.52);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDarkMode.value ? const Color(0xFF161F2E) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: isDarkMode.value ? const Color(0xFF2A3A50) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: logoContent),
    );
  }
}

class ChevroletBowtiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.34, 0);
    path.lineTo(w * 0.66, 0);
    path.lineTo(w * 0.66, h * 0.26);
    path.lineTo(w, h * 0.26);
    path.lineTo(w * 0.94, h * 0.74);
    path.lineTo(w * 0.66, h * 0.74);
    path.lineTo(w * 0.66, h);
    path.lineTo(w * 0.34, h);
    path.lineTo(w * 0.34, h * 0.74);
    path.lineTo(0, h * 0.74);
    path.lineTo(w * 0.06, h * 0.26);
    path.lineTo(w * 0.34, h * 0.26);
    path.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD54F), Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFF92400E)],
        stops: [0.0, 0.35, 0.75, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    final innerPath = Path();
    innerPath.moveTo(w * 0.38, h * 0.12);
    innerPath.lineTo(w * 0.62, h * 0.12);
    innerPath.lineTo(w * 0.62, h * 0.34);
    innerPath.lineTo(w * 0.88, h * 0.34);
    innerPath.lineTo(w * 0.84, h * 0.66);
    innerPath.lineTo(w * 0.62, h * 0.66);
    innerPath.lineTo(w * 0.62, h * 0.88);
    innerPath.lineTo(w * 0.38, h * 0.88);
    innerPath.lineTo(w * 0.38, h * 0.66);
    innerPath.lineTo(w * 0.12, h * 0.66);
    innerPath.lineTo(w * 0.16, h * 0.34);
    innerPath.lineTo(w * 0.38, h * 0.34);
    innerPath.close();

    final innerStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(innerPath, innerStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VolkswagenLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w / 2;
    final center = Offset(r, r);

    final bgPaint = Paint()..color = const Color(0xFF001E50);
    canvas.drawCircle(center, r, bgPaint);

    final ringPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, r - 1, ringPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final vPath = Path()
      ..moveTo(w * 0.28, w * 0.25)
      ..lineTo(w * 0.50, w * 0.50)
      ..lineTo(w * 0.72, w * 0.25);
    canvas.drawPath(vPath, linePaint);

    final wPath = Path()
      ..moveTo(w * 0.22, w * 0.46)
      ..lineTo(w * 0.38, w * 0.78)
      ..lineTo(w * 0.50, w * 0.56)
      ..lineTo(w * 0.62, w * 0.78)
      ..lineTo(w * 0.78, w * 0.46);
    canvas.drawPath(wPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FiatLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w / 2;
    final center = Offset(r, r);

    final bgPaint = Paint()..color = const Color(0xFF8B0000);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, w), Radius.circular(w * 0.25)), bgPaint);

    final ringPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, w), Radius.circular(w * 0.25)), ringPaint);

    final barPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final startX = w * 0.26 + (i * w * 0.16);
      canvas.drawLine(Offset(startX + w * 0.08, w * 0.30), Offset(startX, w * 0.70), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FordLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()..color = const Color(0xFF002C6C);
    canvas.drawOval(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(Rect.fromLTWH(0, 0, w, h), borderPaint);

    final fPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(w * 0.30, h * 0.70)
      ..cubicTo(w * 0.35, h * 0.30, w * 0.45, h * 0.25, w * 0.65, h * 0.30)
      ..moveTo(w * 0.25, h * 0.48)
      ..lineTo(w * 0.55, h * 0.48);
    canvas.drawPath(path, fPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ToyotaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final p = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawOval(Rect.fromLTWH(1, 1, w - 2, h - 2), p);
    canvas.drawOval(Rect.fromLTWH(w * 0.20, h * 0.15, w * 0.60, h * 0.38), p);
    canvas.drawOval(Rect.fromLTWH(w * 0.36, h * 0.15, w * 0.28, h * 0.70), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HondaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final p = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final outer = Path()
      ..moveTo(w * 0.15, 0)
      ..lineTo(w * 0.85, 0)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..close();
    canvas.drawPath(outer, p);

    final hPath = Path()
      ..moveTo(w * 0.32, h * 0.12)
      ..lineTo(w * 0.36, h * 0.88)
      ..moveTo(w * 0.68, h * 0.12)
      ..lineTo(w * 0.64, h * 0.88)
      ..moveTo(w * 0.34, h * 0.50)
      ..lineTo(w * 0.66, h * 0.50);
    canvas.drawPath(hPath, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

    final savedColorVal = prefs.getInt('finanza_primary_color');
    if (savedColorVal != null) {
      final matched = appPrimaryColors.firstWhere(
        (c) => c.color.value == savedColorVal,
        orElse: () => appPrimaryColors.first,
      );
      primaryColorNotifier.value = matched;
    }
  } catch (_) {}

  runApp(const FinanzaAutoApp());
}

class FinanzaAutoApp extends StatelessWidget {
  const FinanzaAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([isDarkMode, primaryColorNotifier]),
      builder: (context, _) {
        final isDark = isDarkMode.value;
        final pri = primaryColorNotifier.value;
        return MaterialApp(
          key: ValueKey('autolog_app_${isDark}_${pri.color.value}'),
          title: 'AutoLog',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'DM Sans',
            brightness: Brightness.light,
            colorScheme: ColorScheme.light(
              primary: pri.color,
              surface: const Color(0xFFFFFFFF),
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
            colorScheme: ColorScheme.dark(
              primary: pri.color,
              surface: const Color(0xFF131924),
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
          home: FinanzaAutoHomePage(key: ValueKey('home_${isDark}_${pri.color.value}')),
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
    primaryColorNotifier.addListener(_onThemeChanged);
    _loadAllData().then((_) => _checkQuickFuelAction());
    _checkAppUpdates();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    isDarkMode.removeListener(_onThemeChanged);
    primaryColorNotifier.removeListener(_onThemeChanged);
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (isDownloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
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

      final savedActiveVId = prefs.getString('finanza_active_vehicle_id');
      String activeVId = loadedVehicles.first.id;
      if (savedActiveVId != null && loadedVehicles.any((v) => v.id == savedActiveVId)) {
        activeVId = savedActiveVId;
      }

      setState(() {
        _vehicles = loadedVehicles;
        _activeVehicleId = activeVId;
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
            SnackBar(
              content: const Row(
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
          SnackBar(
              content: const Row(
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
                child: Icon(Icons.local_gas_station, color: AppTheme.primary, size: 22),
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

  void _selectVehicle(String vehicleId) async {
    setState(() {
      _activeVehicleId = vehicleId;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('finanza_active_vehicle_id', vehicleId);
    } catch (_) {}
  }

  void _addNewVehicle(CarVehicle v) async {
    setState(() {
      _vehicles.add(v);
      _activeVehicleId = v.id;
    });
    _saveLocalState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('finanza_active_vehicle_id', v.id);
    } catch (_) {}
  }

  void _showAddVehicleDialog() {
    final nameCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final odoCtrl = TextEditingController();
    final tankCtrl = TextEditingController(text: '50.0');
    final targetCtrl = TextEditingController(text: '8.5');
    String selectedBrand = 'Chevrolet';

    final brandOptions = [
      'Chevrolet',
      'Volkswagen',
      'Fiat',
      'Ford',
      'Toyota',
      'Honda',
      'Hyundai',
      'Renault',
      'Nissan',
      'Jeep',
      'Outro',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.border),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Novo Veículo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textMain)),
                          Text('Adicione à sua garagem', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('MARCA DO VEÍCULO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBrand,
                        isExpanded: true,
                        dropdownColor: AppTheme.card,
                        items: brandOptions.map((b) {
                          return DropdownMenuItem<String>(
                            value: b,
                            child: Row(
                              children: [
                                CarBrandLogo(brandOrModel: b, size: 24),
                                const SizedBox(width: 10),
                                Text(b, style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedBrand = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: modelCtrl,
                    style: TextStyle(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'Modelo (ex: Civic EXR 2.0, Gol 1.6)',
                      labelStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.cardSubtle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          style: TextStyle(color: AppTheme.textMain),
                          decoration: InputDecoration(
                            labelText: 'Apelido (ex: Civic)',
                            labelStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.cardSubtle,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: plateCtrl,
                          style: TextStyle(color: AppTheme.textMain),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Placa (ex: BRA2E19)',
                            labelStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.cardSubtle,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: odoCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: AppTheme.textMain),
                          decoration: InputDecoration(
                            labelText: 'Km Inicial',
                            labelStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.cardSubtle,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: tankCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: AppTheme.textMain),
                          decoration: InputDecoration(
                            labelText: 'Tanque (Litros)',
                            labelStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.cardSubtle,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final modelText = modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : '$selectedBrand Carro';
                        final nameText = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : modelText.split(' ').first;
                        final odoVal = int.tryParse(odoCtrl.text.replaceAll('.', '').trim()) ?? 0;
                        final tankVal = double.tryParse(tankCtrl.text.replaceAll(',', '.').trim()) ?? 50.0;
                        final targetVal = double.tryParse(targetCtrl.text.replaceAll(',', '.').trim()) ?? 8.5;

                        final newV = CarVehicle(
                          id: 'car-${DateTime.now().millisecondsSinceEpoch}',
                          name: nameText,
                          model: modelText,
                          brand: selectedBrand,
                          plate: plateCtrl.text.trim().toUpperCase(),
                          odometer: odoVal,
                          tankCapacity: tankVal,
                          targetConsumption: targetVal,
                        );

                        _addNewVehicle(newV);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$nameText adicionado e ativado!'),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      },
                      child: const Text('Salvar Veículo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showGarageModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Minha Garagem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                        Text('${_vehicles.length} veículo${_vehicles.length > 1 ? "s" : ""} cadastrado${_vehicles.length > 1 ? "s" : ""}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: AppTheme.textMuted,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._vehicles.map((v) {
                  final isCurrent = v.id == _activeVehicleId;
                  final vOdo = v.odometer.toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (m) => '${m[1]}.',
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppTheme.primarySoft : AppTheme.cardSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? AppTheme.primary : AppTheme.border,
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: CarBrandLogo(brandOrModel: v.brand.isNotEmpty ? v.brand : v.model, size: 40),
                      title: Text(
                        v.name.isNotEmpty ? v.name : v.model,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isCurrent ? AppTheme.primary : AppTheme.textMain,
                        ),
                      ),
                      subtitle: Text(
                        '${v.model} · $vOdo km${v.plate.isNotEmpty ? " · ${v.plate}" : ""}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      trailing: isCurrent
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('ATIVO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            )
                          : const Icon(Icons.radio_button_off, color: Colors.grey, size: 20),
                      onTap: () {
                        _selectVehicle(v.id);
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar Novo Veículo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddVehicleDialog();
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
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
              CircularProgressIndicator(color: AppTheme.primary),
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
              onOpenGarage: _showGarageModal,
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
              onOpenGarage: _showGarageModal,
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
              children: [
                Expanded(child: _buildNavItem(Icons.home_outlined, Icons.home, 'Início', 0)),
                Expanded(child: _buildNavItem(Icons.history_outlined, Icons.history, 'Histórico', 1)),
                // Central Action Button (+ Registrar)
                GestureDetector(
                  onTap: _showSpeedDialMenu,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary,
                          AppTheme.primaryDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                ),
                Expanded(child: _buildNavItem(Icons.insights_outlined, Icons.insights, 'Análise', 2)),
                Expanded(child: _buildNavItem(Icons.directions_car_outlined, Icons.directions_car, 'Veículo', 3)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildNavItem(IconData outlineIcon, IconData filledIcon, String label, int index) {
    final isSel = _currentIndex == index;
    final color = isSel ? AppTheme.primary : AppTheme.textMuted;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSel ? filledIcon : outlineIcon, color: color, size: 22),
            const SizedBox(height: 2),
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
  final VoidCallback onOpenGarage;
  final VoidCallback onNavigateToHistory;
  final VoidCallback onNavigateToVehicle;

  const HomeOverviewTab({
    super.key,
    required this.vehicle,
    required this.events,
    required this.latestOdometer,
    required this.onOpenFueling,
    required this.onOpenGarage,
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
        // App Brand Header (sem botões conforme solicitação)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
          ],
        ),
        const SizedBox(height: 16),

        // Seletor de Veículo (Card com Logo OEM)
        InkWell(
          onTap: onOpenGarage,
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
                CarBrandLogo(
                  brandOrModel: vehicle.brand.isNotEmpty ? vehicle.brand : vehicle.model,
                  size: 42,
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
                        '${vehicle.name.isNotEmpty ? vehicle.name : "Carro"} · $odoFormatted km',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Garagem',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.primary),
                    ],
                  ),
                ),
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
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('Etanol / Cidade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.primary)),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
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
                child: Text('Ver histórico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
// 3. ANÁLISE (ANALYTICS TAB) & GRÁFICOS
// ==========================================

/// Custom painter for fuel price trend over time
class PriceTrendPainter extends CustomPainter {
  final List<CarEvent> events;
  final Color color;

  PriceTrendPainter({required this.events, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final valid = events.where((e) => e.pricePerLiter > 0).toList();
    if (valid.isEmpty) return;

    final prices = valid.map((e) => e.pricePerLiter).toList();
    final minP = prices.reduce(math.min);
    final maxP = prices.reduce(math.max);
    final range = (maxP - minP) > 0 ? (maxP - minP) : 0.5;

    final path = Path();
    final fillPath = Path();
    final stepX = prices.length > 1 ? size.width / (prices.length - 1) : size.width;
    final points = <Offset>[];

    for (int i = 0; i < prices.length; i++) {
      final x = i * stepX;
      final normY = (prices[i] - minP) / range;
      final y = size.height - (normY * (size.height - 24) + 12);
      points.add(Offset(x, y));
    }

    if (points.length == 1) {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 5, Paint()..color = color);
      return;
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

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    for (final pt in points) {
      canvas.drawCircle(pt, 3.5, Paint()..color = color);
      canvas.drawCircle(pt, 1.8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for monthly spending bar chart
class MonthlyBarsPainter extends CustomPainter {
  final List<MapEntry<String, double>> monthlyData;
  final Color barColor;
  final Color textColor;

  MonthlyBarsPainter({
    required this.monthlyData,
    required this.barColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (monthlyData.isEmpty) return;

    final maxVal = monthlyData.map((e) => e.value).fold(0.0, math.max);
    final ceiling = maxVal > 0 ? maxVal * 1.18 : 100.0;

    final count = monthlyData.length;
    final slotWidth = size.width / count;
    final barWidth = slotWidth * 0.52;

    for (int i = 0; i < count; i++) {
      final item = monthlyData[i];
      final x = (i * slotWidth) + (slotWidth - barWidth) / 2;
      final barHeight = item.value > 0 ? (item.value / ceiling) * (size.height - 36) : 4.0;
      final y = size.height - 20 - barHeight;

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            barColor,
            barColor.withValues(alpha: 0.60),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));

      canvas.drawRRect(rrect, paint);

      // Month Label
      final labelSpan = TextSpan(
        text: item.key,
        style: TextStyle(color: textColor, fontSize: 9.5, fontWeight: FontWeight.w600),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(x + (barWidth - labelPainter.width) / 2, size.height - 15));

      // Value on top (R$)
      if (item.value > 0) {
        final valText = item.value >= 1000 ? '${(item.value / 1000).toStringAsFixed(1)}k' : item.value.toStringAsFixed(0);
        final valSpan = TextSpan(
          text: valText,
          style: TextStyle(color: barColor, fontSize: 9, fontWeight: FontWeight.bold),
        );
        final valPainter = TextPainter(
          text: valSpan,
          textDirection: TextDirection.ltr,
        );
        valPainter.layout();
        valPainter.paint(canvas, Offset(x + (barWidth - valPainter.width) / 2, y - 13));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnalyticsTab extends StatefulWidget {
  final CarVehicle vehicle;
  final List<CarEvent> events;

  const AnalyticsTab({
    super.key,
    required this.vehicle,
    required this.events,
  });

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  String _selectedPeriod = 'Todos';
  String _selectedType = 'Todos';

  @override
  Widget build(BuildContext context) {
    final vEvents = widget.events.where((e) => e.vehicleId == widget.vehicle.id).toList();
    final baseEvents = vEvents.isNotEmpty ? vEvents : widget.events;

    // Filter by period
    final now = DateTime.now();
    final periodEvents = baseEvents.where((e) {
      final d = e.parsedDate;
      if (_selectedPeriod == '30 dias') {
        return now.difference(d).inDays <= 30;
      } else if (_selectedPeriod == '3 meses') {
        return now.difference(d).inDays <= 90;
      } else if (_selectedPeriod == '6 meses') {
        return now.difference(d).inDays <= 180;
      } else if (_selectedPeriod == 'Este Ano') {
        return d.year == now.year;
      }
      return true;
    }).toList();

    // Type subsets
    final fuelEvents = periodEvents.where((e) => e.type == 'fuel').toList();
    final serviceEvents = periodEvents.where((e) => e.type == 'service').toList();
    final expenseEvents = periodEvents.where((e) => e.type == 'expense').toList();

    // Totals
    final totalSpentPeriod = periodEvents.fold(0.0, (sum, e) => sum + e.amount);
    final fuelSpent = fuelEvents.fold(0.0, (sum, e) => sum + e.amount);
    final serviceSpent = serviceEvents.fold(0.0, (sum, e) => sum + e.amount);
    final expenseSpent = expenseEvents.fold(0.0, (sum, e) => sum + e.amount);
    final totalLiters = fuelEvents.fold(0.0, (sum, e) => sum + e.liters);

    // Consumption calculation
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
    if (avgConsumption <= 0 || avgConsumption > 25) {
      // Fallback to vehicle's target consumption or realistic default
      avgConsumption = widget.vehicle.targetConsumption > 0 ? widget.vehicle.targetConsumption : 8.4;
    }

    // Cost per km
    double costPerKm = 0.0;
    if (fuelEvents.length >= 2) {
      final odoDelta = fuelEvents.first.odometer - fuelEvents.last.odometer;
      if (odoDelta > 0) {
        costPerKm = fuelSpent / odoDelta;
      }
    }
    if (costPerKm <= 0 || costPerKm > 5) costPerKm = 0.68;

    // Average price per liter
    double avgPricePerLiter = 0.0;
    final validPpl = fuelEvents.where((e) => e.pricePerLiter > 0).toList();
    if (validPpl.isNotEmpty) {
      avgPricePerLiter = validPpl.fold(0.0, (sum, e) => sum + e.pricePerLiter) / validPpl.length;
    } else {
      avgPricePerLiter = 5.75;
    }

    // Range with full tank
    final estimatedRange = (widget.vehicle.tankCapacity * avgConsumption).round();

    // Prepare Monthly Bars Data (last 6 distinct months)
    final monthlyMap = <String, double>{};
    for (final e in periodEvents) {
      final key = DateFormat('MMM/yy', 'pt_BR').format(e.parsedDate);
      monthlyMap[key] = (monthlyMap[key] ?? 0.0) + e.amount;
    }
    final monthlyEntries = monthlyMap.entries.toList().reversed.take(6).toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Análise & Estatísticas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Text(
                widget.vehicle.name,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Filtro de Período
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Todos', '30 dias', '3 meses', '6 meses', 'Este Ano'].map((p) {
              final isSel = _selectedPeriod == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p),
                  selected: isSel,
                  onSelected: (_) => setState(() => _selectedPeriod = p),
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
        const SizedBox(height: 14),

        // 4 KPIs Principais
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildMetricTile('Consumo Médio', '${avgConsumption.toStringAsFixed(1).replaceAll('.', ',')} km/L', Icons.speed, AppTheme.primary),
            _buildMetricTile('Custo por Km', 'R\$ ${costPerKm.toStringAsFixed(2).replaceAll('.', ',')}', Icons.route, AppTheme.primary),
            _buildMetricTile('Preço Médio / L', 'R\$ ${avgPricePerLiter.toStringAsFixed(2).replaceAll('.', ',')}', Icons.local_gas_station, AppTheme.accentAmber),
            _buildMetricTile('Gasto no Período', 'R\$ ${totalSpentPeriod.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}', Icons.account_balance_wallet, AppTheme.servicePurple),
          ],
        ),
        const SizedBox(height: 14),

        // Faixa de Resumo Rápido (Autonomia + Volume + Registros)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Autonomia Est.', '$estimatedRange km', Icons.local_gas_station_outlined),
              Container(width: 1, height: 24, color: AppTheme.border),
              _buildMiniStat('Volume Comb.', '${totalLiters.toStringAsFixed(0)} L', Icons.water_drop_outlined),
              Container(width: 1, height: 24, color: AppTheme.border),
              _buildMiniStat('Registros', '${periodEvents.length}', Icons.format_list_bulleted),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Gráfico 1: Evolução do Consumo (km/L)
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
                      Text('Evolução do Consumo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                      Text('Histórico de eficiência (km/L)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                  Text(
                    '${avgConsumption.toStringAsFixed(1).replaceAll('.', ',')} km/L',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  painter: ConsumptionCurvePainter(
                    events: fuelEvents.take(12).toList().reversed.toList(),
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gráfico 2: Tendência do Preço por Litro (R$/L)
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
                      Text('Tendência do Preço do Combustível', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                      Text('Valor pago por litro no período (R\$/L)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                  Text(
                    'R\$ ${avgPricePerLiter.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentAmber),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  painter: PriceTrendPainter(
                    events: fuelEvents.take(12).toList().reversed.toList(),
                    color: AppTheme.accentAmber,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gráfico 3: Comparativo Mensal de Gastos (Barras)
        if (monthlyEntries.isNotEmpty) ...[
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
                        Text('Gastos Mensais', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                        Text('Comparativo entre os últimos meses (R\$)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                    Text(
                      'Total R\$ ${totalSpentPeriod.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: MonthlyBarsPainter(
                      monthlyData: monthlyEntries,
                      barColor: AppTheme.primary,
                      textColor: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Gráfico 4: Distribuição por Categoria
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
              Text('Distribuição de Despesas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              Text('Proporção de gastos por tipo', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 14),
              _buildCategoryBar(
                label: 'Combustível',
                amount: fuelSpent,
                total: totalSpentPeriod,
                color: AppTheme.accentAmber,
                icon: Icons.local_gas_station,
              ),
              const SizedBox(height: 10),
              _buildCategoryBar(
                label: 'Serviços & Peças',
                amount: serviceSpent,
                total: totalSpentPeriod,
                color: AppTheme.servicePurple,
                icon: Icons.build,
              ),
              const SizedBox(height: 10),
              _buildCategoryBar(
                label: 'Outras Despesas',
                amount: expenseSpent,
                total: totalSpentPeriod,
                color: AppTheme.expenseBlue,
                icon: Icons.receipt_long,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Dica de Eficiência
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardSubtle,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.insights, color: AppTheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Com base na meta de ${widget.vehicle.targetConsumption.toStringAsFixed(1)} km/L, o tanque de ${widget.vehicle.tankCapacity.toStringAsFixed(0)}L garante autonomia de ~$estimatedRange km por abastecimento.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMain),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCategoryBar({
    required String label,
    required double amount,
    required double total,
    required Color color,
    required IconData icon,
  }) {
    final pct = total > 0 ? (amount / total) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              ],
            ),
            Text(
              '${(pct * 100).toStringAsFixed(0)}% · R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppTheme.cardSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppTheme.primary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
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
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
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
  final VoidCallback onOpenGarage;
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
    required this.onOpenGarage,
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
        Text('Veículo & Garagem', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        const SizedBox(height: 16),

        // Cartão do Veículo com Logo da Marca OEM
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
                  Row(
                    children: [
                      CarBrandLogo(
                        brandOrModel: vehicle.brand.isNotEmpty ? vehicle.brand : vehicle.model,
                        size: 46,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.name.isNotEmpty ? vehicle.name : vehicle.model,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                          ),
                          Text(
                            '${vehicle.model} · Tanque ${vehicle.tankCapacity.toStringAsFixed(0)}L',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(12)),
                    child: Text('ATIVO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.garage_outlined, size: 16),
                  label: const Text('Minha Garagem / Trocar Veículo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: onOpenGarage,
                ),
              ),
              const SizedBox(height: 14),
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

        // Aparência & Personalização
        Text('APARÊNCIA & PERSONALIZAÇÃO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.textMuted)),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDarkMode.value ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isDarkMode.value ? 'Modo Escuro (Cockpit)' : 'Modo Claro',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                      ),
                    ],
                  ),
                  Switch(
                    value: isDarkMode.value,
                    activeColor: AppTheme.primary,
                    onChanged: (val) async {
                      isDarkMode.value = val;
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('finanza_auto_is_dark', val);
                      } catch (_) {}
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cor de Destaque',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                  ),
                  Text(
                    primaryColorNotifier.value.name,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: appPrimaryColors.map((themeColor) {
                  final isSelected = primaryColorNotifier.value.color.value == themeColor.color.value;
                  return GestureDetector(
                    onTap: () async {
                      primaryColorNotifier.value = themeColor;
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('finanza_primary_color', themeColor.color.value);
                      } catch (_) {}
                    },
                    child: Tooltip(
                      message: themeColor.name,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: themeColor.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.color.withValues(alpha: isSelected ? 0.5 : 0.2),
                              blurRadius: isSelected ? 8 : 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    ),
                  );
                }).toList(),
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
              child: Text('+ Novo lembrete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
        SnackBar(
                      content: const Text('Informe ao menos o Odômetro e o Valor Total.')),
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
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
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
                prefixIcon: Icon(Icons.speed, color: AppTheme.primary, size: 20),
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
                    Text(
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
        SnackBar(
                      content: const Text('Informe a descrição e o valor.')),
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
        SnackBar(
                      content: const Text('Informe o título do lembrete.')),
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
