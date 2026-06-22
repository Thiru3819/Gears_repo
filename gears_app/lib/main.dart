import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GearSimulationApp(),
  ));
}

class GearSimulationApp extends StatefulWidget {
  const GearSimulationApp({super.key});

  @override
  State<GearSimulationApp> createState() => _GearSimulationAppState();
}

class _GearSimulationAppState extends State<GearSimulationApp> with TickerProviderStateMixin {
  final List<Gear> gears = [];
  Gear? selectedGear;
  bool isSimulating = false;
  AnimationController? _animationController;
  final double baseSpeed = 3.0;

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _toggleSimulation() {
    if (isSimulating) {
      _animationController?.stop();
    } else {
      if (_animationController == null) {
        _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            setState(() => _updatePhysics());
          });
      }
      _calculateGearTrain();
      _animationController?.repeat();
    }
    setState(() => isSimulating = !isSimulating);
  }

  void _updatePhysics() {
    if (!isSimulating) return;
    double dt = 0.016;
    for (var g in gears) {
      if (!g.isFixed) g.angle += g.angularVelocity * dt;
    }
  }

  void _calculateGearTrain() {
    for (var g in gears) {
      if (!g.isDriver) g.angularVelocity = 0;
    }
    for (var g in gears) {
      if (g.isDriver) g.angularVelocity = baseSpeed * (g.isReversed ? -1 : 1);
    }

    bool changed = true;
    int iterations = 0;
    while (changed && iterations < 10) {
      changed = false;
      iterations++;
      for (var g in gears) {
        if (g.angularVelocity == 0 && !g.isFixed) continue;
        for (var neighborId in g.connectedTo) {
          var neighbor = gears.firstWhere((x) => x.id == neighborId, orElse: () => gears[0]);
          if (neighbor.isFixed) continue;
          double ratio = g.teeth / neighbor.teeth;
          double expectedVel = -g.angularVelocity * ratio;
          if (!neighbor.isDriver && (neighbor.angularVelocity == 0 || (neighbor.angularVelocity - expectedVel).abs() > 0.01)) {
            neighbor.angularVelocity = expectedVel;
            changed = true;
          }
        }
      }
    }
  }

  void _addGear(Offset position) {
    for (var g in gears) {
      double dist = math.sqrt(math.pow(position.dx - g.x, 2) + math.pow(position.dy - g.y, 2));
      if (dist < g.radius * 1.2) {
        setState(() {
          selectedGear = g;
        });
        return;
      }
    }
    setState(() {
      gears.add(Gear(
        id: DateTime.now().millisecondsSinceEpoch,
        x: position.dx,
        y: position.dy,
        teeth: 20,
        radius: 30.0,
        angle: 0,
        isDriver: false,
        isFixed: false,
        isReversed: false,
        angularVelocity: 0,
        connectedTo: [],
      ));
      selectedGear = gears.last;
      _checkConnections();
    });
  }

  void _checkConnections() {
    for (var g in gears) g.connectedTo.clear();
    for (int i = 0; i < gears.length; i++) {
      for (int j = i + 1; j < gears.length; j++) {
        var g1 = gears[i];
        var g2 = gears[j];
        double dist = math.sqrt(math.pow(g1.x - g2.x, 2) + math.pow(g1.y - g2.y, 2));
        double idealDist = g1.radius + g2.radius;
        if ((dist - idealDist).abs() < 8.0) {
          g1.connectedTo.add(g2.id);
          g2.connectedTo.add(g1.id);
          double angle = math.atan2(g2.y - g1.y, g2.x - g1.x);
          g2.x = g1.x + math.cos(angle) * idealDist;
          g2.y = g1.y + math.sin(angle) * idealDist;
        }
      }
    }
  }

  void _updateSelectedGear(Property prop, double value) {
    if (selectedGear == null) return;
    setState(() {
      if (prop == Property.teeth) {
        selectedGear!.teeth = value.toInt();
        selectedGear!.radius = (selectedGear!.teeth / 20.0) * 30.0;
        _checkConnections();
      }
    });
  }

  void _deleteSelected() {
    if (selectedGear != null) {
      setState(() {
        gears.remove(selectedGear);
        selectedGear = null;
        _checkConnections();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: Stack(
        children: [
          GestureDetector(
            onTapDown: (details) => _addGear(details.localPosition),
            child: CustomPaint(
              size: Size.infinite,
              painter: GearScenePainter(gears: gears, selectedGear: selectedGear),
              child: Stack(
                children: gears.map((gear) {
                  return Positioned(
                    left: gear.x - gear.radius - 20,
                    top: gear.y - gear.radius - 20,
                    width: gear.radius * 2 + 40,
                    height: gear.radius * 2 + 40,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => selectedGear = gear),
                      onPanStart: (_) => setState(() => selectedGear = gear),
                      onPanUpdate: (details) {
                        setState(() {
                          gear.x += details.delta.dx;
                          gear.y += details.delta.dy;
                          _checkConnections();
                        });
                      },
                      onPanEnd: (_) => _checkConnections(),
                      child: Container(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: _buildControlPanel(),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Row(
              children: [
                FloatingActionButton.extended(
                  onPressed: _toggleSimulation,
                  icon: Icon(isSimulating ? Icons.pause : Icons.play_arrow),
                  label: Text(isSimulating ? "Pause" : "Simulate"),
                  backgroundColor: isSimulating ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      gears.clear();
                      selectedGear = null;
                      isSimulating = false;
                      _animationController?.stop();
                    });
                  },
                  child: const Icon(Icons.delete_sweep),
                  backgroundColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    if (selectedGear == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Text("Click a gear to edit\nClick empty space to add", style: TextStyle(color: Colors.white70, fontSize: 14)),
      );
    }
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF2D2D44), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Gear Properties", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(color: Colors.white24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateSelectedGear(Property.teeth, (selectedGear!.teeth - 2).clamp(8, 60).toDouble()),
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text("Teeth"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                ),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text("${selectedGear!.teeth}", style: const TextStyle(color: Colors.white))),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateSelectedGear(Property.teeth, (selectedGear!.teeth + 2).clamp(8, 60).toDouble()),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(""),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text("Driver", style: TextStyle(color: Colors.white, fontSize: 12)),
            value: selectedGear!.isDriver,
            onChanged: (v) => setState(() => selectedGear!.isDriver = v!),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.green,
          ),
          CheckboxListTile(
            title: const Text("Fixed", style: TextStyle(color: Colors.white, fontSize: 12)),
            value: selectedGear!.isFixed,
            onChanged: (v) => setState(() => selectedGear!.isFixed = v!),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.red,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _deleteSelected,
            child: const Text("Delete", style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

enum Property { teeth, size }

class Gear {
  final int id;
  double x, y;
  int teeth;
  double radius;
  double angle;
  double angularVelocity;
  bool isDriver;
  bool isFixed;
  bool isReversed;
  List<int> connectedTo;

  Gear({
    required this.id,
    required this.x,
    required this.y,
    required this.teeth,
    required this.radius,
    required this.angle,
    this.isDriver = false,
    this.isFixed = false,
    this.isReversed = false,
    this.angularVelocity = 0,
    required this.connectedTo,
  });
}

class GearScenePainter extends CustomPainter {
  final List<Gear> gears;
  final Gear? selectedGear;

  GearScenePainter({required this.gears, this.selectedGear});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections
    final linePaint = Paint()..color = Colors.cyanAccent.withOpacity(0.6)..strokeWidth = 2..style = PaintingStyle.stroke;
    for (var g in gears) {
      for (var connId in g.connectedTo) {
        var other = gears.firstWhere((x) => x.id == connId, orElse: () => g);
        if (g.id < other.id) {
          canvas.drawLine(Offset(g.x, g.y), Offset(other.x, other.y), linePaint);
        }
      }
    }
    // Draw gears
    for (var g in gears) {
      _drawGear(canvas, g);
    }
  }

  void _drawGear(Canvas canvas, Gear g) {
    canvas.save();
    canvas.translate(g.x, g.y);
    canvas.rotate(g.angle);

    final toothPaint = Paint()
      ..color = g.isDriver ? Colors.orange : (g.isFixed ? Colors.grey : Colors.blueGrey)
      ..style = PaintingStyle.fill;

    if (g == selectedGear) {
      toothPaint.color = Colors.lightBlueAccent;
    }

    // Body
    canvas.drawCircle(Offset.zero, g.radius * 0.85, Paint()..color = toothPaint.color.withOpacity(0.8)..style = PaintingStyle.fill);

    // Square Teeth
    double circumference = 2 * math.pi * g.radius;
    double toothPitch = circumference / g.teeth;
    double toothWidth = toothPitch * 0.5;
    double toothHeight = g.radius * 0.2;
    double gapWidth = toothPitch - toothWidth;

    for (int i = 0; i < g.teeth; i++) {
      double angleStep = (2 * math.pi) / g.teeth;
      double theta = i * angleStep;
      canvas.save();
      canvas.rotate(theta);
      
      // Draw rectangular tooth
      double startAngle = -toothWidth / (2 * g.radius);
      double endAngle = toothWidth / (2 * g.radius);
      
      Path toothPath = Path();
      toothPath.moveTo(math.cos(startAngle) * g.radius * 0.85, math.sin(startAngle) * g.radius * 0.85);
      toothPath.lineTo(math.cos(startAngle) * (g.radius + toothHeight), math.sin(startAngle) * (g.radius + toothHeight));
      toothPath.lineTo(math.cos(endAngle) * (g.radius + toothHeight), math.sin(endAngle) * (g.radius + toothHeight));
      toothPath.lineTo(math.cos(endAngle) * g.radius * 0.85, math.sin(endAngle) * g.radius * 0.85);
      toothPath.close();
      
      canvas.drawPath(toothPath, toothPaint);
      canvas.restore();
    }

    // Hub
    canvas.drawCircle(Offset.zero, g.radius * 0.3, Paint()..color = Colors.white70);
    canvas.drawCircle(Offset.zero, g.radius * 0.15, Paint()..color = Colors.black54);

    // Selection ring
    if (g == selectedGear) {
      canvas.drawCircle(Offset.zero, g.radius * 1.15, Paint()..color = Colors.white..strokeWidth = 3..style = PaintingStyle.stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
