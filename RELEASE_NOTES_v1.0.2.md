# Photon Browser v1.0.2

## 🐛 Critical Bug Fix

### Fixed Settings Window Crash
- **Fixed**: Settings window no longer crashes when closing
- **Issue**: App was crashing with `EXC_BAD_ACCESS` in `_NSWindowTransformAnimation dealloc` when closing Settings window
- **Solution**: Changed window closing method from `window.close()` to `window.orderOut(nil)` to avoid animation conflicts
- **Impact**: Settings window can now be closed safely without crashing the application

## 🔧 Technical Details

The crash was caused by a conflict between SwiftUI's window management and AppKit's animation system. Using `orderOut(nil)` instead of `close()` or `performClose()` avoids triggering the problematic animation cleanup that was causing the segmentation fault.

## 📦 What's Included

- Complete app bundle with executable, icon, and Info.plist
- All previous features from v1.0.1
- Stable Settings window that closes without crashing

## 📥 Installation

1. Download `Photon-v1.0.2-macOS.zip` from the releases page
2. Extract the zip file
3. Move `Photon.app` to your Applications folder
4. Double-click to launch

## ✅ Testing

The Settings window can now be:
- Opened via `File → Settings` or `CMD+,`
- Closed using the X button without crashing
- Reopened multiple times without issues

---

**Download**: [Photon-v1.0.2-macOS.zip](Photon-v1.0.2-macOS.zip)

