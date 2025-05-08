# FPSIndicator

A real-time FPS (Frames Per Second) indicator for iOS games and applications.

## Features

- Real-time FPS monitoring
- Supports both Metal and UIKit-based applications
- Customizable display options:
  - Average FPS mode
  - Per-second FPS mode
  - Adjustable opacity
  - Draggable indicator position
  - Light/Dark/System theme support
- iOS 13+ optimized with proper window scene support
- Low power mode aware
- Screen recording compatible
- Settings integration in iOS Settings app

## Supported Games & Apps

- PUBG Mobile (Global, Korean, and Chinese versions)
- Any Metal-based games and applications
- UIKit-based applications

## Requirements

- iOS 11.0 or later
- Jailbroken device

## Installation

1. Add the repository: `https://brendonjkding.github.io`
2. Install FPSIndicator via your package manager (Cydia/Sileo)
3. Respring your device
4. Configure settings in iOS Settings app under "FPSIndicator"

## Usage

- The FPS counter will appear automatically in supported applications
- Drag the indicator to reposition it
- Use Settings to:
  - Toggle the indicator on/off
  - Switch between average and per-second FPS display
  - Adjust appearance settings
  - Reset position

## Known Issues

- The indicator may not appear in some full-screen games
- Position may reset after device rotation in certain apps

## Building from Source

```bash
make package
```

## Contributing

Feel free to submit issues and enhancement requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Special Thanks

- [masagrator/NX-FPS](https://github.com/masagrator/NX-FPS) - FPS calculation implementation
- [JoeyDeVries/LearnOpenGL](https://github.com/JoeyDeVries/LearnOpenGL) - OpenGL insights
- [loyinglin/LearnMetal](https://github.com/loyinglin/LearnMetal) - Metal implementation references

## Author

[brendonjkding](https://github.com/brendonjkding)

## Support

- [GitHub Issues](https://github.com/brendonjkding/FPSIndicator/issues)
- [Twitter](https://twitter.com/brendonjkding)
