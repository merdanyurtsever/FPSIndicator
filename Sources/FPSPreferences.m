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
    if (prefs[@"textColor"]) {
        NSString *hexColor = prefs[@"textColor"];
        _textColor = [self colorWithHexString:hexColor];
    } else {
        _textColor = [UIColor whiteColor];
    }
    
    // Array values
    _disabledApps = prefs[@"disabledApps"] ? prefs[@"disabledApps"] : @[];
    _privacyApps = prefs[@"privacyApps"] ? prefs[@"privacyApps"] : @[];
    
    // Custom position
    if (prefs[@"positionX"] && prefs[@"positionY"]) {
        CGFloat x = [prefs[@"positionX"] floatValue];
        CGFloat y = [prefs[@"positionY"] floatValue];
        _customPosition = CGPointMake(x, y);
    } else {
        _customPosition = CGPointMake(20, 40);
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

- (UIColor *)colorWithHexString:(NSString *)hexString {
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

@end