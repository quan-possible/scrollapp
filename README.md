# Scrollapp

[![GitHub Downloads](https://img.shields.io/github/downloads/fromis-9/scrollapp/total.svg)](https://github.com/fromis-9/scrollapp/releases)

A macOS utility that brings Windows-style auto-scrolling to macOS. Middle-click anywhere to enable auto-scroll mode, then move your cursor to control scrolling speed and direction.

<img src="img/scrollappicon.png" width="100" alt="Scrollapp Icon">

## Project Map

Use these folder guides when you need a fast entry point into the codebase:
- [`Scrollapp/README.md`](Scrollapp/README.md) for the production app architecture and runtime boundaries
- [`ScrollappTests/README.md`](ScrollappTests/README.md) for focused core-logic regression coverage
- [`scripts/README.md`](scripts/README.md) for build, packaging, and local Xcode helper scripts

## Features

- **Middle-click autoscroll**: Activate on middle-click release, then move the cursor to control scrolling speed and direction
- **Adjustable Sensitivity**: Slider control from 0.2x to 3.0x speed with exponential low-speed scaling
- **Smooth near-center control**: Small pointer movement ramps in gradually so autoscroll stays controllable near the anchor
- **Better same-window continuity**: Scrolling stays active anywhere inside the same window instead of dropping out when the pointer crosses into another panel or nested element
- **Customizable Direction**: Option to invert scrolling direction based on preference
- **Launch at Login**: Optional automatic startup
- **Menu Bar Integration**: Quick access via status menu in the menu bar

## Installation

1. **Download**: Download the latest release from the [Releases](https://github.com/fromis-9/scrollapp/releases) page.
2. **Install**: Open the DMG file and drag Scrollapp to your Applications folder.
3. **Security Override**: Since the app is distributed without Apple notarization, you'll need to manually allow it:
   - **Method 1**: Right-click on Scrollapp.app → "Open" → "Open" in the dialog
   - **Method 2**: If you see "can't be opened" error, go to System Settings → Privacy & Security → scroll down to find "Scrollapp was blocked" → click "Open Anyway"
4. **Grant Permissions**:
   - When prompted, grant Accessibility and Input Monitoring permissions.
   - If you miss a prompt, you can grant permissions manually in System Settings:
     - Go to `System Settings > Privacy & Security > Accessibility` and add Scrollapp.
     - Go to `System Settings > Privacy & Security > Input Monitoring` and enable Scrollapp.
   - You may need to restart the app after granting permissions.

## How to Use

### Activating Auto-scroll

**With Mouse:**
- Middle-click once over plain scrollable content
- The button press arms autoscroll, and releasing that same click latches it on
- Click again with the middle button to stop, or click another mouse button to exit

Middle click toggles on click release: pressing the button arms autoscroll, and releasing the same click latches it on without reintroducing a separate hold mode.
Regular wheel events do not cancel an already active autoscroll session.

### Controlling Scrolling

Once auto-scroll is activated:
- Move cursor **up** to scroll **up**
- Move cursor **down** to scroll **down**
- Move further from the center point for faster scrolling
- Speed ramps up gradually as the pointer moves farther from the anchor
- Move closer to the center point for slower, more precise scrolling

### Customization

**Scroll Speed:**
- Use the sensitivity slider in the menu (0.2x - 3.0x)
- Speeds below 1.0x use exponential scaling for fine control
- Real-time adjustment with immediate feedback

### Menu Options

Access additional options from the menu bar icon:
- **Scroll Speed** - Sensitivity slider (0.2x - 3.0x)
- **Invert Scrolling Direction** - Reverse up/down behavior
- **Launch at Login** - Automatic startup option
- **Runtime Diagnostics** - Permission and delivery status for debugging
- **About Scrollapp** - App information and usage tips

## System Requirements

- macOS 14.0 or later
- Mouse with a middle button
- Compatible with both Intel and Apple Silicon Macs

## Privacy & Security

- **Permissions**: Scrollapp needs Accessibility and Input Monitoring permission, and it checks whether macOS will allow synthetic scroll-event posting for delivery. It does not collect or transmit personal data.
- **Code Signing**: The app is ad-hoc signed for free distribution. While this triggers macOS security warnings, the source code is fully open and auditable on GitHub.

## License

[GNU General Public License v3.0](LICENSE)

## Building from Source

To build Scrollapp from source:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/scrollapp.git
   cd scrollapp
   ```

2. **Ensure the Xcode project exists:**
   The repository now includes `Scrollapp.xcodeproj` directly. If you ever need to regenerate it from the checked-in spec, install `xcodegen` and run:
   ```bash
   xcodegen generate --spec project.yml
   ```

3. **Open in Xcode:**
   ```bash
   open Scrollapp.xcodeproj
   ```

   If the repository lives under Google Drive / `Library/CloudStorage` and Xcode freezes while opening the project, use the local wrapper launcher instead:
   ```bash
   SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode ./scripts/open_local_xcode.sh --check --no-open
   ```
   Then launch Xcode manually and open `/private/tmp/scrollapp-xcode/Scrollapp.xcodeproj` from `File > Open...`.

   This creates a local Xcode project wrapper outside the cloud-backed path while keeping the real source files in the original repository via symlinks. If `xcodegen` is installed, it will regenerate the local wrapper project from the checked-in `project.yml`; otherwise it uses the checked-in `Scrollapp.xcodeproj`. You can choose a different local wrapper location by setting `SCROLLAPP_XCODE_LOCAL_DIR`.
   
   Code edits made from that local wrapper go straight back to the real repo. For project structure changes, edit `project.yml` in the real repository and rerun the wrapper script. If the script tries to auto-open Xcode and that step fails on your machine, it will print a manual fallback that points you at the generated local project path.

4. **Build or test from the command line if preferred:**
   ```bash
   xcodebuild -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
   xcodebuild -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
   ./scripts/verify_launch_smoke.sh
   ./scripts/verify_autoscroll_delivery.sh
   ```
   This is the simplest supported local path if you do not share the checked-in signing setup.

5. **Build the app in Xcode:**

   **Option A: With Apple Developer Program Account**
   - In Xcode, select **Product** → **Archive**
   - Click **Distribute App** → **Copy App**
   - Choose a location to export the built app

   **Option B: Local Xcode build with your own signing setup**
   - The checked-in project uses automatic signing with a specific development team and entitlements
   - If that team is not available in your Xcode account, switch signing to your own team before using the GUI build/archive flow
   - If you only need a local build or test run, prefer the command-line path above with signing disabled

The project is configured to build universal binaries that work on both Intel and Apple Silicon Macs.

## Feedback and Contributions

Feedback and contributions are welcome! Please feel free to submit issues or pull requests.
