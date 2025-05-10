#import "FPSGameSupport.h"
#import <UIKit/UIKit.h>
#import "FPSAlternativeOverlay.h"

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
    NSArray *_cocos2DIdentifiers;
    NSArray *_godotIdentifiers;
    NSArray *_gameMakerIdentifiers;
    NSArray *_privacyModeApps;
    
    // Properties to track additional engine detection
    BOOL _isCocos2DApp;
    BOOL _isGodotApp;
    BOOL _isGameMakerApp;
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
        
        _cocos2DIdentifiers = @[
            @"Cocos2D",
            @"cocos2d",
            @"CCDirector"
        ];
        
        _godotIdentifiers = @[
            @"GodotEngine",
            @"godot"
        ];
        
        _gameMakerIdentifiers = @[
            @"GameMaker",
            @"YoYoGames"
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
            [self initializePUBGMobileSupport];
            break;
            
        case GameEngineTypeCocos2D:
            NSLog(@"FPSIndicator: Initializing Cocos2D Engine support");
            break;
            
        case GameEngineTypeGodot:
            NSLog(@"FPSIndicator: Initializing Godot Engine support");
            break;
            
        case GameEngineTypeGameMaker:
            NSLog(@"FPSIndicator: Initializing GameMaker Engine support");
            break;
            
        case GameEngineTypeUnknown:
        default:
            NSLog(@"FPSIndicator: Using standard engine support");
            break;
    }
}

// New method for PUBG Mobile-specific support
- (void)initializePUBGMobileSupport {
    // Use CALayer-based overlay instead of UIWindow for PUBG
    // This avoids detection by PUBG's anti-cheat system
    [[FPSAlternativeOverlay sharedInstance] showWithFPS:0]; // Initialize with 0 FPS
    
    // Set up delayed initialization to avoid anti-cheat detection
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Initialize Metal frame counting
        [self setupMetalFrameCounter];
    });
}

// Setup Metal frame counter for more accurate PUBG FPS counting
- (void)setupMetalFrameCounter {
    // This method should be called after the game has fully initialized
    // to avoid early detection by anti-cheat
    if (!_isPUBGApp) return;
    
    NSLog(@"FPSIndicator: Setting up Metal frame counter for PUBG Mobile");
    
    // Use CADisplayLink with a very low update frequency to minimize detection risk
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updatePUBGFrameCounter:)];
    if (@available(iOS 10.0, *)) {
        displayLink.preferredFramesPerSecond = 2; // Update at only 2Hz to minimize footprint
    } else {
        // For older iOS versions, use frameInterval but suppress the deprecation warning
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        displayLink.frameInterval = 30; // ~2Hz (60/30)
        #pragma clang diagnostic pop
    }
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

// Update method for PUBG Metal frame counter
- (void)updatePUBGFrameCounter:(CADisplayLink *)link {
    if (!_isPUBGApp) return;
    
    // Get FPS from CADisplayLink
    static CFTimeInterval lastTime = 0;
    static NSInteger frameCount = 0;
    static double lastFPS = 0;
    
    // First update
    if (lastTime == 0) {
        lastTime = link.timestamp;
        return;
    }
    
    // Calculate time elapsed since last update
    CFTimeInterval currentTime = link.timestamp;
    CFTimeInterval timeDelta = currentTime - lastTime;
    
    frameCount++;
    
    // Update every ~0.5 seconds
    if (timeDelta >= 0.5) {
        lastFPS = frameCount / timeDelta;
        frameCount = 0;
        lastTime = currentTime;
        
        // Update the alternative overlay
        dispatch_async(dispatch_get_main_queue(), ^{
            [[FPSAlternativeOverlay sharedInstance] showWithFPS:lastFPS];
        });
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
            
        case GameEngineTypeCocos2D:
            return 8.0; // 8 Hz for Cocos2D
            
        case GameEngineTypeGodot:
            return 10.0; // 10 Hz for Godot
            
        case GameEngineTypeGameMaker:
            return 6.0; // 6 Hz for GameMaker
            
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
    
    // Check for Cocos2D engine
    _isCocos2DApp = [self checkForCocos2DEngine];
    if (_isCocos2DApp) {
        _detectedEngine = GameEngineTypeCocos2D;
        return;
    }
    
    // Check for Godot engine
    _isGodotApp = [self checkForGodotEngine];
    if (_isGodotApp) {
        _detectedEngine = GameEngineTypeGodot;
        return;
    }
    
    // Check for GameMaker engine
    _isGameMakerApp = [self checkForGameMakerEngine];
    if (_isGameMakerApp) {
        _detectedEngine = GameEngineTypeGameMaker;
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

- (BOOL)checkForCocos2DEngine {
    // Check for Cocos2D framework
    NSBundle *mainBundle = [NSBundle mainBundle];
    for (NSString *identifier in _cocos2DIdentifiers) {
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
    
    // Check for Cocos2D classes
    NSArray *cocos2DClasses = @[@"CCDirector", @"CCSprite", @"CCScene"];
    for (NSString *className in cocos2DClasses) {
        if (NSClassFromString(className)) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)checkForGodotEngine {
    // Check for Godot framework
    NSBundle *mainBundle = [NSBundle mainBundle];
    for (NSString *identifier in _godotIdentifiers) {
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
    
    // Check for Godot-specific files
    NSString *godotConfigPath = [mainBundle.bundlePath stringByAppendingPathComponent:@"godot.cfg"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:godotConfigPath]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)checkForGameMakerEngine {
    // Check for GameMaker framework
    NSBundle *mainBundle = [NSBundle mainBundle];
    for (NSString *identifier in _gameMakerIdentifiers) {
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
    
    // Check for GameMaker-specific files or class names
    NSArray *gameMakerClasses = @[@"GMRoom", @"GMSprite", @"GMObject"];
    for (NSString *className in gameMakerClasses) {
        if (NSClassFromString(className)) {
            return YES;
        }
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

#pragma mark - Additional Engine Detection

- (BOOL)isCocos2DApp {
    return _isCocos2DApp;
}

- (BOOL)isGodotApp {
    return _isGodotApp;
}

- (BOOL)isGameMakerApp {
    return _isGameMakerApp;
}

/**
 * Determines if a bundle ID corresponds to a game app
 * Uses heuristics and known game bundle ID patterns
 * @param bundleID The bundle ID to check
 * @return YES if the app is likely a game
 */
- (BOOL)isGameApp:(NSString *)bundleID {
    if (!bundleID) return NO;
    
    // Check if it's a known game engine app
    if ([self isUnityApp] || [self isUnrealApp] || [self isCocos2DApp] || 
        [self isGodotApp] || [self isGameMakerApp]) {
        return YES;
    }
    
    // Check for common game publisher identifiers
    NSArray *gamePublishers = @[
        @"com.supercell",
        @"com.king",
        @"com.rovio",
        @"com.ea.",
        @"com.gameloft",
        @"com.activision",
        @"com.ubisoft",
        @"com.tencent",
        @"com.epicgames",
        @"com.nintendo",
        @"com.sega",
        @"io.playimpact",
        @"com.mojang",
        @"com.namco",
        @"com.squareenix",
        @"com.rockstar",
        @"com.playrix",
        @"com.dena",
        @"com.zynga",
        @"com.innersloth",
        @"com.miHoYo"
    ];
    
    for (NSString *publisher in gamePublishers) {
        if ([bundleID hasPrefix:publisher]) {
            return YES;
        }
    }
    
    // Check for common game words in the bundle ID
    NSArray *gameKeywords = @[
        @"game", @"play", @"rpg", @"arcade", @"shooter", @"racing",
        @"puzzle", @"strategy", @"battle", @"adventure", @"quest",
        @"card", @"casino", @"chess", @"football", @"soccer", 
        @"basketball", @"golf", @"tennis", @"sport"
    ];
    
    NSString *lowercaseBundleID = [bundleID lowercaseString];
    for (NSString *keyword in gameKeywords) {
        if ([lowercaseBundleID containsString:keyword]) {
            return YES;
        }
    }
    
    // Check for known PUBG and similar games
    if ([_pubgBundleIDs containsObject:bundleID]) {
        return YES;
    }
    
    return NO;
}

@end