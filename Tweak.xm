#import <UIKit/UIKit.h>

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
        if ([application respondsToSelector:@selector(openURL:options:completionHandler:)]) {
            [application openURL:url options:@{} completionHandler:nil];
        } else {
            [application openURL:url];
        }
    });
}

%hook CCUIQRCodeScannerViewController

- (void)qrCodeScanner:(id)scanner didDecodeString:(NSString *)value
{
    BarcodeSafariOpenURL(value);
}

%end
