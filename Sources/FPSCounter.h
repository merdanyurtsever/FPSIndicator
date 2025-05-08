// FPSCounter.h
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

/**
 * FPSCounter - Efficient frame counter using CADisplayLink
 * 
 * This class provides accurate frame rate counting by synchronizing
 * directly with the display refresh rate.
 */
@interface FPSCounter : NSObject

// Public properties
@property (nonatomic, readonly) double currentFPS;
@property (nonatomic, readonly) double averageFPS;
@property (nonatomic, assign) NSInteger sampleWindow; // Number of frames to average
@property (nonatomic, readonly) BOOL isRunning;

// Core methods
- (void)start;
- (void)stop;
- (void)reset;

// Singleton accessor
+ (instancetype)sharedInstance;

@end