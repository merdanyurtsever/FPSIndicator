#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

/**
 * FPSCalculator - Handles calculation of frames per second
 * 
 * This class encapsulates the frame rate calculation logic, providing
 * multiple calculation methods and power-aware adjustments.
 */
@interface FPSCalculator : NSObject

/**
 * Calculation modes for FPS values
 */
typedef NS_ENUM(NSInteger, FPSMode) {
    FPSModeAverage = 1,    // Running average FPS (smoother)
    FPSModePerSecond = 2   // FPS calculated per second (more responsive)
};

/**
 * @property mode The current FPS calculation mode
 */
@property (nonatomic, assign) FPSMode mode;

/**
 * @property isLowPowerMode Whether the device is in low power mode
 */
@property (nonatomic, assign) BOOL isLowPowerMode;

/**
 * @property averageFPS Current average FPS value
 */
@property (nonatomic, readonly) double averageFPS;

/**
 * @property perSecondFPS Current per-second FPS value
 */
@property (nonatomic, readonly) double perSecondFPS;

/**
 * @property fpsUpdateInterval Time interval between FPS display updates
 */
@property (nonatomic, readonly) NSTimeInterval fpsUpdateInterval;

/**
 * Shared instance accessor
 * @return The shared FPSCalculator instance
 */
+ (instancetype)sharedInstance;

/**
 * Records a frame tick for FPS calculation
 * Thread-safe method that updates both average and per-second FPS values
 */
- (void)frameTick;

/**
 * Get the current FPS value based on selected mode
 * @return The current FPS value based on the calculation mode
 */
- (double)currentFPS;

/**
 * Reset the FPS calculation
 */
- (void)reset;

/**
 * Updates internal state based on power mode
 */
- (void)updatePowerMode;

/**
 * Logs FPS information to a file
 * @param filePath The path to log the FPS data to
 */
- (void)logFPSDataToFile:(NSString *)filePath;

@end
