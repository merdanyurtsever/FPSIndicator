// FPSCounter.m
#import "FPSCounter.h"
#import <UIKit/UIKit.h>

@implementation FPSCounter {
    CADisplayLink *_displayLink;
    NSMutableArray<NSNumber *> *_frameTimestamps;
    CFTimeInterval _lastTimestamp;
    NSUInteger _framesThisSecond;
    CFTimeInterval _lastSecondTimestamp;
    double _lastSecondFPS;
}

+ (instancetype)sharedInstance {
    static FPSCounter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FPSCounter alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _frameTimestamps = [NSMutableArray array];
        _sampleWindow = 60; // Default to 60 frame window
        _lastTimestamp = 0;
        _framesThisSecond = 0;
        _lastSecondTimestamp = 0;
        _lastSecondFPS = 0;
    }
    return self;
}

- (void)start {
    [self stop];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stop {
    [_displayLink invalidate];
    _displayLink = nil;
}

- (BOOL)isRunning {
    return _displayLink != nil;
}

- (void)reset {
    [_frameTimestamps removeAllObjects];
    _lastTimestamp = 0;
    _framesThisSecond = 0;
    _lastSecondTimestamp = 0;
    _lastSecondFPS = 0;
}

- (void)displayLinkTick:(CADisplayLink *)link {
    // First frame initialization
    if (_lastTimestamp == 0) {
        _lastTimestamp = link.timestamp;
        _lastSecondTimestamp = link.timestamp;
        return;
    }
    
    // Calculate delta time
    CFTimeInterval delta = link.timestamp - _lastTimestamp;
    _lastTimestamp = link.timestamp;
    
    // Add to rolling window
    [_frameTimestamps addObject:@(delta)];
    while (_frameTimestamps.count > _sampleWindow) {
        [_frameTimestamps removeObjectAtIndex:0];
    }
    
    // Per-second calculation
    _framesThisSecond++;
    if (link.timestamp - _lastSecondTimestamp >= 1.0) {
        _lastSecondFPS = _framesThisSecond / (link.timestamp - _lastSecondTimestamp);
        _framesThisSecond = 0;
        _lastSecondTimestamp = link.timestamp;
    }
}

- (double)currentFPS {
    if (_frameTimestamps.count < 1) return 0;
    
    // Either use the last second FPS or calculate from most recent frame
    if (_lastSecondFPS > 0) {
        return _lastSecondFPS;
    }
    
    return 1.0 / [_frameTimestamps.lastObject doubleValue];
}

- (double)averageFPS {
    if (_frameTimestamps.count < 1) return 0;
    
    double sum = 0;
    for (NSNumber *delta in _frameTimestamps) {
        sum += [delta doubleValue];
    }
    return _frameTimestamps.count / sum;
}

- (void)dealloc {
    [self stop];
}

@end