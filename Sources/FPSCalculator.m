#import "FPSCalculator.h"
#import <UIKit/UIKit.h>

@implementation FPSCalculator {
    dispatch_queue_t _fpsQueue;
    double _averageFPS;
    double _perSecondFPS;
    
    // Internal calculation variables
    double _frameTimestampStart;
    double _frameTimestampEnd;
    double _frameDelta;
    double _frameAverage;
    double _frameCounter;
}

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static FPSCalculator *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FPSCalculator alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _fpsQueue = dispatch_queue_create("com.fpsindicator.fpsCalculationQueue", DISPATCH_QUEUE_SERIAL);
        _mode = FPSModeAverage;
        _averageFPS = 0.0;
        _perSecondFPS = 0.0;
        [self reset];
        
        // Register for power mode notifications
        if (@available(iOS 9.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(powerModeDidChange:)
                                                         name:NSProcessInfoPowerStateDidChangeNotification
                                                       object:nil];
            [self updatePowerMode];
        }
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

- (void)frameTick {
    // Ensure all frame rate calculations happen on a dedicated queue
    dispatch_async(_fpsQueue, ^{
        // First frame initialization
        if (_frameTimestampStart == 0) {
            _frameTimestampStart = CACurrentMediaTime() * 1000.0;
        }
        
        // Calculate time since last frame
        _frameTimestampEnd = CACurrentMediaTime() * 1000.0;
        double currentFrameDelta = _frameTimestampEnd - _frameDelta;
        
        // Update running average (with 90% previous value weight)
        _frameAverage = ((9 * _frameAverage) + currentFrameDelta) / 10;
        _averageFPS = 1000.0 / _frameAverage;
        _frameDelta = _frameTimestampEnd;
        
        // Per-second FPS calculation
        _frameCounter++;
        double deltaTime = _frameTimestampEnd - _frameTimestampStart;
        
        // If a second has passed, update the per-second FPS value
        if (deltaTime >= 1000.0) {
            _frameTimestampStart = CACurrentMediaTime() * 1000.0;
            _perSecondFPS = _frameCounter;
            _frameCounter = 0;
        }
    });
}

- (double)currentFPS {
    switch (_mode) {
        case FPSModeAverage:
            return _averageFPS;
        case FPSModePerSecond:
            return _perSecondFPS;
        default:
            return _averageFPS;
    }
}

- (void)reset {
    dispatch_async(_fpsQueue, ^{
        self->_frameTimestampStart = 0;
        self->_frameTimestampEnd = 0;
        self->_frameDelta = 0;
        self->_frameAverage = 0;
        self->_frameCounter = 0;
        self->_averageFPS = 0;
        self->_perSecondFPS = 0;
    });
}

- (void)updatePowerMode {
    if (@available(iOS 9.0, *)) {
        self.isLowPowerMode = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    }
}

- (NSTimeInterval)fpsUpdateInterval {
    // Adjust refresh rate based on low power mode
    return self.isLowPowerMode ? 0.5 : 0.2; // 2Hz or 5Hz refresh rate
}

- (void)logFPSDataToFile:(NSString *)filePath {
    // Get the current timestamp for logging
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // Prepare log entry
    NSString *logEntry = [NSString stringWithFormat:@"[%@] Avg FPS: %.1f, Per-Second FPS: %.1f\n", 
                         timestamp, _averageFPS, _perSecondFPS];
    
    // Create the file if it doesn't exist
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [@"FPS Log File\n=========\n" writeToFile:filePath 
                                       atomically:YES 
                                         encoding:NSUTF8StringEncoding 
                                            error:nil];
    }
    
    // Append to the file
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[logEntry dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

#pragma mark - Notifications

- (void)powerModeDidChange:(NSNotification *)notification {
    [self updatePowerMode];
}

@end
