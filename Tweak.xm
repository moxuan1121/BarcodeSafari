#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <fcntl.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>

static void BarcodeSafariWriteEarlyLoad(void)
{
    const char *paths[] = {
        "/tmp/BarcodeSafari-early.log",
        "/var/mobile/Documents/BarcodeSafari-Debug.log"
    };
    const char *line = "[LOAD] C constructor executed\n";
    for (size_t index = 0; index < sizeof(paths) / sizeof(paths[0]); index++) {
        int descriptor = open(paths[index], O_WRONLY | O_CREAT | O_APPEND, 0644);
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

static NSString *const BarcodeSafariDebugPath = @"/var/mobile/Documents/BarcodeSafari-Debug.log";

static void BarcodeSafariLog(NSString *tag, NSString *message)
{
    NSString *timestamp = [[NSDate date] descriptionWithLocale:nil];
    NSString *line = [NSString stringWithFormat:@"%@ [%@] %@\n", timestamp, tag, message ?: @"<nil>"];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSString *directory = [BarcodeSafariDebugPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:BarcodeSafariDebugPath];
    if (handle == nil) {
        [[NSFileManager defaultManager] createFileAtPath:BarcodeSafariDebugPath contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:BarcodeSafariDebugPath];
    }
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
    NSLog(@"[BarcodeSafari] %@", line);
}

static BOOL BarcodeSafariContainsKeyword(NSString *value, NSArray<NSString *> *keywords)
{
    for (NSString *keyword in keywords) {
        if ([value rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static void BarcodeSafariProbeRuntimeDetails(void);

static void BarcodeSafariLogMethods(Class candidateClass, NSArray<NSString *> *methodKeywords)
{
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (Class currentClass = candidateClass; currentClass != Nil; currentClass = class_getSuperclass(currentClass)) {
        NSString *className = NSStringFromClass(currentClass);
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(currentClass, &methodCount);
        NSUInteger loggedMethodCount = 0;
        for (unsigned int index = 0; index < methodCount && loggedMethodCount < 40; index++) {
            SEL selector = method_getName(methods[index]);
            NSString *selectorName = NSStringFromSelector(selector);
            if ([seen containsObject:selectorName] || !BarcodeSafariContainsKeyword(selectorName, methodKeywords)) {
                continue;
            }
            [seen addObject:selectorName];
            const char *encoding = method_getTypeEncoding(methods[index]);
            BarcodeSafariLog(@"METHOD", [NSString stringWithFormat:@"%@ -> %@ encoding=%s",
                                                       className,
                                                       selectorName,
                                                       encoding ?: "<nil>"]);
            loggedMethodCount++;
        }
        free(methods);
    }
}

static void BarcodeSafariProbeRuntime(void)
{
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    NSString *processName = processInfo.processName ?: @"<nil>";
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"<nil>";
    NSString *executablePath = NSBundle.mainBundle.executablePath ?: @"<nil>";
    BarcodeSafariLog(@"LOAD", [NSString stringWithFormat:@"tweak loaded processName=%@ bundleIdentifier=%@ pid=%d executablePath=%@",
                                                     processName,
                                                     bundleID,
                                                     processInfo.processIdentifier,
                                                     executablePath]);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BarcodeSafariLog(@"LOAD", @"starting delayed runtime enumeration");
        BarcodeSafariProbeRuntimeDetails();
    });
}

static void BarcodeSafariProbeRuntimeDetails(void)
{
    Class legacyClass = NSClassFromString(@"CCUIQRCodeScannerViewController");
    SEL legacySelector = sel_registerName("qrCodeScanner:didDecodeString:");
    BOOL legacySelectorExists = legacyClass != Nil && [legacyClass instancesRespondToSelector:legacySelector];

    BarcodeSafariLog(@"CLASS", [NSString stringWithFormat:@"CCUIQRCodeScannerViewController = %@",
                                                      legacyClass == Nil ? @"NO" : @"YES"]);
    BarcodeSafariLog(@"METHOD", [NSString stringWithFormat:@"qrCodeScanner:didDecodeString: = %@",
                                                       legacySelectorExists ? @"YES" : @"NO"]);

    NSArray<NSString *> *classKeywords = @[@"Barcode", @"QRCode", @"QR", @"Scanner", @"CodeScanner", @"Payload", @"Result", @"Preview", @"Web"];
    NSArray<NSString *> *methodKeywords = @[@"scan", @"code", @"decode", @"result", @"payload", @"URL", @"url", @"open", @"preview", @"web", @"request", @"present"];
    int classCount = objc_getClassList(NULL, 0);
    Class *classes = classCount > 0 ? (__unsafe_unretained Class *)calloc((size_t)classCount, sizeof(Class)) : NULL;
    if (classes == NULL) {
        BarcodeSafariLog(@"CLASS", @"objc_getClassList returned no classes");
        return;
    }

    objc_getClassList(classes, classCount);
    NSUInteger loggedClassCount = 0;
    for (int index = 0; index < classCount && loggedClassCount < 100; index++) {
        NSString *className = NSStringFromClass(classes[index]);
        if (!BarcodeSafariContainsKeyword(className, classKeywords)) {
            continue;
        }
        BarcodeSafariLog(@"CLASS", className);
        BarcodeSafariLogMethods(classes[index], methodKeywords);
        loggedClassCount++;
    }
    free(classes);
}

%ctor
{
    BarcodeSafariProbeRuntime();
}
