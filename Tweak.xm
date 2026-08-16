#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <fcntl.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>

static const char *const BarcodeSafariEarlyPaths[] = {
    "/tmp/BarcodeSafari-early.log",
    "/var/tmp/BarcodeSafari-early.log",
    "/var/jb/tmp/BarcodeSafari-early.log",
    "/var/mobile/Documents/BarcodeSafari-Debug.log",
    "/var/jb/var/mobile/Documents/BarcodeSafari-Debug.log"
};

static void BarcodeSafariWriteEarlyLoad(void)
{
    char executablePath[1024] = {0};
    uint32_t pathSize = sizeof(executablePath);
    int pathStatus = _NSGetExecutablePath(executablePath, &pathSize);
    const char *resolvedPath = pathStatus == 0 ? executablePath : "<unresolved>";
    char line[1400] = {0};
    snprintf(line,
             sizeof(line),
             "[LOAD] C constructor executed pid=%d executable=%s\n",
             getpid(),
             resolvedPath);
    for (size_t index = 0; index < sizeof(BarcodeSafariEarlyPaths) / sizeof(BarcodeSafariEarlyPaths[0]); index++) {
        int descriptor = open(BarcodeSafariEarlyPaths[index], O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (descriptor >= 0) {
            write(descriptor, line, strlen(line));
            close(descriptor);
        }
    }
}

__attribute__((constructor))
static void BarcodeSafariEarlyConstructor(void)
{
    BarcodeSafariWriteEarlyLoad();
}

static NSString *const BarcodeSafariDebugPaths[] = {
    @"/var/mobile/Documents/BarcodeSafari-Debug.log",
    @"/var/jb/var/mobile/Documents/BarcodeSafari-Debug.log",
    @"/var/jb/tmp/BarcodeSafari-Debug.log"
};

static NSString *const BarcodeSafariProcessProbePath = @"/var/jb/tmp/BarcodeSafari-ProcessProbe.log";

static void BarcodeSafariLog(NSString *tag, NSString *message)
{
    NSString *timestamp = [[NSDate date] descriptionWithLocale:nil];
    NSString *line = [NSString stringWithFormat:@"%@ [%@] %@\n", timestamp, tag, message ?: @"<nil>"];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    for (size_t index = 0; index < sizeof(BarcodeSafariDebugPaths) / sizeof(BarcodeSafariDebugPaths[0]); index++) {
        NSString *debugPath = BarcodeSafariDebugPaths[index];
        NSString *directory = [debugPath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:nil];
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:debugPath];
        if (handle == nil) {
            [[NSFileManager defaultManager] createFileAtPath:debugPath contents:nil attributes:nil];
            handle = [NSFileHandle fileHandleForWritingAtPath:debugPath];
        }
        if (handle != nil) {
            [handle seekToEndOfFile];
            [handle writeData:data];
            [handle closeFile];
        }
    }
    NSLog(@"[BarcodeSafari] %@", line);
}

static BOOL BarcodeSafariContainsKeyword(NSString *value, NSArray<NSString *> *keywords)
{
    if (value == nil) {
        return NO;
    }
    for (NSString *keyword in keywords) {
        if ([value rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static void BarcodeSafariAppendProcessProbe(NSString *line)
{
    NSString *directory = [BarcodeSafariProcessProbePath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:BarcodeSafariProcessProbePath];
    if (handle == nil) {
        [[NSFileManager defaultManager] createFileAtPath:BarcodeSafariProcessProbePath contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:BarcodeSafariProcessProbePath];
    }
    if (handle != nil) {
        [handle seekToEndOfFile];
        NSData *data = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        [handle writeData:data];
        [handle closeFile];
    }
}

static void BarcodeSafariProbeRuntime(void)
{
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    NSString *processName = processInfo.processName ?: @"<nil>";
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"<nil>";
    NSString *executablePath = NSBundle.mainBundle.executablePath ?: @"<nil>";
    BarcodeSafariLog(@"LOAD", [NSString stringWithFormat:@"probe processName=%@ bundleIdentifier=%@ pid=%d executablePath=%@",
                                                     processName,
                                                     bundleID,
                                                     processInfo.processIdentifier,
                                                     executablePath]);

    NSArray<NSString *> *interestingKeywords = @[@"SpringBoard", @"ControlCenter", @"Barcode", @"Scanner", @"CodeScanner", @"Camera", @"QR"];
    BOOL interesting = BarcodeSafariContainsKeyword(processName, interestingKeywords) ||
                       BarcodeSafariContainsKeyword(bundleID, interestingKeywords) ||
                       BarcodeSafariContainsKeyword(executablePath, interestingKeywords);
    if (interesting) {
        NSString *line = [NSString stringWithFormat:@"%@ pid=%d process=%@ bundle=%@ executable=%@",
                          [[NSDate date] descriptionWithLocale:nil],
                          processInfo.processIdentifier,
                          processName,
                          bundleID,
                          executablePath];
        BarcodeSafariAppendProcessProbe(line);
    }

    NSArray<NSString *> *legacyClasses = @[
        @"CCUIQRCodeScannerViewController",
        @"CSMainViewController",
        @"BCSActionManager",
        @"SFCameraScannerViewController"
    ];
    for (NSString *name in legacyClasses) {
        Class cls = NSClassFromString(name);
        if (cls != Nil) {
            BarcodeSafariLog(@"CLASS", [NSString stringWithFormat:@"%@ = YES", name]);
        }
    }
}

%ctor
{
    BarcodeSafariProbeRuntime();
}
