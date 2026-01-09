# Windows Installer Guide for AgentEngine

This guide explains how to create a professional Windows installer for AgentEngine using Inno Setup.

## Current Distribution Options

### 1. Standalone Executable (Available Now)
- **File**: `AgentEngine-Windows-v1.0.1.exe` (58KB)
- **Download**: https://github.com/WereNext/Asmbli/raw/main/downloads/windows/v1.0.1/AgentEngine-Windows-v1.0.1.exe
- **Pros**: Smallest download, no installation required
- **Cons**: Missing runtime DLLs, requires user to have Visual C++ Redistributables installed

### 2. Inno Setup Installer (Recommended for Distribution)
- **Status**: Script ready, requires Inno Setup to build
- **Output**: Self-contained installer with all dependencies
- **Pros**:
  - Professional installation experience
  - Includes all required DLLs (Visual C++ runtime)
  - Start menu shortcuts
  - Clean uninstallation
  - No admin rights required
- **Cons**: Larger download (~15-20MB)

## Setting Up Inno Setup Installer

### Step 1: Install Inno Setup

1. Download Inno Setup from: https://jrsoftware.org/isdl.php
2. Install the latest version (6.x recommended)
3. Make sure to install to the default location: `C:\Program Files (x86)\Inno Setup 6\`

### Step 2: Build Flutter App

```bash
cd apps/desktop
flutter build windows --release
```

This creates the release build at:
```
apps/desktop/build/windows/x64/runner/Release/
```

### Step 3: Build the Installer

#### Option A: Using Inno Setup GUI
1. Open **Inno Setup Compiler**
2. File → Open → Navigate to `apps/desktop/installer/windows/installer.iss`
3. Build → Compile (or press F9)
4. The installer will be created in: `apps/desktop/build/windows/installer/`

#### Option B: Using Command Line
```bash
cd apps/desktop
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\windows\installer.iss
```

### Step 4: Test the Installer

1. Locate the installer: `apps/desktop/build/windows/installer/AgentEngine-Windows-v1.0.1-Setup.exe`
2. Run it on a test machine
3. Verify:
   - Installation completes successfully
   - Start menu shortcut works
   - Application launches correctly
   - Uninstallation removes all files

### Step 5: Distribute

Upload the installer to:
1. **GitHub Releases**: Create a new release with the installer
2. **Website**: Add to the downloads page at `apps/web/components/DownloadSection.tsx`

## Installer Configuration

The installer script is located at: `apps/desktop/installer/windows/installer.iss`

### Key Features Configured:

- **Application Info**: Name, version, publisher, URL
- **Installation Directory**: `Program Files\AgentEngine` (user-writable location)
- **Shortcuts**: Start menu + optional desktop icon
- **File Inclusion**: All files from Release folder (includes DLLs)
- **Compression**: LZMA (best compression)
- **Architecture**: x64 only
- **Privileges**: No admin required
- **Uninstaller**: Automatic clean uninstall

### Customization

To change version or settings, edit `installer.iss`:

```pascal
#define MyAppVersion "1.0.1"  // Change version here
```

## Alternative: MSIX Package (Microsoft Store)

For Microsoft Store distribution, use the MSIX package:

```bash
cd apps/desktop
flutter pub add msix
dart run msix:create
```

However, MSIX requires:
- Code signing certificate
- Microsoft Store developer account (for Store distribution)
- Windows 10+ only

**Recommendation**: Use Inno Setup for direct distribution, MSIX only for Microsoft Store.

## Troubleshooting

### Missing DLLs Error
If users report missing DLLs (like `msvcp140.dll`), ensure the installer includes the full Release folder:
- The Inno Setup script uses `recursesubdirs` to include all files
- Flutter's Release build includes required Visual C++ runtime DLLs

### Antivirus False Positives
Some antivirus software may flag unsigned installers:
- **Solution**: Code signing certificate ($100-300/year)
- **Temporary**: Instruct users to add exception
- **Alternative**: Use Microsoft's SmartScreen submission

### Icon Issues
If the installer icon doesn't work:
- Ensure `assets/images/logo.png` exists
- Or use a `.ico` file instead and update the script:
  ```pascal
  SetupIconFile=path\to\icon.ico
  ```

## Building Complete Release Package

Complete release workflow:

```bash
# 1. Build Flutter app
cd apps/desktop
flutter build windows --release

# 2. Create standalone .exe (for minimal download)
cp build/windows/x64/runner/Release/agentengine_desktop.exe downloads/windows/v1.0.1/AgentEngine-Windows-v1.0.1.exe

# 3. Build installer (requires Inno Setup installed)
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\windows\installer.iss

# 4. Copy installer to downloads
cp build/windows/installer/AgentEngine-Windows-v1.0.1-Setup.exe downloads/windows/v1.0.1/

# 5. Create ZIP archive (fallback option)
cd build/windows/x64/runner/Release
tar -a -c -f ../../../../../downloads/windows/v1.0.1/AgentEngine-Windows-v1.0.1.zip *
```

Now you have three distribution options:
1. Standalone .exe (58KB) - requires VC++ runtime
2. Installer .exe (~15MB) - self-contained, professional
3. ZIP archive (~15MB) - manual installation

## Next Steps

1. Install Inno Setup on your build machine
2. Build the installer using the instructions above
3. Test on a clean Windows machine
4. Upload to GitHub releases and website
5. Consider code signing for production releases
