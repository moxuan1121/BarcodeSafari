#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>

static NSArray<NSString *> *BarcodeSafariLogPaths(void)
{
    return @[@"/var/mobile/BarcodeSafari-loaded.txt", @"/tmp/BarcodeSafari-loaded.txt"];
}

static void BarcodeSafariLog(NSString *message)
{
    NSString *line = [message stringByAppendingString:@"\n"];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    for (NSString *path in BarcodeSafariLogPaths()) {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (handle == nil) {
            [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
            handle = [NSFileHandle fileHandleForWritingAtPath:path];
        }
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    }
    NSLog(@"[BarcodeSafari] %@", message);
}

static BOOL BarcodeSafariStringContainsKeyword(NSString *value, NSArray<NSString *> *keywords)
{
    for (NSString *keyword in keywords) {
        if ([value rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static void BarcodeSafariLogMethodsForClass(Class class, NSArray<NSString *> *methodKeywords)
{
    NSMutableSet<NSString *> *loggedSelectors = [NSMutableSet set];
    for (Class currentClass = class; currentClass != Nil; currentClass = class_getSuperclass(currentClass)) {
        NSString *className = NSStringFromClass(currentClass);
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(currentClass, &methodCount);
        for (unsigned int methodIndex = 0; methodIndex < methodCount; methodIndex++) {
            SEL selector = method_getName(methods[methodIndex]);
            NSString *selectorName = NSStringFromSelector(selector);
            if (![loggedSelectors containsObject:selectorName] &&
                BarcodeSafariStringContainsKeyword(selectorName, methodKeywords)) {
                const char *encoding = method_getTypeEncoding(methods[methodIndex]);
                BarcodeSafariLog([NSString stringWithFormat:@"candidate method -[%@ %@] encoding=%s",
                                                           className,
                                                           selectorName,
                                                           encoding ?: "<nil>"]);
                [loggedSelectors addObject:selectorName];
            }
        }
        free(methods);
    }
}

static void BarcodeSafariLogRuntimeState(void)
{
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *bundleID = bundle.bundleIdentifier ?: @"<nil>";
    NSString *processName = NSProcessInfo.processInfo.processName ?: @"<nil>";
    Class scannerClass = NSClassFromString(@"CCUIQRCodeScannerViewController");
    SEL decodeSelector = sel_registerName("qrCodeScanner:didDecodeString:");
    BOOL selectorExists = scannerClass != Nil && [scannerClass instancesRespondToSelector:decodeSelector];

    BarcodeSafariLog([NSString stringWithFormat:@"tweak loaded process=%@ bundle=%@ pid=%d",
                                               processName,
                                               bundleID,
                                               NSProcessInfo.processInfo.processIdentifier]);
    BarcodeSafariLog([NSString stringWithFormat:@"class CCUIQRCodeScannerViewController=%@ selector qrCodeScanner:didDecodeString:=%@",
                                               scannerClass == Nil ? @"NO" : @"YES",
                                               selectorExists ? @"YES" : @"NO"]);
    if (scannerClass != Nil) {
        Method decodeMethod = class_getInstanceMethod(scannerClass, decodeSelector);
        BarcodeSafariLog([NSString stringWithFormat:@"current selector encoding=%s",
                                                   decodeMethod == NULL ? "<missing>" : method_getTypeEncoding(decodeMethod)]);
    }

    NSArray<NSString *> *classKeywords = @[@"Barcode", @"QRCode", @"Scanner", @"CodeScanner", @"AVCapture", @"Result", @"Payload", @"Preview", @"URL", @"Web"];
    NSArray<NSString *> *methodKeywords = @[@"scan", @"decode", @"result", @"payload", @"url", @"open", @"code", @"preview", @"web", @"present"];
    int classCount = objc_getClassList(NULL, 0);
    Class *classes = classCount > 0 ? (__unsafe_unretained Class *)calloc((size_t)classCount, sizeof(Class)) : NULL;
    if (classes != NULL) {
        objc_getClassList(classes, classCount);
        for (int index = 0; index < classCount; index++) {
            const char *name = class_getName(classes[index]);
            NSString *className = name == NULL ? @"" : [NSString stringWithUTF8String:name];
            if (!BarcodeSafariStringContainsKeyword(className, classKeywords)) {
                continue;
            }

            BarcodeSafariLog([NSString stringWithFormat:@"scanner-related class=%@", className]);
            BarcodeSafariLogMethodsForClass(classes[index], methodKeywords);
        }
        free(classes);
    }
}

%hook CCUIQRCodeScannerViewController

- (void)qrCodeScanner:(id)scanner didDecodeString:(NSString *)value
{
    BarcodeSafariLog([NSString stringWithFormat:@"current hook called value=%@", value ?: @"<nil>"]);
    %orig;
}

%end

%ctor
{
    BarcodeSafariLogRuntimeState();
}
