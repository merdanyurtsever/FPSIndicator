# FPSIndicator (Revamped)

A lightweight, non-intrusive FPS counter for iOS that works system-wide with a simplified, efficient architecture. Now with special support for PUBG Mobile that avoids anti-cheat detection.

## Features

- **Accurate FPS monitoring** - See your frame rate in real-time across all apps and games
- **Direct display sync** - Uses CADisplayLink for precise frame timing
- **PUBG Mobile support** - Special stealth mode for PUBG Mobile that avoids anti-cheat detection
- **Anti-cheat evasion** - Multiple stealth levels to minimize detection risk
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

### PUBG Mobile Usage

For PUBG Mobile, the tweak automatically uses a special stealth mode that:

1. Uses a CALayer-based overlay instead of UIWindow
2. Initializes after a delay to avoid anti-cheat detection
3. Updates at a lower frequency to minimize visibility to anti-cheat
4. Optionally uses the QuartzCore debug API with appropriate entitlements

You can configure the stealth level in settings:
- **Normal**: Standard hooks (not recommended)
- **Medium**: Delayed initialization with minimal hooks
- **Maximum**: Extreme caution mode with minimal footprint

Note: Changing PUBG Mobile settings requires restarting the PUBG Mobile app to take effect.

## Technical Details

FPSIndicator uses a streamlined architecture:

- **FPSCounter** - Uses CADisplayLink for accurate frame counting with statistical smoothing
- **FPSDisplay** - Provides a lightweight, draggable overlay with color coding
- **FPSPreferences** - Centralizes preference management with a single source of truth
- **FPSPUBGSupport** - Specialized handling for PUBG Mobile with anti-cheat evasion
- **FPSAlternativeOverlay** - CALayer-based overlay for stealthy display in games

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

### PUBG Mobile issues

If you experience issues with PUBG Mobile:

1. Try increasing the stealth level in settings
2. Lower the refresh rate to minimize detection
3. In extreme cases, enable the "Use QuartzCore Debug API" option (requires appropriate entitlements)

## Changelog

### v2.1.0
- Added specialized PUBG Mobile support with anti-cheat evasion
- Implemented multiple stealth levels for game compatibility
- Added CALayer-based alternative overlay for games
- Optional QuartzCore debug API support for accurate system FPS
- Added PUBG-specific settings in preferences

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
