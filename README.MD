# FPSIndicator (Revamped)

A lightweight, non-intrusive FPS counter for iOS that works system-wide with a simplified, efficient architecture.

## Features

- **Accurate FPS monitoring** - See your frame rate in real-time across all apps and games
- **Direct display sync** - Uses CADisplayLink for precise frame timing
- **Drag-to-position** - Easily position the indicator anywhere on screen with a simple drag gesture
- **Appearance customization** - Color coding, opacity, and size options
- **Privacy mode** - Automatically hide the indicator in sensitive apps
- **iOS compatibility** - Supports iOS 12-17 with proper UIScene support for iPad Stage Manager
- **Battery optimized** - Low power impact with adaptive refresh rate
- **Screen recording awareness** - Automatically hides during screen recording

## Installation

1. Add the repository to your package manager: `https://repo.example.com`
2. Search for "FPSIndicator" and install it
3. Respring your device

## Usage

After installation, a small FPS counter will appear in the top corner of your screen.

- **Drag** the counter to reposition it anywhere on screen
- **Configure** the indicator in Settings app → FPSIndicator

## Technical Details

FPSIndicator uses a streamlined architecture:

- **FPSCounter** - Uses CADisplayLink for accurate frame counting with statistical smoothing
- **FPSDisplay** - Provides a lightweight, draggable overlay with color coding
- **FPSPreferences** - Centralizes preference management with a single source of truth

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

### Battery optimization

The tweak is designed to have minimal impact on battery life:

1. Uses CADisplayLink instead of rendering hooks
2. Updates the display at 10Hz instead of every frame
3. Simple UI with minimal overhead

### Display issues

If the FPS indicator is not appearing:

1. Check that the app is not in your privacy or disabled list
2. Try toggling the tweak off and on in Settings
3. Respring your device

## Changelog

### v2.0.0
- Complete architectural revamp for reliability and performance
- Switched to CADisplayLink for accurate frame timing
- Simplified UI with drag positioning
- Improved battery efficiency
- Better compatibility with iOS windowing system
- Eliminated game-specific hacks for a universal solution

### v1.0.0
- Original modular architecture release

### v0.0.5
- Initial public release
