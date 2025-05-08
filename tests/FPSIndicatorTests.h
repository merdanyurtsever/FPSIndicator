#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>

#import "../Sources/FPSCalculator.h"
#import "../Sources/FPSDisplayWindow.h"
#import "../Sources/FPSGameSupport.h"

/**
 * FPSIndicatorTests - Test suite for the FPSIndicator tweak
 *
 * This test class verifies the functionality of the FPSIndicator components
 * including calculation accuracy, UI behavior, and compatibility features.
 */
@interface FPSIndicatorTests : XCTestCase

// Mocks for testing
@property (nonatomic, strong) id mockWindow;
@property (nonatomic, strong) id mockLabel;
@property (nonatomic, strong) id mockScene;
@property (nonatomic, strong) NSString *prefsPath;

@end