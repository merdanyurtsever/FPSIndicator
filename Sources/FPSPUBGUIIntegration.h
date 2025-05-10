#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * FPSPUBGUIIntegration - Integration with PUBG Mobile UI elements
 * 
 * This class provides methods to integrate FPS display with existing PUBG Mobile UI elements
 * to avoid anti-cheat detection while still providing visible FPS information.
 */
@interface FPSPUBGUIIntegration : NSObject

/**
 * @property displayMode How to display the FPS in PUBG UI
 * 0 = Disabled
 * 1 = Left Fire Button Mode (replaces text on the left fire button)
 * 2 = Log File Mode (writes FPS to a log file)
 */
@property (nonatomic, assign) NSInteger displayMode;

/**
 * @property logFilePath Path to the log file for mode 2
 */
@property (nonatomic, copy) NSString *logFilePath;

/**
 * @property logInterval Interval in seconds between log entries (default 5s)
 */
@property (nonatomic, assign) CGFloat logInterval;

/**
 * @property customFormat Custom format for the FPS display (default: "FPS: %.1f")
 */
@property (nonatomic, copy) NSString *customFormat;

/**
 * Initializes the PUBG UI integration with the specified mode
 * @param mode The display mode to use
 */
- (void)initializeWithMode:(NSInteger)mode;

/**
 * Starts monitoring and updating the selected display mode
 * @param initialFPS The initial FPS to display
 */
- (void)startDisplayingWithInitialFPS:(double)initialFPS;

/**
 * Updates the FPS display with the current value
 * @param fps The current frames per second
 */
- (void)updateWithFPS:(double)fps;

/**
 * Stops monitoring and clean up any resources
 */
- (void)stopDisplaying;

/**
 * Returns the path to the latest log file if in log mode
 * @return The full path to the latest log file or nil if not in log mode
 */
- (NSString *)currentLogFilePath;

/**
 * Force writes the current FPS to the log file
 * @param fps The current FPS to log
 */
- (void)forceLogWithFPS:(double)fps;

/**
 * Singleton accessor
 * @return The shared instance
 */
+ (instancetype)sharedInstance;

@end
