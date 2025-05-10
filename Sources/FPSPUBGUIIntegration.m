#import "FPSPUBGUIIntegration.h"
#import "FPSPUBGSupport.h"
#import <objc/runtime.h>

@implementation FPSPUBGUIIntegration {
    NSTimer *_updateTimer;
    NSTimer *_logTimer;
    NSDateFormatter *_dateFormatter;
    NSFileHandle *_logFileHandle;
    
    BOOL _isDisplaying;
    double _currentFPS;
    NSDate *_lastLogTime;
    
    // Reference to PUBG UI elements
    UIButton *_leftFireButton;
    NSString *_originalButtonText;
}

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static FPSPUBGUIIntegration *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _displayMode = 0; // Disabled by default
        _logInterval = 5.0; // 5 seconds between log entries
        _customFormat = @"FPS: %.1f"; // Default format
        _isDisplaying = NO;
        _currentFPS = 0;
        
        // Create date formatter for logs
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
        // Setup default log path outside of app's container to avoid anti-cheat detection
        NSString *logDir = [self logDirectoryPath];
        _logFilePath = [logDir stringByAppendingPathComponent:@"fps_log.txt"];
    }
    return self;
}

- (void)dealloc {
    [self stopDisplaying];
}

#pragma mark - Public Methods

- (void)initializeWithMode:(NSInteger)mode {
    self.displayMode = mode;
    
    // If we're in log file mode, prepare the log file
    if (mode == 2) {
        [self prepareLogFile];
    }
    
    // If we're in left fire button mode, find and prepare the button
    if (mode == 1) {
        // We'll use dispatch_after to delay finding the button until it's likely been created
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), 
                      dispatch_get_main_queue(), ^{
            [self findAndPrepareLeftFireButton];
        });
    }
}

- (void)startDisplayingWithInitialFPS:(double)initialFPS {
    if (_isDisplaying) return;
    
    _currentFPS = initialFPS;
    _isDisplaying = YES;
    
    // Based on mode, start the appropriate display method
    switch (self.displayMode) {
        case 1: // Left Fire Button Mode
            // Create a timer to update the button text
            _updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 
                                                            target:self 
                                                          selector:@selector(updateFireButtonFPS) 
                                                          userInfo:nil 
                                                           repeats:YES];
            break;
            
        case 2: // Log File Mode
            // Create a timer to periodically log the FPS
            _logTimer = [NSTimer scheduledTimerWithTimeInterval:self.logInterval 
                                                         target:self 
                                                       selector:@selector(logCurrentFPS) 
                                                       userInfo:nil 
                                                        repeats:YES];
            // Log initial value
            [self forceLogWithFPS:initialFPS];
            break;
            
        default:
            break;
    }
}

- (void)updateWithFPS:(double)fps {
    _currentFPS = fps;
    
    // If in fire button mode and we already have a reference to the button,
    // update it immediately rather than waiting for the timer
    if (self.displayMode == 1 && _leftFireButton) {
        [self updateFireButtonFPS];
    }
}

- (void)stopDisplaying {
    _isDisplaying = NO;
    
    // Clean up timers
    [_updateTimer invalidate];
    _updateTimer = nil;
    
    [_logTimer invalidate];
    _logTimer = nil;
    
    // Restore original button text if we modified it
    if (_leftFireButton && _originalButtonText) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_leftFireButton setTitle:self->_originalButtonText forState:UIControlStateNormal];
        });
    }
    
    // Close log file if open
    if (_logFileHandle) {
        [_logFileHandle closeFile];
        _logFileHandle = nil;
    }
}

- (NSString *)currentLogFilePath {
    return _logFilePath;
}

- (void)forceLogWithFPS:(double)fps {
    if (self.displayMode != 2) return;
    
    _currentFPS = fps;
    [self logCurrentFPS];
}

#pragma mark - Private Methods - Fire Button Integration

- (void)findAndPrepareLeftFireButton {
    @try {
        // First try to find buttons using recursive search
        UIWindow *keyWindow = nil;
        
        // Get the key window 
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *window in scene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (keyWindow) break;
                }
            }
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            keyWindow = [UIApplication sharedApplication].keyWindow;
            #pragma clang diagnostic pop
        }
        
        if (!keyWindow) {
            NSLog(@"FPSIndicator: Could not find key window for fire button integration");
            return;
        }
        
        // Now search for the left fire button in the view hierarchy
        // PUBG Mobile typically has fire buttons on the left and right sides
        // We're looking for a button on the left side of the screen
        NSArray<UIButton *> *candidateButtons = [self findFireButtonsInView:keyWindow];
        
        if (candidateButtons.count > 0) {
            // Try to find the left fire button based on position
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            UIButton *leftmostButton = nil;
            CGFloat leftmostX = screenWidth;
            
            for (UIButton *button in candidateButtons) {
                CGPoint buttonCenter = button.center;
                // Convert to window coordinates if needed
                if (button.window != keyWindow) {
                    buttonCenter = [button.window convertPoint:buttonCenter toWindow:keyWindow];
                }
                
                // We're looking for buttons in the left half of the screen
                if (buttonCenter.x < screenWidth / 2 && buttonCenter.x < leftmostX) {
                    leftmostX = buttonCenter.x;
                    leftmostButton = button;
                }
            }
            
            if (leftmostButton) {
                _leftFireButton = leftmostButton;
                // Store the original text to restore later
                _originalButtonText = [leftmostButton titleForState:UIControlStateNormal];
                NSLog(@"FPSIndicator: Found left fire button, original text: %@", _originalButtonText);
                
                // Update with current FPS
                [self updateFireButtonFPS];
            } else {
                NSLog(@"FPSIndicator: No suitable left fire button found");
            }
        } else {
            NSLog(@"FPSIndicator: No candidate fire buttons found");
        }
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception finding fire button: %@", exception);
    }
}

- (NSArray<UIButton *> *)findFireButtonsInView:(UIView *)view {
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    
    // Recursively search for buttons
    [self findButtonsInView:view output:buttons];
    
    // Filter for likely fire buttons (typically large, round buttons)
    NSMutableArray<UIButton *> *fireButtons = [NSMutableArray array];
    for (UIButton *button in buttons) {
        // Look for buttons that are likely to be fire buttons
        // Criteria: Relatively large, visible, and enabled
        if (button.bounds.size.width >= 44 &&   // Reasonable minimum touch target size
            button.bounds.size.height >= 44 &&   
            !button.hidden &&
            button.enabled) {
            
            // Further filter with class name or other properties specific to PUBG
            // Many games use custom button classes with names that might contain "fire", "shoot", etc.
            NSString *className = NSStringFromClass([button class]);
            if ([className containsString:@"Fire"] || 
                [className containsString:@"Shoot"] ||
                [className containsString:@"Combat"] ||
                [className containsString:@"Action"]) {
                [fireButtons addObject:button];
                continue;
            }
            
            // Check if the button has an image that might indicate it's a fire button
            if (button.imageView.image != nil) {
                [fireButtons addObject:button];
                continue;
            }
            
            // Check if the button's title might indicate it's a fire button
            NSString *title = [button titleForState:UIControlStateNormal];
            if (title && ([title containsString:@"Fire"] || 
                           [title containsString:@"Shoot"] ||
                           [title length] == 0)) { // Empty title is common for icon-only buttons
                [fireButtons addObject:button];
                continue;
            }
            
            // Last resort: check button position (fire buttons typically in lower half of screen)
            CGRect buttonFrame = button.frame;
            if (buttonFrame.origin.y > [UIScreen mainScreen].bounds.size.height / 2) {
                [fireButtons addObject:button];
            }
        }
    }
    
    return fireButtons;
}

- (void)findButtonsInView:(UIView *)view output:(NSMutableArray<UIButton *> *)buttons {
    if (!view) return;
    
    // If this view is a button, add it
    if ([view isKindOfClass:[UIButton class]]) {
        [buttons addObject:(UIButton *)view];
    }
    
    // Recurse on subviews
    for (UIView *subview in view.subviews) {
        [self findButtonsInView:subview output:buttons];
    }
}

- (void)updateFireButtonFPS {
    if (!_leftFireButton || !_isDisplaying) return;
    
    NSString *fpsText = [NSString stringWithFormat:self.customFormat, _currentFPS];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self->_leftFireButton setTitle:fpsText forState:UIControlStateNormal];
        } @catch (NSException *exception) {
            NSLog(@"FPSIndicator: Exception updating fire button: %@", exception);
        }
    });
}

#pragma mark - Private Methods - Log File Integration

- (void)prepareLogFile {
    @try {
        // Create a new log file for this session
        NSDateFormatter *fileFormatter = [[NSDateFormatter alloc] init];
        [fileFormatter setDateFormat:@"yyyyMMdd_HHmmss"];
        NSString *timeStamp = [fileFormatter stringFromDate:[NSDate date]];
        
        // Get the log directory path (safely outside of app's container)
        NSString *logDir = [self logDirectoryPath];
        _logFilePath = [logDir stringByAppendingPathComponent:[NSString stringWithFormat:@"fps_log_%@.txt", timeStamp]];
        
        // Create the file with a header
        NSString *header = [NSString stringWithFormat:@"FPS Log - Session started at %@\n"
                            @"--------------------------------------------\n"
                            @"Timestamp               | FPS\n"
                            @"--------------------------------------------\n",
                            [_dateFormatter stringFromDate:[NSDate date]]];
        
        [header writeToFile:_logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        // Open the file for appending
        _logFileHandle = [NSFileHandle fileHandleForWritingAtPath:_logFilePath];
        [_logFileHandle seekToEndOfFile];
        
        NSLog(@"FPSIndicator: Created FPS log file at %@", _logFilePath);
        
        // Write session info
        NSString *deviceInfo = [NSString stringWithFormat:@"Device: %@, iOS %@\n",
                               [[UIDevice currentDevice] model],
                               [[UIDevice currentDevice] systemVersion]];
        NSData *deviceData = [deviceInfo dataUsingEncoding:NSUTF8StringEncoding];
        [_logFileHandle writeData:deviceData];
        
        // Record the start time
        _lastLogTime = [NSDate date];
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception preparing log file: %@", exception);
    }
}

- (void)logCurrentFPS {
    if (!_isDisplaying || !_logFileHandle) return;
    
    @try {
        // Get current timestamp
        NSDate *now = [NSDate date];
        NSString *timestamp = [_dateFormatter stringFromDate:now];
        
        // Format the log entry
        NSString *logEntry = [NSString stringWithFormat:@"%@ | %.1f\n", timestamp, _currentFPS];
        NSData *logData = [logEntry dataUsingEncoding:NSUTF8StringEncoding];
        
        // Write to file
        [_logFileHandle writeData:logData];
        
        // Update last log time
        _lastLogTime = now;
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception logging FPS: %@", exception);
    }
}

#pragma mark - Log File Management

- (NSString *)logDirectoryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    NSString *logDir = [paths firstObject];
    
    // If Downloads directory isn't available, fall back to a shared container
    if (!logDir) {
        paths = NSSearchPathForDirectoriesInDomains(NSSharedPublicDirectory, NSUserDomainMask, YES);
        logDir = [paths firstObject];
    }
    
    // If neither is available, use a special directory in /var/mobile/Documents
    if (!logDir) {
        NSString *baseDir = @"/var/mobile/Documents";
        if ([[NSFileManager defaultManager] fileExistsAtPath:baseDir]) {
            logDir = [baseDir stringByAppendingPathComponent:@"FPSIndicator/Logs"];
        } else {
            // Last resort, try to use a directory that's not directly in the app container
            paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            logDir = [[paths firstObject] stringByAppendingPathComponent:@"../FPSIndicator/Logs"];
        }
    }
    
    // Add FPSIndicator subfolder
    NSString *fpsDirPath = [logDir stringByAppendingPathComponent:@"FPSIndicator"];
    
    // Create directory if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:fpsDirPath]) {
        [fileManager createDirectoryAtPath:fpsDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return fpsDirPath;
}

- (NSArray<NSString *> *)allLogFilePaths {
    NSString *logDir = [self logDirectoryPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:logDir]) {
        return @[];
    }
    
    NSError *error = nil;
    NSArray *fileNames = [fileManager contentsOfDirectoryAtPath:logDir error:&error];
    
    if (error) {
        NSLog(@"FPSIndicator: Error reading log directory: %@", error);
        return @[];
    }
    
    NSMutableArray *logFiles = [NSMutableArray array];
    
    for (NSString *fileName in fileNames) {
        if ([fileName hasPrefix:@"fps_log_"] && [fileName hasSuffix:@".txt"]) {
            [logFiles addObject:[logDir stringByAppendingPathComponent:fileName]];
        }
    }
    
    // Sort by modification date (newest first)
    [logFiles sortUsingComparator:^NSComparisonResult(NSString *path1, NSString *path2) {
        NSDictionary *attrs1 = [fileManager attributesOfItemAtPath:path1 error:nil];
        NSDictionary *attrs2 = [fileManager attributesOfItemAtPath:path2 error:nil];
        
        NSDate *date1 = attrs1[NSFileModificationDate];
        NSDate *date2 = attrs2[NSFileModificationDate];
        
        return [date2 compare:date1];
    }];
    
    return [logFiles copy];
}

- (NSString *)contentsOfLogFile:(NSString *)logFilePath {
    if (!logFilePath) return nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:logFilePath]) {
        return nil;
    }
    
    NSError *error = nil;
    NSString *contents = [NSString stringWithContentsOfFile:logFilePath 
                                                   encoding:NSUTF8StringEncoding 
                                                      error:&error];
    
    if (error) {
        NSLog(@"FPSIndicator: Error reading log file %@: %@", logFilePath, error);
        return nil;
    }
    
    return contents;
}

- (NSString *)contentsOfMostRecentLogFile {
    NSArray *logFiles = [self allLogFilePaths];
    if (logFiles.count == 0) {
        return nil;
    }
    
    // The first file is the most recent since we sorted them
    return [self contentsOfLogFile:logFiles[0]];
}

@end
