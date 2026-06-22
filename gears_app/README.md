# Gear Simulation App 🎯⚙️

An interactive Flutter application for creating, arranging, and simulating gear systems with realistic physics. Build compound gears, connect them with belts/chains, and watch them rotate in real-time!

## Features ✨

### Gear Creation & Customization
- **Add Gears**: Click anywhere on the canvas to add a new gear
- **Adjust Teeth Count**: Set the number of teeth (8-60) for each new gear
- **Size Control**: Modify gear size with a multiplier (0.5x - 2.0x)
- **Random Colors**: Each gear gets a unique random color

### Gear Properties
- **Driver Gear**: Mark a gear as the power source (indicated by ⚡)
- **Fixed Gear**: Lock a gear in place so it doesn't rotate (indicated by 🔒)
- **Delete**: Remove unwanted gears from the simulation

### Physics Simulation
- **Realistic Gear Meshing**: Gears automatically detect when they're touching and transfer rotation
- **Proper Gear Ratios**: Rotation speed is calculated based on teeth count ratio
- **Direction Reversal**: Connected meshed gears rotate in opposite directions
- **Compound Gears**: Multiple gears on the same axle rotate together at the same speed

### Visual Features
- **Animated Teeth**: Visible gear teeth that show rotation
- **Rotation Indicator**: Center line shows which direction gears are spinning
- **Selection Highlight**: Blue outline shows the currently selected gear
- **Connection Lines**: Visual belts/chains between connected gears

### Controls
- **Play/Pause**: Start or stop the simulation
- **Reset**: Stop simulation and reset all gear angles
- **Toggle Teeth**: Show/hide gear teeth for performance
- **Connect Gears**: Create belt/chain connections between gears

## How to Use 📖

1. **Add a Gear**: Click on empty space in the workspace
2. **Configure New Gear**: Use the sliders in the control panel to set teeth count and size
3. **Move Gears**: (Future feature) Drag gears to position them
4. **Select a Gear**: Click on a gear to select it
5. **Set as Driver**: Click "Driver" button to make it the power source
6. **Mesh Gears**: Position gears so their teeth overlap for automatic rotation transfer
7. **Start Simulation**: Click the play button to see your gear system in action!

## Technical Details 🔧

### Gear Physics
The simulation uses these principles:
- **Pitch Radius**: Calculated as `radius * 0.85` for proper meshing detection
- **Gear Ratio**: `angularVelocity2 = -angularVelocity1 * (teeth1 / teeth2)`
- **Mesh Detection**: Gears are considered meshed when distance ≈ pitchRadius1 + pitchRadius2

### Compound Gears
Gears can be compounded (mounted on the same axle) to create complex gear trains. Compounded gears:
- Rotate at the same angular velocity
- Can have different sizes and teeth counts
- Transfer power between different gear stages

## Project Structure 📁

```
gears_app/
├── lib/
│   └── main.dart          # Main application code
├── web/
│   └── index.html         # Web entry point
├── pubspec.yaml           # Dependencies
└── README.md              # This file
```

## Running the App 🚀

### Prerequisites
- Flutter SDK (https://flutter.dev)
- A code editor (VS Code, Android Studio, etc.)

### Run on Web
```bash
cd gears_app
flutter run -d chrome
```

### Build for Web
```bash
flutter build web
```

### Run on Mobile/Desktop
```bash
flutter run -d <device>
```

## Future Enhancements 🚀

- [ ] Drag and drop gear positioning
- [ ] Save/load gear configurations
- [ ] Export simulation as GIF/video
- [ ] More connection types (worm gears, rack and pinion)
- [ ] Torque and force visualization
- [ ] Gear material properties
- [ ] Sound effects
- [ ] Preset gear systems

## Technologies Used 🛠️

- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **CustomPainter**: For rendering gears and animations
- **AnimationController**: For smooth simulation updates

## License 📄

This project is open source and available for educational purposes.

---

**Enjoy building amazing gear systems!** ⚙️🔧
