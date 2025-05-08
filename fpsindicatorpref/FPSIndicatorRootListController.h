#import <Preferences/PSListController.h>

@interface FPSIndicatorRootListController : PSListController

// Store previous values to detect changes requiring respring
@property (nonatomic, strong) NSMutableDictionary *previousValue;

@end
