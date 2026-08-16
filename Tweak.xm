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

    BarcodeSafariLog([NSString stringWithFormat:@"loaded process=%@ bundle=%@", processName, bundleID]);
    BarcodeSafariLog([NSString stringWithFormat:@"class CCUIQRCodeScannerViewController=%@ selector qrCodeScanner:didDecodeString:=%@",
                                               scannerClass == Nil ? @"NO" : @"YES",
                                               selectorExists ? @"YES" : @"NO"]);

    int classCount = objc_getClassList(NULL, 0);
    Class *classes = classCount > 0 ? (__unsafe_unretained Class *)calloc((size_t)classCount, sizeof(Class)) : NULL;
    if (classes != NULL) {
        objc_getClassList(classes, classCount);
        for (int index = 0; index < classCount; index++) {
            const char *name = class_getName(classes[index]);
            if (name != NULL && (strstr(name, "QRCode") != NULL || strstr(name, "Barcode") != NULL || strstr(name, "Scanner") != NULL)) {
                BarcodeSafariLog([NSString stringWithFormat:@"scanner-related class=%s", name]);
            }
        }
        free(classes);
    }
}

static BOOL BarcodeSafariIsWebURL(NSString *value)
{
    NSURL *url = [NSURL URLWithString:value];
    NSString *scheme = url.scheme.lowercaseString;
    return url != nil &&
           ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]);
}

static void BarcodeSafariOpenURL(NSString *value)
{
    if (!BarcodeSafariIsWebURL(value)) {
        return;
    }

    NSURL *url = [NSURL URLWithString:value];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *application = UIApplication.sharedApplication;
        [application openURL:url options:@{} completionHandler:nil];
    });
}

%hook CCUIQRCodeScannerViewController

- (void)qrCodeScanner:(id)scanner didDecodeString:(NSString *)value
{
    BarcodeSafariLog([NSString stringWithFormat:@"hook fired value=%@", value ?: @"<nil>"]);
    BarcodeSafariOpenURL(value);
}

%end

%ctor
{
    BarcodeSafariLogRuntimeState();
}
