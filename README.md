# BarcodeSafari

RootHide-only iOS 15 tweak for Control Center Scanner. Web QR codes are passed to the system URL opener so Safari handles redirects and subsequent navigation.

## Build

This project uses the RootHide Theos package scheme only:

```sh
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

The package is emitted under `packages/` with Debian architecture `iphoneos-arm64e`. The tweak binary is built for `arm64` and `arm64e` according to Theos' normal RootHide configuration.

Injected process: `ControlCenter`.

Hooked class and selector: `CCUIQRCodeScannerViewController` and `-qrCodeScanner:didDecodeString:`.
