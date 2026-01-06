# iOS Background Call Notifications Setup

To enable background call notifications on iOS, you need to configure background modes in Xcode. Follow these steps:

## Steps to Configure

### 1. Open Xcode Project
```bash
cd ios
open Runner.xcworkspace
```

### 2. Enable Background Modes
1. In Xcode, select the **Runner** target in the project navigator
2. Go to the **Signing & Capabilities** tab
3. Click the **+ Capability** button
4. Add **Background Modes**
5. Enable the following checkboxes:
   - ☑️ **Audio, AirPlay, and Picture in Picture**
   - ☑️ **Voice over IP**

### 3. Add Push Notifications Capability
1. Still in the **Signing & Capabilities** tab
2. Click the **+ Capability** button again
3. Add **Push Notifications**

### 4. Update Info.plist (if needed)
The following permissions should already be in your `Info.plist`, but verify they exist:

```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera for video calls</string>

<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for voice and video calls</string>
```

### 5. Build and Test
After making these changes:
1. Clean the build folder: **Product → Clean Build Folder** (Cmd+Shift+K)
2. Build and run the app on a physical device (background modes don't work well in simulator)

## Verification

To verify background call notifications are working:

1. **Background Test**: 
   - Put the app in the background (press home button)
   - Make a call from another device
   - You should receive a notification and be able to answer

2. **Killed App Test**:
   - Force quit the app (swipe up from app switcher)
   - Make a call from another device
   - You should still receive a notification (requires VoIP push notifications setup)

## Notes

- **VoIP Push Notifications**: For receiving calls when the app is completely killed, you'll need to implement VoIP push notifications using Apple Push Notification service (APNs). This is a more advanced setup.
  
- **CallKit Integration**: For a native iOS calling experience, consider integrating CallKit. Zego SDK supports this.

- **Testing**: Always test on a real device, as background modes have limited functionality in the iOS Simulator.

## Troubleshooting

### Calls not received in background
- Verify Background Modes are enabled in Xcode
- Check that "Voice over IP" is checked
- Ensure the app has notification permissions

### Calls not received when app is killed
- This requires VoIP push notifications setup
- Check Apple Developer Console for push notification certificates
- Verify your app's bundle ID matches the one in the developer console

## Additional Resources

- [Apple Background Execution Documentation](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background)
- [Zego iOS CallKit Integration](https://docs.zegocloud.com/article/14826)
