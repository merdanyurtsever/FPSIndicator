#import <UIKit/UIKit.h>

@class FPSGraphView;

/**
 * FPSDisplayWindow - Manages the floating FPS indicator window
 * 
 * This class handles the visual representation of FPS data including
 * window management, positioning, styling, and interaction.
 */
@interface FPSDisplayWindow : UIWindow

/**
 * @property fpsLabel The label that displays the current FPS
 */
@property (nonatomic, strong) UILabel *fpsLabel;

/**
 * @property labelColor The color of the FPS text
 */
@property (nonatomic, strong) UIColor *labelColor;

/**
 * @property backgroundColor The background color of the FPS display
 */
@property (nonatomic, strong) UIColor *backgroundColor;

/**
 * @property backgroundAlpha The opacity of the FPS display background (0.0-1.0)
 */
@property (nonatomic, assign) CGFloat backgroundAlpha;

/**
 * @property fontSize The size of the FPS text
 */
@property (nonatomic, assign) CGFloat fontSize;

/**
 * @property positionPreset Preset positions for the FPS display
 */
typedef NS_ENUM(NSInteger, PositionPreset) {
    PositionPresetTopRight = 0,
    PositionPresetTopLeft,
    PositionPresetBottomRight,
    PositionPresetBottomLeft,
    PositionPresetCustom
};
@property (nonatomic, assign) PositionPreset positionPreset;

/**
 * @property colorCodingEnabled Whether to enable color coding based on FPS thresholds
 */
@property (nonatomic, assign) BOOL colorCodingEnabled;

/**
 * @property goodFPSThreshold FPS above this value is considered "good" (green color)
 */
@property (nonatomic, assign) double goodFPSThreshold;

/**
 * @property mediumFPSThreshold FPS above this value is considered "medium" (yellow color)
 */
@property (nonatomic, assign) double mediumFPSThreshold;

/**
 * @property goodFPSColor Color used when FPS is above goodFPSThreshold
 */
@property (nonatomic, strong) UIColor *goodFPSColor;

/**
 * @property mediumFPSColor Color used when FPS is between mediumFPSThreshold and goodFPSThreshold
 */
@property (nonatomic, strong) UIColor *mediumFPSColor;

/**
 * @property poorFPSColor Color used when FPS is below mediumFPSThreshold
 */
@property (nonatomic, strong) UIColor *poorFPSColor;

/**
 * @property displayMode The display mode for the FPS indicator
 */
typedef NS_ENUM(NSInteger, FPSDisplayMode) {
    FPSDisplayModeNormal = 0,  // Shows FPS with text (e.g., "60.0 FPS")
    FPSDisplayModeCompact,     // Shows only the number (e.g., "60.0")
    FPSDisplayModeDot,         // Shows just a color-coded dot
    FPSDisplayModeGraph        // Shows frame time graph
};
@property (nonatomic, assign) FPSDisplayMode displayMode;

/**
 * @property graphView The graph view showing frame time history
 */
@property (nonatomic, strong) FPSGraphView *graphView;

/**
 * @property graphEnabled Whether the frame time graph is enabled
 */
@property (nonatomic, assign) BOOL graphEnabled;

/**
 * @property thermalMonitoringEnabled Whether to display thermal information
 */
@property (nonatomic, assign) BOOL thermalMonitoringEnabled;

/**
 * @property temperatureLabel The label that displays temperature information
 */
@property (nonatomic, strong) UILabel *temperatureLabel;

/**
 * Shared instance accessor
 * @return The shared FPSDisplayWindow instance
 */
+ (instancetype)sharedInstance;

/**
 * Updates the FPS display with the given value
 * @param fps The FPS value to display
 */
- (void)updateWithFPS:(double)fps;

/**
 * Applies a preset position to the FPS display
 * @param preset The position preset to apply
 */
- (void)applyPositionPreset:(PositionPreset)preset;

/**
 * Saves the current position of the FPS display to preferences
 */
- (void)saveCurrentPosition;

/**
 * Updates the FPS window to match the current scene and orientation
 */
- (void)updateFrameForCurrentOrientation;

/**
 * Updates the visual appearance based on preferences
 * @param preferences Dictionary containing visual preferences
 */
- (void)updateAppearanceWithPreferences:(NSDictionary *)preferences;

/**
 * Sets whether the window is visible
 * @param visible Whether the window should be visible
 */
- (void)setVisible:(BOOL)visible;

/**
 * Activates privacy mode for the specified app bundle ID
 * @param bundleID The bundle ID of the app to check
 * @return Whether privacy mode has been activated
 */
- (BOOL)activatePrivacyModeForApp:(NSString *)bundleID;

@end