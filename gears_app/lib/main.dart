import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const GearSimulationApp());
}

class GearSimulationApp extends StatelessWidget {
  const GearSimulationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gear Simulation',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.system,
      home: const GearWorkspace(),
    );
  }
}

// Model for a single gear
class Gear {
  String id;
  Offset position;
  double radius; // Visual radius in pixels
  int teethCount;
  double angle; // Current rotation angle
  double angularVelocity;
  bool isFixed; // If true, this gear doesn't move
  bool isDriver; // If true, this gear is powered
  List<String> connectedGears; // Gears connected via chain/belt
  String? compoundWith; // ID of gear this is compounded with (same axle)
  Color color;

  Gear({
    required this.id,
    required this.position,
    required this.radius,
    required this.teethCount,
    this.angle = 0,
    this.angularVelocity = 0,
    this.isFixed = false,
    this.isDriver = false,
    this.connectedGears = const [],
    this.compoundWith,
    Color? color,
  }) : color = color ?? Colors.grey;

  // Calculate pitch radius based on teeth count (for proper meshing)
  double get pitchRadius => radius * 0.85;
}

// Model for a connection between gears (chain or belt)
class GearConnection {
  String id;
  String gear1Id;
  String gear2Id;
  bool isCrossed; // If true, belt is crossed (reverses direction)

  GearConnection({
    required this.id,
    required this.gear1Id,
    required this.gear2Id,
    this.isCrossed = false,
  });
}

class GearWorkspace extends StatefulWidget {
  const GearWorkspace({super.key});

  @override
  State<GearWorkspace> createState() => _GearWorkspaceState();
}

class _GearWorkspaceState extends State<GearWorkspace> with TickerProviderStateMixin {
  final Map<String, Gear> _gears = {};
  final List<GearConnection> _connections = [];
  String? _selectedGearId;
  String? _draggingGearId;
  String? _connectionStartGearId;
  bool _isSimulating = false;
  AnimationController? _simulationController;
  
  // Properties for new gear
  int _newTeethCount = 20;
  double _newSizeMultiplier = 1.0;
  
  // Display options
  bool _showTeeth = true;
  bool _showConnectionLines = true;

  @override
  void dispose() {
    _simulationController?.dispose();
    super.dispose();
  }

  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString() + 
                          math.Random().nextInt(1000).toString();

  double _calculateGearRadius(int teeth) {
    // Radius proportional to teeth count for proper meshing
    return 20 + (teeth * 2.5);
  }

  void _addGear(Offset position) {
    final radius = _calculateGearRadius(_newTeethCount) * _newSizeMultiplier;
    final gear = Gear(
      id: _generateId(),
      position: position,
      radius: radius,
      teethCount: _newTeethCount,
      color: Color((math.Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0),
    );
    setState(() {
      _gears[gear.id] = gear;
    });
  }

  void _removeGear(String gearId) {
    setState(() {
      _gears.remove(gearId);
      _connections.removeWhere((c) => c.gear1Id == gearId || c.gear2Id == gearId);
      // Remove compound references
      for (var gear in _gears.values) {
        if (gear.compoundWith == gearId) {
          gear.compoundWith = null;
        }
      }
      if (_selectedGearId == gearId) {
        _selectedGearId = null;
      }
    });
  }

  void _toggleDriver(String gearId) {
    setState(() {
      for (var gear in _gears.values) {
        gear.isDriver = false;
      }
      _gears[gearId]?.isDriver = !_gears[gearId]!.isDriver;
    });
  }

  void _toggleFixed(String gearId) {
    setState(() {
      _gears[gearId]?.isFixed = !_gears[gearId]!.isFixed;
    });
  }

  void _createCompound(String gearId1, String gearId2) {
    setState(() {
      _gears[gearId1]?.compoundWith = gearId2;
      _gears[gearId2]?.compoundWith = gearId1;
    });
  }

  void _addConnection(String gearId1, String gearId2) {
    // Check if connection already exists
    final exists = _connections.any((c) => 
      (c.gear1Id == gearId1 && c.gear2Id == gearId2) ||
      (c.gear1Id == gearId2 && c.gear2Id == gearId1)
    );
    
    if (!exists && gearId1 != gearId2) {
      setState(() {
        _connections.add(GearConnection(
          id: _generateId(),
          gear1Id: gearId1,
          gear2Id: gearId2,
        ));
      });
    }
  }

  void _startSimulation() {
    if (_simulationController != null) {
      _stopSimulation();
      return;
    }

    _simulationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );

    _simulationController!.addListener(() {
      _updateGearPhysics();
    });

    setState(() {
      _isSimulating = true;
    });
    _simulationController!.repeat();
  }

  void _stopSimulation() {
    _simulationController?.stop();
    _simulationController?.dispose();
    _simulationController = null;
    setState(() {
      _isSimulating = false;
    });
  }

  void _updateGearPhysics() {
    final dt = 0.016; // Approximate delta time in seconds
    final baseSpeed = 2.0; // Radians per second

    // Reset velocities
    for (var gear in _gears.values) {
      gear.angularVelocity = 0;
    }

    // Set driver gear velocity
    for (var gear in _gears.values) {
      if (gear.isDriver && !gear.isFixed) {
        gear.angularVelocity = baseSpeed;
      }
    }

    // Propagate velocities through meshed gears
    var changed = true;
    var iterations = 0;
    while (changed && iterations < 100) {
      changed = false;
      iterations++;

      for (var gear1 in _gears.values) {
        if (gear1.isFixed) continue;

        for (var gear2 in _gears.values) {
          if (gear1.id == gear2.id || gear2.isFixed) continue;

          // Check if gears are meshed (touching)
          final distance = (gear1.position - gear2.position).distance;
          final meshDistance = gear1.pitchRadius + gear2.pitchRadius;
          
          if ((distance - meshDistance).abs() < 5) {
            // Gears are meshed
            if (gear1.angularVelocity != 0 && gear2.angularVelocity == 0) {
              // Transfer velocity from gear1 to gear2
              final ratio = gear1.teethCount / gear2.teethCount;
              gear2.angularVelocity = -gear1.angularVelocity * ratio;
              changed = true;
            } else if (gear2.angularVelocity != 0 && gear1.angularVelocity == 0) {
              // Transfer velocity from gear2 to gear1
              final ratio = gear2.teethCount / gear1.teethCount;
              gear1.angularVelocity = -gear2.angularVelocity * ratio;
              changed = true;
            }
          }
        }

        // Handle compound gears
        if (gear1.compoundWith != null) {
          final compoundGear = _gears[gear1.compoundWith];
          if (compoundGear != null && !compoundGear.isFixed) {
            if (gear1.angularVelocity != 0 && compoundGear.angularVelocity == 0) {
              compoundGear.angularVelocity = gear1.angularVelocity;
              changed = true;
            } else if (compoundGear.angularVelocity != 0 && gear1.angularVelocity == 0) {
              gear1.angularVelocity = compoundGear.angularVelocity;
              changed = true;
            }
          }
        }
      }
    }

    // Update angles
    setState(() {
      for (var gear in _gears.values) {
        if (!gear.isFixed) {
          gear.angle += gear.angularVelocity * dt;
        }
      }
    });
  }

  void _resetSimulation() {
    _stopSimulation();
    setState(() {
      for (var gear in _gears.values) {
        gear.angle = 0;
        gear.angularVelocity = 0;
        gear.isDriver = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gear Simulation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isSimulating ? Icons.pause : Icons.play_arrow),
            onPressed: _startSimulation,
            tooltip: _isSimulating ? 'Pause' : 'Play',
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: _resetSimulation,
            tooltip: 'Reset',
          ),
          IconButton(
            icon: Icon(_showTeeth ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showTeeth = !_showTeeth),
            tooltip: 'Toggle Teeth',
          ),
        ],
      ),
      body: Row(
        children: [
          // Main workspace
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                // Check if clicking on empty space
                final renderBox = context.findRenderObject() as RenderBox;
                final position = renderBox.globalToLocal(details.globalPosition);
                
                bool clickedOnGear = false;
                for (var gear in _gears.values) {
                  if ((gear.position - position).distance < gear.radius) {
                    clickedOnGear = true;
                    break;
                  }
                }
                
                if (!clickedOnGear && _connectionStartGearId == null) {
                  _addGear(position);
                }
              },
              child: CustomPaint(
                painter: GearPainter(
                  gears: _gears.values.toList(),
                  connections: _connections,
                  selectedGearId: _selectedGearId,
                  connectionStartGearId: _connectionStartGearId,
                  showTeeth: _showTeeth,
                  showConnectionLines: _showConnectionLines,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          // Control panel
          Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Controls',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // New gear settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('New Gear Settings', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Teeth: '),
                              Expanded(
                                child: Slider(
                                  value: _newTeethCount.toDouble(),
                                  min: 8,
                                  max: 60,
                                  divisions: 26,
                                  label: _newTeethCount.toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      _newTeethCount = value.round();
                                    });
                                  },
                                ),
                              ),
                              Text(_newTeethCount.toString()),
                            ],
                          ),
                          Row(
                            children: [
                              const Text('Size: '),
                              Expanded(
                                child: Slider(
                                  value: _newSizeMultiplier,
                                  min: 0.5,
                                  max: 2.0,
                                  divisions: 15,
                                  label: _newSizeMultiplier.toStringAsFixed(1),
                                  onChanged: (value) {
                                    setState(() {
                                      _newSizeMultiplier = value;
                                    });
                                  },
                                ),
                              ),
                              Text(_newSizeMultiplier.toStringAsFixed(1)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Selected gear controls
                  if (_selectedGearId != null && _gears[_selectedGearId] != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Selected Gear', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Teeth: ${_gears[_selectedGearId]!.teethCount}'),
                            Text('Radius: ${_gears[_selectedGearId]!.radius.toStringAsFixed(1)}'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(
                                      _gears[_selectedGearId]!.isDriver 
                                        ? Icons.bolt 
                                        : Icons.bolt_outlined
                                    ),
                                    label: const Text('Driver'),
                                    onPressed: () => _toggleDriver(_selectedGearId!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _gears[_selectedGearId]!.isDriver 
                                        ? Colors.amber 
                                        : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(
                                      _gears[_selectedGearId]!.isFixed 
                                        ? Icons.lock 
                                        : Icons.lock_open
                                    ),
                                    label: const Text('Fixed'),
                                    onPressed: () => _toggleFixed(_selectedGearId!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _gears[_selectedGearId]!.isFixed 
                                        ? Colors.red 
                                        : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.delete),
                              label: const Text('Delete Gear'),
                              onPressed: () {
                                _removeGear(_selectedGearId!);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Connection mode
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Connect Gears', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text(
                            'Click two gears to connect them with a belt/chain.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          if (_connectionStartGearId != null)
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _connectionStartGearId = null;
                                });
                              },
                              child: const Text('Cancel Connection'),
                            )
                          else
                            const Text(
                              'Select a gear first, then click "Start Connection"',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.link),
                            label: const Text('Start Connection'),
                            onPressed: _selectedGearId != null
                                ? () {
                                    setState(() {
                                      _connectionStartGearId = _selectedGearId;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Compound gear creation
                  if (_selectedGearId != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Compound Gears', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text(
                              'Select two overlapping gears to compound them (same axle).',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Instructions', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text(
                            '• Click on empty space to add a gear\n'
                            '• Drag gears to move them\n'
                            '• Select a gear to see options\n'
                            '• Set a gear as "Driver" to power it\n'
                            '• Mesh gears together for automatic rotation\n'
                            '• Use connections for belt/chain drives',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GearPainter extends CustomPainter {
  final List<Gear> gears;
  final List<GearConnection> connections;
  final String? selectedGearId;
  final String? connectionStartGearId;
  final bool showTeeth;
  final bool showConnectionLines;

  GearPainter({
    required this.gears,
    required this.connections,
    required this.selectedGearId,
    required this.connectionStartGearId,
    required this.showTeeth,
    required this.showConnectionLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections first (behind gears)
    if (showConnectionLines) {
      _drawConnections(canvas);
    }

    // Draw gears
    for (var gear in gears) {
      _drawGear(canvas, gear);
    }

    // Draw selection highlight
    if (selectedGearId != null) {
      final gear = gears.firstWhere((g) => g.id == selectedGearId, orElse: () => gears.first);
      _drawSelectionHighlight(canvas, gear);
    }
  }

  void _drawConnections(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.brown
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (var conn in connections) {
      final gear1 = gears.firstWhere((g) => g.id == conn.gear1Id, orElse: () => gears.first);
      final gear2 = gears.firstWhere((g) => g.id == conn.gear2Id, orElse: () => gears.first);

      if (conn.isCrossed) {
        // Draw crossed belt
        final path = Path();
        path.moveTo(gear1.position.dx, gear1.position.dy);
        path.lineTo(gear2.position.dx, gear2.position.dy);
        canvas.drawPath(path, paint);
      } else {
        // Draw parallel belt
        final dx = gear2.position.dx - gear1.position.dx;
        final dy = gear2.position.dy - gear1.position.dy;
        final distance = math.sqrt(dx * dx + dy * dy);
        final angle = math.atan2(dy, dx);
        
        final offsetX = math.cos(angle) * gear1.radius;
        final offsetY = math.sin(angle) * gear1.radius;
        
        final path = Path();
        path.moveTo(
          gear1.position.dx + offsetX * 0.8,
          gear1.position.dy + offsetY * 0.8,
        );
        path.lineTo(
          gear2.position.dx - offsetX * 0.8 * (gear2.radius / gear1.radius),
          gear2.position.dy - offsetY * 0.8 * (gear2.radius / gear1.radius),
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawGear(Canvas canvas, Gear gear) {
    // Save canvas state
    canvas.save();
    
    // Translate to gear position and rotate
    canvas.translate(gear.position.dx, gear.position.dy);
    canvas.rotate(gear.angle);

    // Gear body paint
    final bodyPaint = Paint()
      ..color = gear.color
      ..style = PaintingStyle.fill;

    // Gear outline paint
    final outlinePaint = Paint()
      ..color = gear.color.darker()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw gear body (circle)
    canvas.drawCircle(Offset.zero, gear.radius, bodyPaint);
    canvas.drawCircle(Offset.zero, gear.radius, outlinePaint);

    // Draw teeth
    if (showTeeth) {
      final toothPaint = Paint()
        ..color = gear.color.darker()
        ..style = PaintingStyle.fill;

      final toothHeight = gear.radius * 0.15;
      final toothWidth = (2 * math.pi * gear.radius) / (gear.teethCount * 2);

      for (int i = 0; i < gear.teethCount; i++) {
        final angle = (2 * math.pi / gear.teethCount) * i;
        
        final outerRadius = gear.radius + toothHeight;
        final innerRadius = gear.radius;
        
        final path = Path();
        path.moveTo(
          math.cos(angle) * innerRadius,
          math.sin(angle) * innerRadius,
        );
        path.lineTo(
          math.cos(angle - toothWidth / 2 / gear.radius) * outerRadius,
          math.sin(angle - toothWidth / 2 / gear.radius) * outerRadius,
        );
        path.lineTo(
          math.cos(angle + toothWidth / 2 / gear.radius) * outerRadius,
          math.sin(angle + toothWidth / 2 / gear.radius) * outerRadius,
        );
        path.close();
        
        canvas.drawPath(path, toothPaint);
      }
    }

    // Draw center hole
    final holePaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset.zero, gear.radius * 0.15, holePaint);
    
    // Draw center marker (to show rotation)
    final markerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, -gear.radius * 0.5),
      markerPaint,
    );

    // Restore canvas state
    canvas.restore();

    // Draw driver indicator (outside the rotated area)
    if (gear.isDriver) {
      final boltPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(gear.position.dx, gear.position.dy - gear.radius - 15),
        8,
        boltPaint,
      );
      
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '⚡',
          style: TextStyle(fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          gear.position.dx - 6,
          gear.position.dy - gear.radius - 21,
        ),
      );
    }

    // Draw fixed indicator
    if (gear.isFixed) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '🔒',
          style: TextStyle(fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          gear.position.dx - 7,
          gear.position.dy - 7,
        ),
      );
    }
  }

  void _drawSelectionHighlight(Canvas canvas, Gear gear) {
    final highlightPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(gear.position, gear.radius + 5, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant GearPainter oldDelegate) {
    return oldDelegate.gears != gears ||
           oldDelegate.connections != connections ||
           oldDelegate.selectedGearId != selectedGearId ||
           oldDelegate.connectionStartGearId != connectionStartGearId;
  }
}

// Extension to get darker color
extension ColorExtension on Color {
  Color darker() {
    return Color.fromRGBO(
      (red * 0.7).round(),
      (green * 0.7).round(),
      (blue * 0.7).round(),
      opacity,
    );
  }
}
