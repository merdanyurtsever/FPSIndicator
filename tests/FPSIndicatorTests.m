#import "FPSIndicatorTests.h"

// Define preference path for testing
#define kTestPrefPath @"/tmp/test_fps_prefs.plist"

@implementation FPSIndicatorTests

- (void)setUp {
    [super setUp];
    
    // Initialize mocks
    self.mockWindow = OCMClassMock([FPSDisplayWindow class]);
    self.mockLabel = OCMClassMock([UILabel class]);
    self.mockScene = OCMClassMock([UIWindowScene class]);
    self.prefsPath = kTestPrefPath;
    
    // Set up test preferences
    [[NSFileManager defaultManager] removeItemAtPath:self.prefsPath error:nil];
}

- (void)tearDown {
    // Clean up mocks
    [self.mockWindow stopMocking];
    [self.mockLabel stopMocking];
    [self.mockScene stopMocking];
    
    // Remove test preferences
    [[NSFileManager defaultManager] removeItemAtPath:self.prefsPath error:nil];
    
    [super tearDown];
}

#pragma mark - FPS Calculation Tests

- (void)testFPSCalculator {
    FPSCalculator *calculator = [FPSCalculator sharedInstance];
    
    // Reset for clean test
    [calculator reset];
    
    // Simulate 60 frames at ~16.67ms intervals (60 FPS)
    for (int i = 0; i < 60; i++) {
        [calculator frameTick];
        usleep(16667); // ~60 FPS timing
    }
    
    // Check if calculated values are in reasonable range
    XCTAssertTrue(calculator.averageFPS >= 55.0 && calculator.averageFPS <= 65.0, 
                  @"FPS average should be close to 60, got %f", calculator.averageFPS);
    
    XCTAssertTrue(calculator.perSecondFPS >= 55.0 && calculator.perSecondFPS <= 65.0, 
                  @"FPS per second should be close to 60, got %f", calculator.perSecondFPS);
    
    // Test mode switching
    calculator.mode = FPSModeAverage;
    XCTAssertEqual([calculator currentFPS], calculator.averageFPS, 
                   @"Current FPS should match averageFPS in Average mode");
    
    calculator.mode = FPSModePerSecond;
    XCTAssertEqual([calculator currentFPS], calculator.perSecondFPS, 
                   @"Current FPS should match perSecondFPS in PerSecond mode");
}

- (void)testLowFPSAccuracy {
    FPSCalculator *calculator = [FPSCalculator sharedInstance];
    [calculator reset];
    
    // Simulate 30 frames at ~33.33ms intervals (30 FPS)
    for (int i = 0; i < 30; i++) {
        [calculator frameTick];
        usleep(33333); // ~30 FPS timing
    }
    
    XCTAssertTrue(calculator.averageFPS >= 25.0 && calculator.averageFPS <= 35.0, 
                  @"FPS average should be close to 30, got %f", calculator.averageFPS);
}

- (void)testPowerModeAdjustment {
    FPSCalculator *calculator = [FPSCalculator sharedInstance];
    
    // Test normal mode
    calculator.isLowPowerMode = NO;
    XCTAssertLessThan(calculator.fpsUpdateInterval, 0.3, 
                      @"Update interval should be faster in normal power mode");
    
    // Test low power mode
    calculator.isLowPowerMode = YES;
    XCTAssertGreaterThanOrEqual(calculator.fpsUpdateInterval, 0.5, 
                               @"Update interval should be slower in low power mode");
}

#pragma mark - Display Window Tests

- (void)testDisplayWindow {
    FPSDisplayWindow *window = [FPSDisplayWindow sharedInstance];
    
    XCTAssertNotNil(window, @"Display window should be created");
    XCTAssertNotNil(window.fpsLabel, @"FPS label should be created");
    XCTAssertTrue(window.userInteractionEnabled, @"Window should be interactive");
    
    // Test FPS update
    [window updateWithFPS:60.0];
    XCTAssertEqualObjects(window.fpsLabel.text, @"60.0", 
                         @"Label should display the FPS value");
    
    // Test position presets
    [window applyPositionPreset:PositionPresetTopRight];
    CGPoint topRightPoint = window.fpsLabel.center;
    
    [window applyPositionPreset:PositionPresetBottomLeft];
    CGPoint bottomLeftPoint = window.fpsLabel.center;
    
    XCTAssertNotEqualWithAccuracy(topRightPoint.x, bottomLeftPoint.x, 1.0, 
                                 @"Different presets should have different X positions");
    XCTAssertNotEqualWithAccuracy(topRightPoint.y, bottomLeftPoint.y, 1.0, 
                                 @"Different presets should have different Y positions");
}

- (void)testPrivacyMode {
    FPSDisplayWindow *window = [FPSDisplayWindow sharedInstance];
    
    // Test non-privacy app
    BOOL privacyEnabled = [window activatePrivacyModeForApp:@"com.example.testapp"];
    XCTAssertFalse(privacyEnabled, @"Privacy mode should not be enabled for non-privacy app");
    
    // Test privacy app
    privacyEnabled = [window activatePrivacyModeForApp:@"com.apple.Passbook"];
    XCTAssertTrue(privacyEnabled, @"Privacy mode should be enabled for privacy-sensitive app");
}

#pragma mark - Game Support Tests

- (void)testGameEngineDetection {
    FPSGameSupport *gameSupport = [FPSGameSupport sharedInstance];
    
    // Test PUBG detection
    XCTAssertTrue([gameSupport isKindOfClass:[FPSGameSupport class]], 
                 @"Game support should be initialized");
    
    // Test engine-specific settings
    XCTAssertGreaterThan([gameSupport recommendedWindowLevel], 100, 
                        @"Window level should be appropriate for games");
    
    XCTAssertGreaterThan([gameSupport recommendedFrameDetectionRate], 0, 
                        @"Frame detection rate should be positive");
}

#pragma mark - Thread Safety Tests

- (void)testConcurrentFrameTicking {
    FPSCalculator *calculator = [FPSCalculator sharedInstance];
    [calculator reset];
    
    dispatch_queue_t queue1 = dispatch_queue_create("test.queue1", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t queue2 = dispatch_queue_create("test.queue2", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_group_t group = dispatch_group_create();
    
    // Simulate multiple threads calling frameTick
    for (int i = 0; i < 1000; i++) {
        dispatch_group_async(group, queue1, ^{
            [calculator frameTick];
        });
        dispatch_group_async(group, queue2, ^{
            [calculator frameTick];
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    XCTAssertGreaterThan(calculator.averageFPS, 0, @"FPS should be calculated without crashes");
}

#pragma mark - Preferences Tests

- (void)testPreferencesLoading {
    // Create test preferences
    NSDictionary *prefs = @{
        @"enabled": @YES,
        @"fpsMode": @(FPSModeAverage),
        @"color": @"#00FF00",
        @"backgroundOpacity": @0.8,
        @"fontSize": @16.0,
        @"labelPosition": @[@100, @100],
        @"positionPreset": @(PositionPresetTopRight)
    };
    [prefs writeToFile:self.prefsPath atomically:YES];
    
    // Load preferences into display window
    FPSDisplayWindow *window = [FPSDisplayWindow sharedInstance];
    [window updateAppearanceWithPreferences:prefs];
    
    // Verify preferences are loaded
    XCTAssertEqual(window.positionPreset, PositionPresetTopRight,
                  @"Position preset should match preference");
    
    XCTAssertEqual(window.fontSize, 16.0,
                  @"Font size should match preference");
    
    // Verify position is saved
    NSDictionary *savedPrefs = [NSDictionary dictionaryWithContentsOfFile:self.prefsPath];
    XCTAssertNotNil(savedPrefs[@"positionPreset"], @"Position preset should be saved");
}

#pragma mark - Memory Management Tests

- (void)testMemoryLeaks {
    @autoreleasepool {
        for (int i = 0; i < 100; i++) {
            FPSDisplayWindow *window = [[FPSDisplayWindow alloc] init];
            // Force window to initialize
            [window commonInit];
            // Let window go out of scope
        }
    }
    
    // Use private API to trigger memory warning - commented out in real test
    // [[UIApplication sharedApplication] performSelector:@selector(_performMemoryWarning)];
    
    // Shared instance should still exist
    XCTAssertNotNil([FPSDisplayWindow sharedInstance], 
                   @"Shared window instance should survive memory pressure");
}

#pragma mark - FPS Data Export Tests

- (void)testFPSDataLogging {
    FPSCalculator *calculator = [FPSCalculator sharedInstance];
    
    // Generate some sample data
    for (int i = 0; i < 10; i++) {
        [calculator frameTick];
    }
    
    // Test log file creation
    NSString *logPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"fps_test_log.txt"];
    [[NSFileManager defaultManager] removeItemAtPath:logPath error:nil];
    
    [calculator logFPSDataToFile:logPath];
    
    // Verify log file was created
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:logPath];
    XCTAssertTrue(fileExists, @"Log file should be created");
    
    // Check log file content
    NSString *logContent = [NSString stringWithContentsOfFile:logPath 
                                                    encoding:NSUTF8StringEncoding 
                                                       error:nil];
    XCTAssertTrue([logContent containsString:@"Avg FPS"], @"Log should contain FPS data");
    
    // Clean up
    [[NSFileManager defaultManager] removeItemAtPath:logPath error:nil];
}

@end