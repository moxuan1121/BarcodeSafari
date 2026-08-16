#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>

static NSString *const BarcodeSafariLogPath = @"/var/mobile/BarcodeSafari-loaded.txt";

static void BarcodeSafariLog(NSString *message)
{
    NSString *line = [message stringByAppendingString:@"\n"];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:BarcodeSafariLogPath];
    if (handle == nil) {
        [[NSFileManager defaultManager] createFileAtPath:BarcodeSafariLogPath contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:BarcodeSafariLogPath];
    }
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
    NSLog(@"[BarcodeSafari] %@", message);
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

    NSArray<NSString *> *classKeywords = @[@"Barcode", @"QRCode", @"Scanner", @"CodeScanner", @"AVCapture", @"Result", @"Payload", @"Preview"];
    NSArray<NSString *> *methodKeywords = @[@"decode", @"result", @"payload", @"url", @"open", @"scan", @"code", @"preview", @"present"];
    int classCount = objc_getClassList(NULL, 0);
    Class *classes = classCount > 0 ? (__unsafe_unretained Class *)calloc((size_t)classCount, sizeof(Class)) : NULL;
    if (classes != NULL) {
        objc_getClassList(classes, classCount);
        for (int index = 0; index < classCount; index++) {
            const char *name = class_getName(classes[index]);
            NSString *className = name == NULL ? @"" : [NSString stringWithUTF8String:name];
            BOOL classMatches = NO;
            for (NSString *keyword in classKeywords) {
                if ([className rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    classMatches = YES;
                    break;
                }
            }
            if (!classMatches) {
                continue;
            }

            BarcodeSafariLog([NSString stringWithFormat:@"scanner-related class=%@", className]);
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(classes[index], &methodCount);
            for (unsigned int methodIndex = 0; methodIndex < methodCount; methodIndex++) {
                SEL selector = method_getName(methods[methodIndex]);
                NSString *selectorName = NSStringFromSelector(selector);
                for (NSString *keyword in methodKeywords) {
                    if ([selectorName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        BarcodeSafariLog([NSString stringWithFormat:@"candidate method %@ -[%@ %@]",
                                                           className,
                                                           className,
                                                           selectorName]);
                        break;
                    }
                }
            }
            free(methods);
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
