#import "FPSIndicatorRootListController.h"
#import "BDInfoListController.h"
#import <Preferences/PSSpecifier.h>

/**
 * Privacy Apps Manager Controller
 * Used to manage the list of apps where FPS indicator should be hidden
 */
@interface FPSPrivacyAppsController : PSListController
@property (nonatomic, strong) NSMutableArray *privacyApps;
@end

/**
 * FPS Data Export Controller
 * Handles exporting FPS logs for analysis
 */
@interface FPSDataExportController : PSListController
@end

@implementation FPSIndicatorRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        
        // Add privacy mode section
        [self addPrivacyModeSpecifiers];
        
        // Add about section
        PSSpecifier* spec = [PSSpecifier preferenceSpecifierNamed:FPSNSLocalizedString(@"ABOUT_AUTHOR")
                                          target:self
                                          set:NULL
                                          get:NULL
                                          detail:Nil
                                          cell:PSLinkCell
                                          edit:Nil];
        spec->action = @selector(showInfo);
        [(NSMutableArray *)_specifiers addObject:spec];
        
        // Update theme options based on iOS version
        if (@available(iOS 13.0, *)) {
            // Keep all theme options
        } else {
            // Remove system theme option for older iOS
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier != %@", @"appearance"];
            NSArray *filtered = [_specifiers filteredArrayUsingPredicate:predicate];
            _specifiers = [[NSMutableArray alloc] initWithArray:filtered];
        }
    }
    return _specifiers;
}

- (void)addPrivacyModeSpecifiers {
    // Add section header
    PSSpecifier *privacyHeader = [PSSpecifier preferenceSpecifierNamed:@"Privacy & Analytics"
                                                    target:self
                                                       set:NULL
                                                       get:NULL
                                                    detail:Nil
                                                      cell:PSGroupCell
                                                      edit:Nil];
    [(NSMutableArray *)_specifiers addObject:privacyHeader];
    
    // Add toggle for privacy mode
    PSSpecifier *privacyToggle = [PSSpecifier preferenceSpecifierNamed:@"Enable Privacy Mode"
                                                   target:self
                                                      set:@selector(setPreferenceValue:specifier:)
                                                      get:@selector(readPreferenceValue:)
                                                   detail:Nil
                                                     cell:PSSwitchCell
                                                     edit:Nil];
    [privacyToggle setProperty:@"com.fpsindicator" forKey:@"defaults"];
    [privacyToggle setProperty:@"privacyModeEnabled" forKey:@"key"];
    [privacyToggle setProperty:@NO forKey:@"default"];
    [privacyToggle setProperty:@"Privacy mode hides FPS indicator in banking and other sensitive apps" forKey:@"footerText"];
    [privacyToggle setProperty:@"com.fpsindicator/loadPref" forKey:@"PostNotification"];
    [(NSMutableArray *)_specifiers addObject:privacyToggle];
    
    // Add manage privacy apps button
    PSSpecifier *managePrivacyApps = [PSSpecifier preferenceSpecifierNamed:@"Manage Privacy Apps"
                                                  target:self
                                                     set:NULL
                                                     get:NULL
                                                  detail:Nil
                                                    cell:PSButtonCell
                                                    edit:Nil];
    managePrivacyApps->action = @selector(managePrivacyApps);
    [(NSMutableArray *)_specifiers addObject:managePrivacyApps];
    
    // Add FPS logging toggle
    PSSpecifier *loggingToggle = [PSSpecifier preferenceSpecifierNamed:@"Enable FPS Logging"
                                                  target:self
                                                     set:@selector(setPreferenceValue:specifier:)
                                                     get:@selector(readPreferenceValue:)
                                                  detail:Nil
                                                    cell:PSSwitchCell
                                                    edit:Nil];
    [loggingToggle setProperty:@"com.fpsindicator" forKey:@"defaults"];
    [loggingToggle setProperty:@"enableLogging" forKey:@"key"];
    [loggingToggle setProperty:@NO forKey:@"default"];
    [loggingToggle setProperty:@"Logs FPS data to a file for later analysis" forKey:@"footerText"];
    [loggingToggle setProperty:@"com.fpsindicator/loadPref" forKey:@"PostNotification"];
    [(NSMutableArray *)_specifiers addObject:loggingToggle];
    
    // Add export logs button
    PSSpecifier *exportLogs = [PSSpecifier preferenceSpecifierNamed:@"Export FPS Logs"
                                                 target:self
                                                    set:NULL
                                                    get:NULL
                                                 detail:Nil
                                                   cell:PSButtonCell
                                                   edit:Nil];
    exportLogs->action = @selector(exportFPSData);
    [(NSMutableArray *)_specifiers addObject:exportLogs];
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
}

- (void)showInfo {
    if (@available(iOS 13.0, *)) {
        self.navigationItem.backButtonTitle = @"";
    } else {
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" 
                                                                               style:UIBarButtonItemStylePlain 
                                                                              target:nil 
                                                                              action:nil];
    }
    [self.navigationController pushViewController:[[BDInfoListController alloc] init] animated:YES];
}

- (void)resetPosition {
    NSString *path = [NSString stringWithFormat:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist"];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    
    // Remove saved position and set to default preset
    [settings removeObjectForKey:@"labelPosition"];
    settings[@"positionPreset"] = @(0); // Top right default
    [settings writeToFile:path atomically:YES];
    
    // Notify the tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                       CFSTR("com.fpsindicator/loadPref"), 
                                       NULL, NULL, YES);
    
    // Show confirmation with modern alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FPSIndicator"
                                                                  message:@"Position has been reset to top right"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
    [alert addAction:okAction];
    
    if (@available(iOS 13.0, *)) {
        // Use overrideUserInterfaceStyle if available
        alert.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)managePrivacyApps {
    if (@available(iOS 13.0, *)) {
        self.navigationItem.backButtonTitle = @"";
    } else {
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" 
                                                                                  style:UIBarButtonItemStylePlain 
                                                                                 target:nil 
                                                                                 action:nil];
    }
    
    // Create and push the privacy apps controller
    FPSPrivacyAppsController *privacyController = [[FPSPrivacyAppsController alloc] init];
    [self.navigationController pushViewController:privacyController animated:YES];
}

- (void)exportFPSData {
    // Check if logging is enabled
    NSString *path = [NSString stringWithFormat:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist"];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    
    BOOL loggingEnabled = [settings[@"enableLogging"] boolValue];
    if (!loggingEnabled) {
        // Show alert that logging needs to be enabled first
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FPS Logging"
                                                                      message:@"Please enable FPS logging first to collect data"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Push export controller or handle export directly
    FPSDataExportController *exportController = [[FPSDataExportController alloc] init];
    [self.navigationController pushViewController:exportController animated:YES];
}

@end

#pragma mark - FPSPrivacyAppsController Implementation

@implementation FPSPrivacyAppsController

- (instancetype)init {
    if (self = [super init]) {
        self.title = @"Privacy Apps";
        self.privacyApps = [NSMutableArray array];
        
        // Load existing privacy apps list
        [self loadPrivacyApps];
    }
    return self;
}

- (void)loadPrivacyApps {
    NSString *path = [NSString stringWithFormat:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist"];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
    
    if (settings[@"privacyApps"]) {
        [self.privacyApps addObjectsFromArray:settings[@"privacyApps"]];
    } else {
        // Default privacy list - banking and financial apps
        [self.privacyApps addObjectsFromArray:@[
            @"com.apple.Passbook",
            @"com.paypal.PPClient",
            @"com.venmo.TouchFree",
            @"com.chase.sig.Chase"
        ]];
    }
}

- (void)savePrivacyApps {
    NSString *path = [NSString stringWithFormat:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist"];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    
    settings[@"privacyApps"] = self.privacyApps;
    [settings writeToFile:path atomically:YES];
    
    // Notify the tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                      CFSTR("com.fpsindicator/loadPref"), 
                                      NULL, NULL, YES);
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        
        // Header section
        PSSpecifier *groupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Privacy Apps"
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:nil
                                                                      cell:PSGroupCell
                                                                      edit:nil];
        [groupSpecifier setProperty:@"FPS indicator will automatically hide in these apps" forKey:@"footerText"];
        [specs addObject:groupSpecifier];
        
        // List all current privacy apps
        for (NSString *bundleID in self.privacyApps) {
            PSSpecifier *appSpec = [PSSpecifier preferenceSpecifierNamed:[self appNameForBundleID:bundleID]
                                                                  target:self
                                                                     set:NULL
                                                                     get:NULL
                                                                  detail:nil
                                                                    cell:PSButtonCell
                                                                    edit:nil];
            [appSpec setProperty:bundleID forKey:@"bundleID"];
            appSpec->action = @selector(removePrivacyApp:);
            [specs addObject:appSpec];
        }
        
        // Add app button
        PSSpecifier *addButtonSpec = [PSSpecifier preferenceSpecifierNamed:@"Add App to Privacy List"
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:nil
                                                                      cell:PSButtonCell
                                                                      edit:nil];
        addButtonSpec->action = @selector(addPrivacyApp);
        [specs addObject:addButtonSpec];
        
        _specifiers = specs;
    }
    
    return _specifiers;
}

- (NSString *)appNameForBundleID:(NSString *)bundleID {
    // Try to get app display name, fallback to bundle ID
    if ([bundleID isEqualToString:@"com.apple.Passbook"]) return @"Apple Wallet";
    if ([bundleID isEqualToString:@"com.paypal.PPClient"]) return @"PayPal";
    if ([bundleID isEqualToString:@"com.venmo.TouchFree"]) return @"Venmo";
    if ([bundleID isEqualToString:@"com.chase.sig.Chase"]) return @"Chase Mobile";
    
    return bundleID;
}

- (void)removePrivacyApp:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    
    // Confirm removal
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Remove App"
                                                                  message:[NSString stringWithFormat:@"Remove %@ from privacy list?", [self appNameForBundleID:bundleID]]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    UIAlertAction *removeAction = [UIAlertAction actionWithTitle:@"Remove"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self.privacyApps removeObject:bundleID];
        [self savePrivacyApps];
        [self reloadSpecifiers];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:removeAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addPrivacyApp {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add Privacy App"
                                                                  message:@"Enter the bundle ID of the app to hide FPS indicator"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"com.example.app";
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"Add"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        NSString *bundleID = alert.textFields.firstObject.text;
        if (bundleID.length > 0 && ![self.privacyApps containsObject:bundleID]) {
            [self.privacyApps addObject:bundleID];
            [self savePrivacyApps];
            [self reloadSpecifiers];
        }
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:addAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - FPSDataExportController Implementation

@implementation FPSDataExportController

- (instancetype)init {
    if (self = [super init]) {
        self.title = @"FPS Data Export";
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        
        // Header section
        PSSpecifier *groupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"FPS Data"
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:nil
                                                                      cell:PSGroupCell
                                                                      edit:nil];
        [groupSpecifier setProperty:@"Export collected FPS data for analysis" forKey:@"footerText"];
        [specs addObject:groupSpecifier];
        
        // Data information
        NSString *logPath = [self getFPSLogPath];
        NSString *logExists = [[NSFileManager defaultManager] fileExistsAtPath:logPath] ? @"Yes" : @"No";
        NSString *logSize = [self getLogFileSize:logPath];
        
        // Info about log file
        PSSpecifier *infoSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Log File Info"
                                                                    target:self
                                                                      set:NULL
                                                                      get:NULL
                                                                   detail:nil
                                                                     cell:PSGroupCell
                                                                     edit:nil];
        [infoSpecifier setProperty:[NSString stringWithFormat:@"File exists: %@\nSize: %@", logExists, logSize] 
                            forKey:@"footerText"];
        [specs addObject:infoSpecifier];
        
        // Export options
        PSSpecifier *exportSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Export via Share Sheet"
                                                                     target:self
                                                                        set:NULL
                                                                        get:NULL
                                                                     detail:nil
                                                                       cell:PSButtonCell
                                                                       edit:nil];
        exportSpecifier->action = @selector(exportLogFile);
        [specs addObject:exportSpecifier];
        
        // Clear log
        PSSpecifier *clearSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Clear Log File"
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:nil
                                                                      cell:PSButtonCell
                                                                      edit:nil];
        clearSpecifier->action = @selector(clearLogFile);
        [specs addObject:clearSpecifier];
        
        _specifiers = specs;
    }
    
    return _specifiers;
}

- (NSString *)getFPSLogPath {
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [docsDir stringByAppendingPathComponent:@"fps_log.txt"];
}

- (NSString *)getLogFileSize:(NSString *)path {
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    
    if (error || !attributes) {
        return @"N/A";
    }
    
    NSNumber *fileSizeNumber = attributes[NSFileSize];
    double fileSize = [fileSizeNumber doubleValue];
    
    if (fileSize < 1024) {
        return [NSString stringWithFormat:@"%.0f bytes", fileSize];
    } else if (fileSize < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", fileSize / 1024.0];
    } else {
        return [NSString stringWithFormat:@"%.1f MB", fileSize / (1024.0 * 1024.0)];
    }
}

- (void)exportLogFile {
    NSString *logPath = [self getFPSLogPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Data"
                                                                      message:@"No FPS log data is available for export"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:logPath];
    
    // Create activity view controller for sharing
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    
    // For iPad, present as popover
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 
                                                                        self.view.bounds.size.height / 4, 
                                                                        0, 
                                                                        0);
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)clearLogFile {
    NSString *logPath = [self getFPSLogPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Data"
                                                                      message:@"No FPS log data exists to clear"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear Log Data"
                                                                  message:@"Are you sure you want to clear all FPS log data? This cannot be undone."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"Clear"
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction * _Nonnull action) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:logPath error:&error];
        
        if (error) {
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                               message:[NSString stringWithFormat:@"Failed to clear log: %@", error.localizedDescription]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                              style:UIAlertActionStyleDefault
                                                            handler:nil];
            [errorAlert addAction:okAction];
            
            [self presentViewController:errorAlert animated:YES completion:nil];
        } else {
            [self reloadSpecifiers];
        }
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:clearAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
