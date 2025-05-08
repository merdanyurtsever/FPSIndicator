#import <Foundation/Foundation.h>

/**
 * FPSGameSupport - Enhanced support for specific game engines and apps
 * 
 * This class provides specialized handling for different game engines and
 * applications, allowing for more accurate FPS counting and compatibility.
 */
@interface FPSGameSupport : NSObject

/**
 * Game engines supported for specialized handling
 */
typedef NS_ENUM(NSInteger, GameEngineType) {
    GameEngineTypeUnknown = 0,
    GameEngineTypeUnity,
    GameEngineTypeUnreal,
    GameEngineTypePUBG,
    GameEngineTypeCustom
};

/**
 * @property detectedEngine The currently detected game engine
 */
@property (nonatomic, readonly) GameEngineType detectedEngine;

/**
 * @property currentAppBundleID The bundle ID of the current application
 */
@property (nonatomic, readonly) NSString *currentAppBundleID;

/**
 * @property isPUBGApp Whether the current app is a PUBG Mobile app
 */
@property (nonatomic, readonly) BOOL isPUBGApp;

/**
 * @property isUnityApp Whether the current app uses Unity engine
 */
@property (nonatomic, readonly) BOOL isUnityApp;

/**
 * @property isUnrealApp Whether the current app uses Unreal engine
 */
@property (nonatomic, readonly) BOOL isUnrealApp;

/**
 * Shared instance accessor
 * @return The shared FPSGameSupport instance
 */
+ (instancetype)sharedInstance;

/**
 * Initializes support for the detected game engine
 * Sets up appropriate hooks and configurations
 */
- (void)initializeGameSupport;

/**
 * Gets the recommended window level for the current app
 * PUBG and similar games need higher window levels
 * @return The UIWindowLevel value to use for the FPS indicator
 */
- (NSInteger)recommendedWindowLevel;

/**
 * Gets the recommended refresh rate for FPS counting for the current app
 * Some engines work better with different refresh rates
 * @return The refresh rate (calls per second) for optimal FPS counting
 */
- (double)recommendedFrameDetectionRate;

/**
 * Determines if the current app should use special Metal hooks
 * @return YES if special Metal hooks should be used
 */
- (BOOL)shouldUseSpecialMetalHooks;

/**
 * Determines if the current app should use OpenGL hooks
 * @return YES if OpenGL hooks should be used
 */
- (BOOL)shouldUseOpenGLHooks;

/**
 * Checks if the current app is in the privacy list
 * @return YES if the app should enable privacy mode
 */
- (BOOL)shouldEnablePrivacyMode;

@end