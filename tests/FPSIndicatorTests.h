#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface FPSIndicatorTests : XCTestCase

@property (nonatomic, strong) id mockWindow;
@property (nonatomic, strong) id mockLabel;
@property (nonatomic, strong) id mockScene;
@property (nonatomic, strong) NSString *prefsPath;

@end