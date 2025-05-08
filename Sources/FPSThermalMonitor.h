#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

/**
 * FPSThermalMonitor - Monitors device thermal state and CPU/GPU temperatures
 * 
 * This class provides thermal monitoring capabilities for the FPS indicator,
 * allowing users to see temperature-related performance impacts.
 */
@interface FPSThermalMonitor : NSObject

/**
 * Thermal state constants
 */
typedef NS_ENUM(NSInteger, FPSThermalState) {
    FPSThermalStateNominal = 0,    // Normal operating temperature
    FPSThermalStateFair,           // Slightly elevated temperature
    FPSThermalStateSerious,        // High temperature, potential throttling
    FPSThermalStateCritical        // Very high temperature, significant throttling
};

/**
 * @property currentThermalState The current thermal state of the device
 */
@property (nonatomic, readonly) FPSThermalState currentThermalState;

/**
 * @property cpuTemperature Estimated CPU temperature (in Celsius)
 */
@property (nonatomic, readonly) float cpuTemperature;

/**
 * @property gpuTemperature Estimated GPU temperature (in Celsius)
 */
@property (nonatomic, readonly) float gpuTemperature;

/**
 * @property thermalStateString String representation of current thermal state
 */
@property (nonatomic, readonly) NSString *thermalStateString;

/**
 * @property temperatureString Formatted temperature string
 */
@property (nonatomic, readonly) NSString *temperatureString;

/**
 * @property monitoringEnabled Whether thermal monitoring is enabled
 */
@property (nonatomic, assign) BOOL monitoringEnabled;

/**
 * Shared instance accessor
 * @return The shared FPSThermalMonitor instance
 */
+ (instancetype)sharedInstance;

/**
 * Start monitoring thermal state
 */
- (void)startMonitoring;

/**
 * Stop monitoring thermal state
 */
- (void)stopMonitoring;

/**
 * Get the color representing the current thermal state
 * @return UIColor representing the current thermal state (green -> red)
 */
- (UIColor *)thermalStateColor;

@end