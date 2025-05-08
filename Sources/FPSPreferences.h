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

// Methods
- (void)loadPreferences;
- (void)savePreferences;
- (BOOL)shouldDisplayInApp:(NSString *)bundleID;
- (BOOL)isPrivacyModeEnabledForApp:(NSString *)bundleID;

// Singleton accessor
+ (instancetype)sharedPreferences;

@end