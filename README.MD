# FPSIndicator

A lightweight, non-intrusive FPS counter for iOS that works system-wide and with special optimizations for games.

## Features

- **Real-time FPS monitoring** - See your frame rate in real-time across all apps and games
- **Multiple calculation methods** - Choose between average FPS (smoother) or per-second FPS (more responsive)
- **Game engine optimization** - Special support for Unity, Unreal, and PUBG Mobile games
- **Position presets** - Easily position the indicator in any corner or drag to a custom position
- **Appearance customization** - Color, opacity, size, and theme options
- **Privacy mode** - Automatically hide the indicator in banking and other sensitive apps
- **iOS compatibility** - Supports iOS 12-17 with proper UIScene support for iPad Stage Manager
- **Performance data export** - Log and export FPS data for analysis
- **Low power mode** - Automatically adjusts refresh rate to conserve battery

## Installation

1. Add the repository to your package manager: `https://repo.example.com`
2. Search for "FPSIndicator" and install it
3. Respring your device

## Usage

After installation, a small FPS counter will appear in the top-right corner of your screen.

- **Drag** the counter to reposition it
- **Configure** the indicator in Settings app → FPSIndicator

## Technical Details

FPSIndicator uses a modular architecture:

- **FPSCalculator** - Handles the frame rate calculation with thread safety and power optimization
- **FPSDisplayWindow** - Manages the UI display with customization and positioning
- **FPSGameSupport** - Provides specialized support for different game engines

## Privacy Mode

In privacy mode, the FPS indicator is automatically hidden in selected apps:

- Banking apps (default)
- Any apps added to your privacy list in settings

## License

MIT License - See LICENSE file for details.

## Credits

- Original concept inspired by NX-FPS
- Special thanks to the jailbreak community for testing

## Troubleshooting

### FPS not showing in games?

Some games use custom rendering methods. Try these solutions:

1. Open FPSIndicator settings and increase opacity
2. Make sure the game is not in your privacy list
3. Some games may require a higher window level setting

### Battery drain concerns?

The tweak automatically reduces refresh rate in low power mode. You can also:

1. Use a smaller font size
2. Disable logging when not needed
3. Disable the tweak in games where you don't need it

## Changelog

### v1.0.0
- Complete rewrite with modular architecture
- Enhanced game engine support
- Added privacy mode
- Added position presets
- Added FPS data export
- Improved thread safety and performance

### v0.0.5
- Initial public release
