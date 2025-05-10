// FPSLogViewer.m
#import "FPSLogViewer.h"
#import "FPSPUBGUIIntegration.h"

@implementation FPSLogViewer

#pragma mark - Log File Management

+ (NSString *)logDirectoryPath {
    // Re-use the path logic from FPSPUBGUIIntegration
    return [[FPSPUBGUIIntegration sharedInstance] logDirectoryPath];
}

+ (NSArray<NSString *> *)allLogFilePaths {
    // Re-use the logic from FPSPUBGUIIntegration
    return [[FPSPUBGUIIntegration sharedInstance] allLogFilePaths];
}

#pragma mark - File Viewing & Sharing

+ (void)openLogFile:(NSString *)logFilePath fromViewController:(UIViewController *)viewController {
    if (!logFilePath || !viewController) return;
    
    NSURL *fileURL = [NSURL fileURLWithPath:logFilePath];
    
    // Create a document interaction controller
    UIDocumentInteractionController *docController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    
    // Configure the document interaction controller
    docController.delegate = (id<UIDocumentInteractionControllerDelegate>)viewController;
    
    // Present the options menu
    [docController presentOptionsMenuFromRect:viewController.view.bounds inView:viewController.view animated:YES];
}

+ (void)showLogFileListFromViewController:(UIViewController *)viewController {
    if (!viewController) return;
    
    // Get all log files
    NSArray *logFiles = [self allLogFilePaths];
    
    if (logFiles.count == 0) {
        // Show an alert if no logs are found
        UIAlertController *alert = [UIAlertController 
                                   alertControllerWithTitle:@"No Log Files" 
                                   message:@"No FPS log files have been created yet. Use the Log File mode in PUBG Mobile to create log files." 
                                   preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [viewController presentViewController:alert animated:YES completion:nil];
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
        UIAlertAction *action = [UIAlertAction 
                                actionWithTitle:actionTitle 
                                style:UIAlertActionStyleDefault 
                                handler:^(UIAlertAction * _Nonnull action) {
            [self openLogFile:logPath fromViewController:viewController];
        }];
        
        [fileList addAction:action];
    }
    
    // Add a cancel action
    [fileList addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    // Present the alert
    [viewController presentViewController:fileList animated:YES completion:nil];
}

+ (void)shareLogFile:(NSString *)logFilePath fromViewController:(UIViewController *)viewController sourceView:(UIView *)sourceView {
    if (!logFilePath || !viewController) return;
    
    NSURL *fileURL = [NSURL fileURLWithPath:logFilePath];
    
    // Create an activity view controller
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    
    // Configure for iPad
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad && sourceView) {
        activityVC.popoverPresentationController.sourceView = sourceView;
        activityVC.popoverPresentationController.sourceRect = sourceView.bounds;
    }
    
    // Present the activity view controller
    [viewController presentViewController:activityVC animated:YES completion:nil];
}

+ (void)openSystemDocumentViewer:(NSString *)logFilePath {
    if (!logFilePath) return;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:logFilePath]) {
        NSLog(@"FPSIndicator: Log file does not exist: %@", logFilePath);
        return;
    }
    
    // Use a runtime declaration of the function from Tweak.xm
    // We can't directly call it, but we can use the same notification approach
    NSString *encodedPath = [logFilePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    // Store the path for our notification handler to use
    [[NSUserDefaults standardUserDefaults] setObject:encodedPath forKey:@"com.fpsindicator.lastLogPath"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Post a Darwin notification that our hook will catch
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.fpsindicator/openLogFile"),
        NULL,
        NULL,
        YES
    );
}

@end
