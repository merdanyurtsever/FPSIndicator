// FPSPreferences.h
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * FPSPreferences - Centralized preference management
 * 
 * Provides a single source of truth for all preferences related to the FPS indicator,
 * with simplified methods for accessing and saving settings.
 */
@interface FPSPreferences : NSObject

// Core preferences
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, assign) CGFloat opacity;
@property (nonatomic, assign) BOOL colorCoding;
@property (nonatomic, strong) NSArray<NSString *> *disabledApps;
@property (nonatomic, strong) NSArray<NSString *> *privacyApps;
@property (nonatomic, assign) CGPoint customPosition;

// PUBG Mobile specific settings
@property (nonatomic, assign) NSInteger pubgStealthMode;
@property (nonatomic, assign) NSInteger pubgUiMode;
@property (nonatomic, assign) BOOL usePUBGSpecialMode;
@property (nonatomic, assign) BOOL useMetalHooks;
@property (nonatomic, assign) BOOL useQuartzCoreAPI;
@property (nonatomic, assign) BOOL useCoreAnimationPerfHUD;
@property (nonatomic, assign) CGFloat pubgRefreshRate;

// Methods
- (void)loadPreferences;
- (void)savePreferences;
- (BOOL)shouldDisplayInApp:(NSString *)bundleID;
- (BOOL)isPrivacyModeEnabledForApp:(NSString *)bundleID;
- (CGFloat)refreshRate; // Alias for pubgRefreshRate
- (BOOL)useQuartzDebug; // Alias for useQuartzCoreAPI

// Utility methods
- (UIColor *)colorFromHexString:(NSString *)hexString;
- (NSString *)hexStringFromColor:(UIColor *)color;

// Singleton accessor
+ (instancetype)sharedPreferences;

@end