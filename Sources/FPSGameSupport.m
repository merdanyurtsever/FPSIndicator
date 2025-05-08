#import "FPSGameSupport.h"
#import <UIKit/UIKit.h>

// NSTask interface declaration for iOS since it's not public
@interface NSTask : NSObject
- (instancetype)init;
- (void)setLaunchPath:(NSString *)path;
- (void)setArguments:(NSArray *)arguments;
- (void)setStandardOutput:(id)output;
- (void)launch;
@end

// Constants

@implementation FPSGameSupport {
    NSArray *_pubgBundleIDs;
    NSArray *_unityIdentifiers;
    NSArray *_unrealIdentifiers;
    NSArray *_privacyModeApps;
}

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static FPSGameSupport *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FPSGameSupport alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _pubgBundleIDs = @[
            @"com.tencent.ig",
            @"com.pubg.krmobile",
            @"com.tencent.tmgp.pubgmhd"
        ];
        
        _unityIdentifiers = @[
            @"UnityFramework",
            @"UnityEngine",
            @"unity"
        ];
        
        _unrealIdentifiers = @[
            @"UnrealEngine",
            @"UE4Game"
        ];
        
        // Default privacy mode apps
        _privacyModeApps = @[
            @"com.apple.Passbook",
            @"com.paypal.PPClient",
            @"com.venmo.TouchFree",
            @"com.chase.sig.Chase"
        ];
        
        // Load privacy app list from preferences
        [self loadPrivacyAppList];
        
        // Detect the current app and engine
        [self detectCurrentApp];
    }
    return self;
}

#pragma mark - Public Methods

- (void)initializeGameSupport {
    // Specific initialization based on the detected engine
    switch (_detectedEngine) {
        case GameEngineTypeUnity:
            NSLog(@"FPSIndicator: Initializing Unity Engine support");
            break;
            
        case GameEngineTypeUnreal:
            NSLog(@"FPSIndicator: Initializing Unreal Engine support");
            break;
            
        case GameEngineTypePUBG:
            NSLog(@"FPSIndicator: Initializing PUBG Mobile support");
            break;
            
        case GameEngineTypeUnknown:
        default:
            NSLog(@"FPSIndicator: Using standard engine support");
            break;
    }
}

- (NSInteger)recommendedWindowLevel {
    // PUBG and similar games need much higher window levels
    if (_isPUBGApp) {
        return UIWindowLevelStatusBar + 10000;
    }
    
    // Unity games sometimes need higher window levels too
    if (_isUnityApp) {
        return UIWindowLevelStatusBar + 500;
    }
    
    // Default window level
    return UIWindowLevelStatusBar + 100;
}

- (double)recommendedFrameDetectionRate {
    // Different refresh rates based on the engine
    switch (_detectedEngine) {
        case GameEngineTypeUnity:
            return 10.0; // 10 Hz for Unity
            
        case GameEngineTypeUnreal:
            return 8.0; // 8 Hz for Unreal
            
        case GameEngineTypePUBG:
            return 5.0; // 5 Hz for PUBG
            
        case GameEngineTypeUnknown:
        default:
            return 5.0; // 5 Hz default
    }
}

- (BOOL)shouldUseSpecialMetalHooks {
    // Unity and Unreal often use Metal
    return _isUnityApp || _isUnrealApp || _isPUBGApp;
}

- (BOOL)shouldUseOpenGLHooks {
    // Many older games still use OpenGL ES
    // Check if the app links against OpenGL
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *executablePath = [mainBundle executablePath];
    
    if (executablePath) {
        // Simple check for OpenGL framework usage
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/otool"];
        [task setArguments:@[@"-L", executablePath]];
        
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        
        NSFileHandle *file = [pipe fileHandleForReading];
        
        @try {
            [task launch];
            NSData *data = [file readDataToEndOfFile];
            NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            // Check for OpenGL ES framework
            return [output containsString:@"OpenGLES.framework"];
        } @catch (NSException *exception) {
            NSLog(@"FPSIndicator: Error checking OpenGL: %@", exception);
        }
    }
    
    // Default to false if we couldn't check
    return NO;
}

- (BOOL)shouldEnablePrivacyMode {
    if (!_currentAppBundleID) return NO;
    
    return [_privacyModeApps containsObject:_currentAppBundleID];
}

#pragma mark - Private Methods

- (void)detectCurrentApp {
    // Get current app's bundle ID
    _currentAppBundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    // Check if this is a PUBG app
    _isPUBGApp = [_pubgBundleIDs containsObject:_currentAppBundleID];
    if (_isPUBGApp) {
        _detectedEngine = GameEngineTypePUBG;
        return;
    }
    
    // Check for Unity engine
    _isUnityApp = [self checkForUnityEngine];
    if (_isUnityApp) {
        _detectedEngine = GameEngineTypeUnity;
        return;
    }
    
    // Check for Unreal engine
    _isUnrealApp = [self checkForUnrealEngine];
    if (_isUnrealApp) {
        _detectedEngine = GameEngineTypeUnreal;
        return;
    }
    
    // Default to unknown
    _detectedEngine = GameEngineTypeUnknown;
}

- (BOOL)checkForUnityEngine {
    // Check for Unity framework
    NSBundle *mainBundle = [NSBundle mainBundle];
    for (NSString *identifier in _unityIdentifiers) {
        // Check bundle identifier
        if ([_currentAppBundleID containsString:identifier]) {
            return YES;
        }
        
        // Check frameworks
        NSString *frameworkPath = [mainBundle.privateFrameworksPath stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"%@.framework", identifier]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:frameworkPath]) {
            return YES;
        }
    }
    
    // Check Info.plist for Unity
    NSDictionary *infoDictionary = [mainBundle infoDictionary];
    if ([infoDictionary[@"DTSDKName"] containsString:@"Unity"]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)checkForUnrealEngine {
    // Check for Unreal framework
    NSBundle *mainBundle = [NSBundle mainBundle];
    for (NSString *identifier in _unrealIdentifiers) {
        // Check bundle identifier
        if ([_currentAppBundleID containsString:identifier]) {
            return YES;
        }
        
        // Check frameworks
        NSString *frameworkPath = [mainBundle.privateFrameworksPath stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"%@.framework", identifier]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:frameworkPath]) {
            return YES;
        }
    }
    
    // Check Info.plist for Unreal
    NSDictionary *infoDictionary = [mainBundle infoDictionary];
    if ([infoDictionary[@"DTSDKName"] containsString:@"Unreal"]) {
        return YES;
    }
    
    return NO;
}

- (void)loadPrivacyAppList {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) return;
    
    if (prefs[@"privacyApps"]) {
        _privacyModeApps = prefs[@"privacyApps"];
    }
}

@end