#!/usr/bin/env python3
"""Static checks; Xcode compilation is performed by GitHub Actions."""
import plistlib
from pathlib import Path
root=Path(__file__).parent
plist=plistlib.loads((root/'StreamPlayLegacy/Info.plist').read_bytes())
assert plist['CFBundleDisplayName']=='StreamPlay Legacy'
assert plist['NSAppTransportSecurity']['NSAllowsArbitraryLoads'] is True
assert 'UIApplicationSceneManifest' not in plist
assert plist['UILaunchStoryboardName'] == 'LaunchScreen'
assert (root/'StreamPlayLegacy/LaunchScreen.storyboard').exists()
main=(root/'StreamPlayLegacy/main.m').read_text()
for identifier in ['SPLChannelsController','SPLBrowserController','SPLSettingsController','AVPlayer','WKWebView','UIDocumentPickerViewController','NSRegularExpression','UIApplicationMain']:
    assert identifier in main, identifier
assert 'com.apple.developer.carplay' not in main
proj=(root/'StreamPlayLegacy.xcodeproj/project.pbxproj').read_text()
for identifier in ['IPHONEOS_DEPLOYMENT_TARGET = 12.0','com.drotavio.streamplaylegacy','main.m in Sources','UIKit.framework','WebKit.framework','AVFoundation.framework','LaunchScreen.storyboard in Resources']:
    assert identifier in proj, identifier
workflow=(root/'.github/workflows/build-ipa.yml').read_text()
assert 'runs-on: macos-15' in workflow
assert 'Xcode_16.4.app' in workflow
print('PASS: metadata, layout, architecture, build workflow')
