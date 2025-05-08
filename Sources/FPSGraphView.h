#import <UIKit/UIKit.h>

/**
 * FPSGraphView - Provides a visual graph of frame times
 * 
 * This class renders a graph showing frame time history,
 * allowing visualization of performance spikes and dips.
 */
@interface FPSGraphView : UIView

/**
 * @property graphColor The color of the graph line
 */
@property (nonatomic, strong) UIColor *graphColor;

/**
 * @property backgroundColor The background color of the graph
 */
@property (nonatomic, strong) UIColor *graphBackgroundColor;

/**
 * @property maxFrameTime The maximum frame time to display (ms)
 */
@property (nonatomic, assign) double maxFrameTime;

/**
 * @property historySize The number of frames to keep in history
 */
@property (nonatomic, assign) NSInteger historySize;

/**
 * @property thresholdColor Color for the threshold line
 */
@property (nonatomic, strong) UIColor *thresholdColor;

/**
 * @property showThreshold Whether to show the threshold line (16.7ms for 60fps)
 */
@property (nonatomic, assign) BOOL showThreshold;

/**
 * @property frameTimeHistory Array of recent frame times
 */
@property (nonatomic, readonly) NSArray<NSNumber *> *frameTimeHistory;

/**
 * Adds a new frame time to the graph
 * @param frameTime The frame time in milliseconds
 */
- (void)addFrameTime:(double)frameTime;

/**
 * Clears the frame time history
 */
- (void)clearHistory;

/**
 * Initializes a new graph view with the given frame
 * @param frame The frame rectangle for the view
 * @return Initialized graph view
 */
- (instancetype)initWithFrame:(CGRect)frame;

@end