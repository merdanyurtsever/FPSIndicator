#import "FPSIndicatorRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <spawn.h>  // Import for posix_spawn

/**
 * FPS App Selection Controller
 * Simple list to select which apps to enable the FPS indicator on
 */
@interface FPSAppSelectionController : PSListController
@property (nonatomic, strong) NSMutableArray *enabledApps;
@end

@implementation FPSIndicatorRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
    return settings[specifier.properties[@"key"]] ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    settings[specifier.properties[@"key"]] = value;
    [settings writeToFile:path atomically:YES];
    
    if (specifier.properties[@"PostNotification"]) {
        CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
    
    // Check if this toggle requires a respring
    if ([specifier.properties[@"key"] isEqualToString:@"enabled"] && [specifier.properties[@"requiresRespring"] boolValue]) {
        BOOL enabled = [value boolValue];
        // Only ask when turning on/off, not when it's already in that state
        if (enabled != [[self.previousValue objectForKey:@"enabled"] boolValue]) {
            [self showRespringAlert];
        }
    }
    
    // Check if this setting requires PUBG Mobile to be restarted
    if (([specifier.properties[@"key"] isEqualToString:@"pubgStealthMode"] || 
         [specifier.properties[@"key"] isEqualToString:@"usePUBGSpecialMode"] ||
         [specifier.properties[@"key"] isEqualToString:@"useQuartzCoreAPI"]) && 
        [specifier.properties[@"requiresRestart"] boolValue]) {
        
        // Check if the value actually changed
        id previousValue = [self.previousValue objectForKey:specifier.properties[@"key"]];
        if (previousValue && ![value isEqual:previousValue]) {
            [self showPUBGRestartAlert];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Store the initial values to check for changes later
    self.previousValue = [NSMutableDictionary dictionary];
    for (PSSpecifier *specifier in [self specifiers]) {
        if (specifier.properties[@"key"]) {
            self.previousValue[specifier.properties[@"key"]] = [self readPreferenceValue:specifier];
        }
    }
}

- (void)showRespringAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Respring Required"
                                                                  message:@"Changes to FPS Indicator require a respring to take effect. Would you like to respring now?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Later"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    UIAlertAction *respringAction = [UIAlertAction actionWithTitle:@"Respring Now"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * _Nonnull action) {
        [self respring];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:respringAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)respring {
    // Use a safer method to respring
    pid_t pid;
    const char *args[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
}

- (void)selectApps {
    FPSAppSelectionController *appSelector = [[FPSAppSelectionController alloc] init];
    [self.navigationController pushViewController:appSelector animated:YES];
}

- (void)showPUBGRestartAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PUBG Mobile Restart Required"
                                                                   message:@"Changes to PUBG Mobile security settings require you to restart PUBG Mobile to take effect."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Log File Management

- (void)viewLogFiles {
    // Load our log viewer class dynamically
    Class logViewerClass = NSClassFromString(@"FPSLogViewer");
    
    if (!logViewerClass) {
        UIAlertController *alert = [UIAlertController 
                                   alertControllerWithTitle:@"Not Available" 
                                   message:@"Log viewer is not available. Make sure you're using the latest version of FPSIndicator." 
                                   preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Get the log directory path method
    SEL logDirSel = NSSelectorFromString(@"logDirectoryPath");
    if (![logViewerClass respondsToSelector:logDirSel]) {
        UIAlertController *alert = [UIAlertController 
                                   alertControllerWithTitle:@"Error" 
                                   message:@"Cannot access log directory. Please update to the latest version." 
                                   preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Get log files using the allLogFilePaths method
    SEL allLogsSel = NSSelectorFromString(@"allLogFilePaths");
    if (![logViewerClass respondsToSelector:allLogsSel]) {
        UIAlertController *alert = [UIAlertController 
                                   alertControllerWithTitle:@"Error" 
                                   message:@"Cannot list log files. Please update to the latest version." 
                                   preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Suppress performSelector leak warning
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSArray *logFiles = [logViewerClass performSelector:allLogsSel];
    #pragma clang diagnostic pop
    
    if (!logFiles || logFiles.count == 0) {
        UIAlertController *alert = [UIAlertController 
                                   alertControllerWithTitle:@"No Log Files" 
                                   message:@"No FPS log files have been created yet. Use the Log File mode in PUBG Mobile to create log files." 
                                   preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Create a file list using UIAlertController
    UIAlertController *fileList = [UIAlertController 
                                  alertControllerWithTitle:@"FPS Log Files" 
                                  message:@"Select a log file to view:" 
                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Add an action for each log file
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    for (NSString *logPath in logFiles) {
        // Get file attributes to show the date
        NSDictionary *attrs = [fileManager attributesOfItemAtPath:logPath error:nil];
        NSDate *modDate = attrs[NSFileModificationDate];
        
        // Format the date and get the filename
        NSString *dateStr = [formatter stringFromDate:modDate];
        NSString *fileName = [logPath lastPathComponent];
        
        // Create an action for this file
        NSString *actionTitle = [NSString stringWithFormat:@"%@ (%@)", fileName, dateStr];
        [fileList addAction:[UIAlertAction actionWithTitle:actionTitle 
                                               style:UIAlertActionStyleDefault 
                                             handler:^(UIAlertAction * _Nonnull action) {
            // Use our notification approach to open the file
            NSString *encodedPath = [logPath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            
            // Store the path for the notification handler to use
            [[NSUserDefaults standardUserDefaults] setObject:encodedPath forKey:@"com.fpsindicator.lastLogPath"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Post a Darwin notification
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFSTR("com.fpsindicator/openLogFile"),
                NULL,
                NULL,
                YES
            );
        }]];
    }
    
    // Add a cancel action
    [fileList addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    // Handle iPad presentation
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        fileList.popoverPresentationController.sourceView = self.view;
        fileList.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 
                                                                      self.view.bounds.size.height / 2, 
                                                                      0, 0);
        fileList.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    // Present the alert
    [self presentViewController:fileList animated:YES completion:nil];
}

@end

#pragma mark - FPSAppSelectionController Implementation

@implementation FPSAppSelectionController {
    NSArray *_installedApps;
}

- (instancetype)init {
    if (self = [super init]) {
        self.title = @"Select Apps";
        self.enabledApps = [NSMutableArray array];
        
        // Load enabled apps list
        [self loadEnabledApps];
        
        // Get installed apps
        _installedApps = [self getInstalledApps];
    }
    return self;
}

- (void)loadEnabledApps {
    NSString *path = [NSString stringWithFormat:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist"];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
    
    // In our revamped system, we use a "disabledApps" array instead of "enabledApps"
    // So we need to invert the logic here
    if (settings[@"disabledApps"]) {
        NSArray *disabledApps = settings[@"disabledApps"];
        
        // Initialize with all possible apps
        NSMutableArray *allPossibleApps = [NSMutableArray array];
        for (NSDictionary *app in [self getInstalledApps]) {
            [allPossibleApps addObject:app[@"bundleID"]];
        }
        
        // Remove the disabled ones to get enabled apps
        for (NSString *bundleID in disabledApps) {
            [allPossibleApps removeObject:bundleID];
        }
        
        // If no apps are disabled, enable all
        if (disabledApps.count == 0) {
            [self.enabledApps addObject:@"*"];
        } else {
            [self.enabledApps addObjectsFromArray:allPossibleApps];
        }
    } else {
        // Default to enable on all apps
        self.enabledApps = [NSMutableArray arrayWithObject:@"*"];
    }
}

- (void)saveEnabledApps {
    NSString *path = [NSString stringWithFormat:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist"];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    
    // Convert enabledApps to disabledApps for the revamped system
    NSMutableArray *disabledApps = [NSMutableArray array];
    
    // Special case: if all apps are enabled, disabledApps should be empty
    if ([self.enabledApps containsObject:@"*"]) {
        settings[@"disabledApps"] = @[];
    } else {
        // Get all possible apps
        NSMutableArray *allPossibleApps = [NSMutableArray array];
        for (NSDictionary *app in [self getInstalledApps]) {
            [allPossibleApps addObject:app[@"bundleID"]];
        }
        
        // Determine which ones are disabled by finding those not in enabledApps
        for (NSString *bundleID in allPossibleApps) {
            if (![self.enabledApps containsObject:bundleID] && ![bundleID isEqualToString:@"*"]) {
                [disabledApps addObject:bundleID];
            }
        }
        
        settings[@"disabledApps"] = disabledApps;
    }
    
    [settings writeToFile:path atomically:YES];
    
    // Notify the tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                       CFSTR("com.fpsindicator/loadPref"), 
                                       NULL, NULL, YES);
}

- (NSArray *)getInstalledApps {
    // Simple built-in list of common game engines and platforms
    // In a production version, this would scan the installed apps
    return @[
        @{@"name": @"All Apps", @"bundleID": @"*"},
        @{@"name": @"Games Only", @"bundleID": @"games"},
        @{@"name": @"Unity Games", @"bundleID": @"unity"},
        @{@"name": @"Unreal Games", @"bundleID": @"unreal"},
        @{@"name": @"PUBG Mobile", @"bundleID": @"com.tencent.ig"},
        @{@"name": @"Fortnite", @"bundleID": @"com.epicgames.fortnite"},
        @{@"name": @"Minecraft", @"bundleID": @"com.mojang.minecraftpe"},
        @{@"name": @"Call of Duty Mobile", @"bundleID": @"com.activision.callofduty.shooter"},
        @{@"name": @"Genshin Impact", @"bundleID": @"com.miHoYo.GenshinImpact"},
        @{@"name": @"Roblox", @"bundleID": @"com.roblox.robloxmobile"},
        @{@"name": @"Among Us", @"bundleID": @"com.innersloth.amongus"}
    ];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        
        // Header section
        PSSpecifier *groupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Select apps to show FPS"
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:nil
                                                                      cell:PSGroupCell
                                                                      edit:nil];
        [groupSpecifier setProperty:@"Enable the FPS indicator for specific apps or categories" forKey:@"footerText"];
        [specs addObject:groupSpecifier];
        
        // Toggle for each app
        for (NSDictionary *app in _installedApps) {
            PSSpecifier *toggleSpec = [PSSpecifier preferenceSpecifierNamed:app[@"name"]
                                                                    target:self
                                                                       set:@selector(setAppEnabled:specifier:)
                                                                       get:@selector(isAppEnabled:)
                                                                    detail:nil
                                                                      cell:PSSwitchCell
                                                                      edit:nil];
            [toggleSpec setProperty:app[@"bundleID"] forKey:@"bundleID"];
            [specs addObject:toggleSpec];
        }
        
        _specifiers = specs;
    }
    
    return _specifiers;
}

- (id)isAppEnabled:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    
    // Special case for "All Apps"
    if ([bundleID isEqualToString:@"*"] && [self.enabledApps containsObject:@"*"]) {
        return @YES;
    }
    
    return @([self.enabledApps containsObject:bundleID]);
}

- (void)setAppEnabled:(id)value specifier:(PSSpecifier *)specifier {
    BOOL enabled = [value boolValue];
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    
    // Special handling for "All Apps"
    if ([bundleID isEqualToString:@"*"]) {
        if (enabled) {
            // If "All Apps" is enabled, clear list and just add "*"
            [self.enabledApps removeAllObjects];
            [self.enabledApps addObject:@"*"];
        } else {
            // If "All Apps" is disabled, remove it from the list
            [self.enabledApps removeObject:@"*"];
        }
    } else {
        // For regular apps
        if (enabled) {
            // When enabling a specific app, remove "All Apps" if present
            [self.enabledApps removeObject:@"*"];
            
            // Add the app to enabled list if not already there
            if (![self.enabledApps containsObject:bundleID]) {
                [self.enabledApps addObject:bundleID];
            }
        } else {
            // Remove the app from enabled list
            [self.enabledApps removeObject:bundleID];
        }
    }
    
    // Update prefs
    [self saveEnabledApps];
    
    // Refresh the UI to handle dependencies
    [self reloadSpecifiers];
}

@end
