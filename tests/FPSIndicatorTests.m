#import "FPSIndicatorTests.h"
#import "../Tweak.h"

@implementation FPSIndicatorTests

- (void)setUp {
    [super setUp];
    self.mockWindow = OCMClassMock([FPSWindow class]);
    self.mockLabel = OCMClassMock([UILabel class]);
    self.mockScene = OCMClassMock([UIWindowScene class]);
    self.prefsPath = @"/tmp/test_fps_prefs.plist";
}

- (void)tearDown {
    [self.mockWindow stopMocking];
    [self.mockLabel stopMocking];
    [self.mockScene stopMocking];
    [[NSFileManager defaultManager] removeItemAtPath:self.prefsPath error:nil];
    [super tearDown];
}

#pragma mark - FPS Calculation Tests

- (void)testFrameTickAccuracy {
    // Test frame counting accuracy
    for (int i = 0; i < 60; i++) {
        frameTick();
        usleep(16667); // Simulate 60 FPS timing
    }
    XCTAssertTrue(FPSavg >= 55.0 && FPSavg <= 65.0, @"FPS average should be close to 60");
    XCTAssertTrue(FPSPerSecond >= 55.0 && FPSPerSecond <= 65.0, @"FPS per second should be close to 60");
}

- (void)testLowFPSAccuracy {
    for (int i = 0; i < 30; i++) {
        frameTick();
        usleep(33333); // Simulate 30 FPS timing
    }
    XCTAssertTrue(FPSavg >= 25.0 && FPSavg <= 35.0, @"FPS average should be close to 30");
}

#pragma mark - Window Management Tests

- (void)testWindowInitialization {
    FPSWindow *window = [[FPSWindow alloc] init];
    XCTAssertNotNil(window, @"Window should be created");
    XCTAssertNotNil(window.fpsLabel, @"FPS label should be created");
    XCTAssertTrue(window.userInteractionEnabled, @"Window should be interactive");
}

- (void)testWindowSceneHandling {
    if (@available(iOS 13.0, *)) {
        FPSWindow *window = [[FPSWindow alloc] initWithWindowScene:self.mockScene];
        XCTAssertNotNil(window.windowScene, @"Window scene should be set");
    }
}

#pragma mark - Preferences Tests

- (void)testPreferencesLoading {
    NSDictionary *prefs = @{
        @"enabled": @YES,
        @"fpsMode": @(kModeAverage),
        @"opacity": @0.8,
        @"labelPosition": @[@100, @100]
    };
    [prefs writeToFile:self.prefsPath atomically:YES];
    
    loadPref();
    XCTAssertTrue(enabled, @"Enabled preference should be loaded");
    XCTAssertEqual(fpsMode, kModeAverage, @"FPS mode should be set correctly");
}

- (void)testPreferencesSaving {
    FPSWindow *window = [[FPSWindow alloc] init];
    CGPoint newPosition = CGPointMake(100, 100);
    [window handleFPSLabelPan:[[UIPanGestureRecognizer alloc] init]];
    
    NSDictionary *savedPrefs = [NSDictionary dictionaryWithContentsOfFile:self.prefsPath];
    XCTAssertNotNil(savedPrefs[@"labelPosition"], @"Position should be saved");
}

#pragma mark - Thread Safety Tests

- (void)testConcurrentFrameTicking {
    dispatch_queue_t queue1 = dispatch_queue_create("test.queue1", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t queue2 = dispatch_queue_create("test.queue2", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_group_t group = dispatch_group_create();
    
    // Simulate multiple threads calling frameTick
    for (int i = 0; i < 1000; i++) {
        dispatch_group_async(group, queue1, ^{
            frameTick();
        });
        dispatch_group_async(group, queue2, ^{
            frameTick();
        });
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    XCTAssertGreaterThan(FPSavg, 0, @"FPS should be calculated without crashes");
}

#pragma mark - Metal Integration Tests

- (void)testMetalFrameCapture {
    id mockDrawable = OCMClassMock([CAMetalDrawable class]);
    OCMStub([mockDrawable present]);
    
    [mockDrawable present];
    XCTAssertGreaterThan(FPSavg, 0, @"Metal frame should be captured");
    
    [mockDrawable stopMocking];
}

#pragma mark - Memory Management Tests

- (void)testMemoryLeaks {
    @autoreleasepool {
        for (int i = 0; i < 1000; i++) {
            FPSWindow *window = [[FPSWindow alloc] init];
            [window commonInit];
        }
    }
    
    // Use private API to trigger memory warning
    [[UIApplication sharedApplication] performSelector:@selector(_performMemoryWarning)];
    
    XCTAssertNotNil(fpsWindow, @"Main FPS window should survive memory warning");
}

#pragma mark - UI Tests

- (void)testLabelVisibility {
    FPSWindow *window = [[FPSWindow alloc] init];
    XCTAssertFalse(window.fpsLabel.hidden, @"FPS label should be visible by default");
    
    // Test low power mode
    if (@available(iOS 9.0, *)) {
        [NSProcessInfo processInfo].lowPowerModeEnabled = YES;
        handlePowerModeChange();
        XCTAssertTrue(window.fpsLabel.alpha < 1.0, @"Label should be dimmed in low power mode");
    }
}

- (void)testScreenRecordingBehavior {
    if (@available(iOS 11.0, *)) {
        id mockScreen = OCMClassMock([UIScreen class]);
        OCMStub([mockScreen isCaptured]).andReturn(YES);
        
        handleScreenRecording();
        XCTAssertTrue(fpsWindow.hidden, @"Window should be hidden during screen recording");
        
        [mockScreen stopMocking];
    }
}

@end