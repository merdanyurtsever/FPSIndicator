// FPSLogViewer.h
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * FPSLogViewer - Utility for viewing FPS logs
 * 
 * This class provides methods to view and share FPS log files
 */
@interface FPSLogViewer : NSObject

/**
 * Opens a log file viewer for the specified file path
 * @param logFilePath The path to the log file to view
 * @param viewController The view controller to present from
 */
+ (void)openLogFile:(NSString *)logFilePath fromViewController:(UIViewController *)viewController;

/**
 * Shows a list of available log files and allows the user to select one
 * @param viewController The view controller to present from
 */
+ (void)showLogFileListFromViewController:(UIViewController *)viewController;

/**
 * Shares a log file using UIActivityViewController
 * @param logFilePath The path to the log file to share
 * @param viewController The view controller to present from
 * @param sourceView The source view for iPad popover presentation
 */
+ (void)shareLogFile:(NSString *)logFilePath 
   fromViewController:(UIViewController *)viewController 
           sourceView:(UIView *)sourceView;

/**
 * Opens the specified log file using the system document viewer
 * @param logFilePath The path to the log file to open
 */
+ (void)openSystemDocumentViewer:(NSString *)logFilePath;

/**
 * Returns the directory where FPS logs are stored
 * @return The full path to the log directory
 */
+ (NSString *)logDirectoryPath;

/**
 * Returns a list of all log files in the log directory
 * @return An array of file paths for all log files, sorted by modification date (newest first)
 */
+ (NSArray<NSString *> *)allLogFilePaths;

@end
