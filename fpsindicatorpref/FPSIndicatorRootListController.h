#import <Preferences/PSListController.h>

@interface FPSIndicatorRootListController : PSListController

// Store previous values to detect changes requiring respring
@property (nonatomic, strong) NSMutableDictionary *previousValue;

// Log file management
- (void)viewLogFiles;

@end
