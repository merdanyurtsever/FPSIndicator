#import "FPSIndicatorRootListController.h"
#import "BDInfoListController.h"
#import <Preferences/PSSpecifier.h>

@implementation FPSIndicatorRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        
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
    
    // Remove saved position
    [settings removeObjectForKey:@"labelPosition"];
    [settings writeToFile:path atomically:YES];
    
    // Notify the tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                       CFSTR("com.fpsindicator/loadPref"), 
                                       NULL, NULL, YES);
    
    // Show confirmation with modern alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FPSIndicator"
                                                                  message:@"Position has been reset"
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

@end
