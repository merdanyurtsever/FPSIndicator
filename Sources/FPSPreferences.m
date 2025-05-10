// FPSPreferences.m
#import "FPSPreferences.h"

// Using the kPrefPath from Prefix.pch instead of redefining it
// Previously: #define kPrefPath @"/var/mobile/Library/Preferences/com.fpsindicator.plist"

@implementation FPSPreferences {
    NSMutableDictionary *_prefsCache;
}

+ (instancetype)sharedPreferences {
    static FPSPreferences *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FPSPreferences alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _prefsCache = [NSMutableDictionary dictionary];
        
        // Set default values
        _enabled = YES;
        _fontSize = 14.0;
        _textColor = [UIColor whiteColor];
        _opacity = 0.7;
        _colorCoding = YES;
        _disabledApps = @[];
        _privacyApps = @[];
        _customPosition = CGPointMake(20, 40);
        
        // Load saved preferences
        [self loadPreferences];
    }
    return self;
}

- (void)loadPreferences {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) {
        NSLog(@"FPSIndicator: No preferences found at path: %@, using defaults", kPrefPath);
        prefs = [NSMutableDictionary dictionary];
    }
    
    // Cache preferences for later use
    _prefsCache = [prefs mutableCopy];
    
    // Get values with defaults
    _enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
    _fontSize = prefs[@"fontSize"] ? [prefs[@"fontSize"] floatValue] : 14.0;
    _opacity = prefs[@"opacity"] ? [prefs[@"opacity"] floatValue] : 0.7;
    _colorCoding = prefs[@"colorCoding"] ? [prefs[@"colorCoding"] boolValue] : YES;
    
    // Text color (with default white)
    if (prefs[@"textColorHex"]) {
        _textColor = [self colorFromHexString:prefs[@"textColorHex"]];
    } else {
        _textColor = [UIColor whiteColor];
    }
    
    // Arrays of app identifiers
    _disabledApps = prefs[@"disabledApps"] ?: @[];
    _privacyApps = prefs[@"privacyApps"] ?: @[];
    
    // Custom position (with default)
    CGFloat posX = prefs[@"positionX"] ? [prefs[@"positionX"] floatValue] : 20.0;
    CGFloat posY = prefs[@"positionY"] ? [prefs[@"positionY"] floatValue] : 40.0;
    _customPosition = CGPointMake(posX, posY);
    
    // PUBG Mobile specific settings
    _pubgStealthMode = prefs[@"pubgStealthMode"] ? [prefs[@"pubgStealthMode"] integerValue] : 1;
    _usePUBGSpecialMode = prefs[@"usePUBGSpecialMode"] ? [prefs[@"usePUBGSpecialMode"] boolValue] : YES;
    _useMetalHooks = prefs[@"useMetalHooks"] ? [prefs[@"useMetalHooks"] boolValue] : NO;
    _useQuartzCoreAPI = prefs[@"useQuartzCoreAPI"] ? [prefs[@"useQuartzCoreAPI"] boolValue] : NO;
    _pubgRefreshRate = prefs[@"pubgRefreshRate"] ? [prefs[@"pubgRefreshRate"] floatValue] : 2.0;
    
    // Apply settings to PUBG support if it's initialized
    Class pubgSupportClass = NSClassFromString(@"FPSPUBGSupport");
    if (pubgSupportClass) {
        id sharedInstance = [pubgSupportClass performSelector:@selector(sharedInstance)];
        if (sharedInstance) {
            [sharedInstance setValue:@(_pubgStealthMode) forKey:@"stealthMode"];
            [sharedInstance setValue:@(_useQuartzCoreAPI) forKey:@"useQuartzCoreDebug"];
            [sharedInstance setValue:@(_pubgRefreshRate) forKey:@"refreshRate"];
        }
    }
    
    // Apply preferences to FPSDisplay if it exists
    dispatch_async(dispatch_get_main_queue(), ^{
        Class displayClass = NSClassFromString(@"FPSDisplay");
        if (displayClass && [displayClass respondsToSelector:@selector(sharedInstance)]) {
            id display = [displayClass performSelector:@selector(sharedInstance)];
            
            // Use performSelector instead of direct method calls to avoid compilation errors
            if ([display respondsToSelector:@selector(setFontSize:)]) {
                [display performSelector:@selector(setFontSize:) withObject:@(self.fontSize)];
            }
            if ([display respondsToSelector:@selector(setTextColor:)]) {
                [display performSelector:@selector(setTextColor:) withObject:self.textColor];
            }
            if ([display respondsToSelector:@selector(setBackgroundAlpha:)]) {
                NSNumber *opacity = @(self.opacity);
                [display performSelector:@selector(setBackgroundAlpha:) withObject:opacity];
            }
            if ([display respondsToSelector:@selector(setColorCoding:)]) {
                [display performSelector:@selector(setColorCoding:) withObject:@(self.colorCoding)];
            }
            if ([display respondsToSelector:@selector(setPosition:)]) {
                // Using NSValue to wrap CGPoint for performSelector
                NSValue *pointValue = [NSValue valueWithCGPoint:self.customPosition];
                [display performSelector:@selector(setPosition:) withObject:pointValue];
            }
            if ([display respondsToSelector:@selector(updatePosition)]) {
                [display performSelector:@selector(updatePosition)];
            }
        }
    });
}

- (void)savePreferences {
    // Update cache with current values
    _prefsCache[@"enabled"] = @(self.enabled);
    _prefsCache[@"fontSize"] = @(self.fontSize);
    _prefsCache[@"opacity"] = @(self.opacity);
    _prefsCache[@"colorCoding"] = @(self.colorCoding);
    
    // Save position
    _prefsCache[@"positionX"] = @(self.customPosition.x);
    _prefsCache[@"positionY"] = @(self.customPosition.y);
    
    // Save text color
    _prefsCache[@"textColor"] = [self hexStringFromColor:self.textColor];
    
    // Save arrays
    _prefsCache[@"disabledApps"] = self.disabledApps;
    _prefsCache[@"privacyApps"] = self.privacyApps;
    
    // Save PUBG Mobile specific settings
    _prefsCache[@"pubgStealthMode"] = @(self.pubgStealthMode);
    _prefsCache[@"usePUBGSpecialMode"] = @(self.usePUBGSpecialMode);
    _prefsCache[@"useMetalHooks"] = @(self.useMetalHooks);
    _prefsCache[@"useQuartzCoreAPI"] = @(self.useQuartzCoreAPI);
    _prefsCache[@"pubgRefreshRate"] = @(self.pubgRefreshRate);
    
    // Write to file
    [_prefsCache writeToFile:kPrefPath atomically:YES];
    
    // Post notification to reload preferences in other processes
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.fpsindicator/loadPref"),
        NULL, NULL, YES
    );
}

- (BOOL)shouldDisplayInApp:(NSString *)bundleID {
    if (!bundleID) return YES;
    return ![self.disabledApps containsObject:bundleID];
}

- (BOOL)isPrivacyModeEnabledForApp:(NSString *)bundleID {
    if (!bundleID) return NO;
    return [self.privacyApps containsObject:bundleID];
}

- (void)setCustomPosition:(CGPoint)position {
    _customPosition = position;
}

#pragma mark - Color Utilities

- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // Skip '#' character
    [scanner scanHexInt:&rgbValue];
    
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 
                           green:((rgbValue & 0x00FF00) >> 8)/255.0 
                            blue:(rgbValue & 0x0000FF)/255.0 
                           alpha:1.0];
}

- (NSString *)hexStringFromColor:(UIColor *)color {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    
    return [NSString stringWithFormat:@"#%02X%02X%02X", 
            (int)(r * 255), 
            (int)(g * 255), 
            (int)(b * 255)];
}

#pragma mark - Accessor Methods

// Accessor for PUBG refresh rate
- (CGFloat)refreshRate {
    // Return the PUBG refresh rate or a reasonable default
    return self.pubgRefreshRate > 0 ? self.pubgRefreshRate : 2.0;
}

// Accessor for QuartzCore debug API usage
- (BOOL)useQuartzDebug {
    return self.useQuartzCoreAPI;
}

@end