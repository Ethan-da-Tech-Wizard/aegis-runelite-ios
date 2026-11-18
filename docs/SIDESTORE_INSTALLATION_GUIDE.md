# SideStore Installation & Zero-Cost ($0) Distribution Guide

**Client:** RuneLite Mobile (1:1 Standalone iOS Client)  
**Cost:** **$0.00** (Zero Apple Developer Program fee required)  
**Expiration Risk:** **None** (On-device automatic background re-signing via WireGuard loopback)  
**Compatibility:** iOS 15.0 through iOS 18.x (iPhone & iPad)

---

## Why SideStore?

Traditional iOS sideloading using free Apple IDs (like standard AltStore) has a severe drawback: **apps expire every 7 days**, requiring you to connect your iPhone with a USB cable to a running computer every single week.

**SideStore completely solves this:**
- It runs a local **WireGuard VPN loopback (`127.0.0.1`)** entirely inside your iPhone.
- This tricks iOS into believing your iPhone is its own host computer communicating with `mobile_installation_proxy`.
- **Result:** RuneLite Mobile re-signs itself automatically in the background over Wi-Fi or cellular data. After the initial 5-minute install, **you never need to plug your iPhone into a computer again.**

---

## Step 1: Initial One-Time Setup (5–10 Minutes)

> *You only need a computer (Mac, Windows, or Linux) for this initial installation step.*

1. **Download SideServer:**
   - Go to [sidestore.io](https://sidestore.io) on your computer.
   - Download the SideServer utility for your computer operating system.
2. **Connect iPhone via Cable:**
   - Plug your iPhone into your computer.
   - Tap **Trust This Computer** on your iPhone screen if prompted.
3. **Install SideStore to your iPhone:**
   - Open SideServer on your computer.
   - Select **Install SideStore** and choose your connected iPhone.
   - Enter your personal Apple ID (or create a dedicated free throwaway Apple ID).
4. **Enable Developer Mode (iOS 16+ only):**
   - On your iPhone, open **Settings → Privacy & Security → Developer Mode**.
   - Toggle **Developer Mode ON** and restart your iPhone when prompted.
5. **Trust the Certificate:**
   - Open **Settings → General → VPN & Device Management**.
   - Tap your Apple ID under Developer App and tap **Trust**.

---

## Step 2: Install WireGuard Loopback on iPhone

1. On your iPhone, open the **App Store** and download the free **WireGuard** app.
2. In the SideStore app on your iPhone, go to **Settings → WireGuard Configuration** and export/save `SideStore.conf`.
3. Open the **WireGuard** app on your iPhone, tap **Add a Tunnel**, and import `SideStore.conf`.
4. Toggle the **SideStore WireGuard tunnel ON**.  
   *(This creates the `127.0.0.1` local loopback so SideStore can sign apps on-device).*

---

## Step 3: Install RuneLite Mobile (`.ipa`)

1. Transfer `RuneLiteMobile_SideStore.ipa` to your iPhone:
   - **Mac:** AirDrop `RuneLiteMobile_SideStore.ipa` directly to your iPhone.
   - **Windows / Linux:** Save `RuneLiteMobile_SideStore.ipa` to iCloud Drive, Google Drive, or send it to yourself via Discord/Telegram/Email, then save it to the iOS **Files** app.
2. Open the **SideStore** app on your iPhone.
3. Tap the **My Apps** tab, then tap the **+** (plus) icon in the top-left corner.
4. Select `RuneLiteMobile_SideStore.ipa` from the Files browser.
5. SideStore will sign and install RuneLite Mobile directly onto your iPhone home screen!

---

## Step 4: Open & Enjoy RuneLite Mobile

1. Tap **RuneLite** on your home screen.
2. **1:1 Touch Controls:**
   - **Single tap (<200ms):** Direct action (Yellow X for ground movement, Red X for interactables).
   - **Long press (350ms hold):** Triggers gentle Taptic Engine haptic vibration and opens the OSRS context menu.
   - **Two-finger drag:** Smooth camera orbit (yaw and pitch).
   - **Pinch gesture:** Smooth zoom.
   - **Compass tap:** Instantly resets camera facing North.
3. **Official Plugin Hub:**
   - Tap the **Gear icon** in the top left corner to open the Settings panel.
   - Tap **Official Plugin Hub** to browse, search, and install community plugins (Loot Tracker, Quest Helper Mobile, Timers & Buffs, Banked XP, Farming Tracker).
   - All plugins run in a secure, sandboxed JavaScriptCore runtime with zero risk to your account.
4. **Jagex Account Sign-In:**
   - Under Settings, tap **Sign In with Jagex** to authenticate via the official Jagex Account OAuth2 PKCE portal.
   - The app never sees your password or 2FA codes.

---

## How Background Auto-Renewal Works

SideStore schedules a background task with iOS. As long as the WireGuard loopback is active or toggled when on Wi-Fi, SideStore connects to Apple's developer provisioning servers and renews the 7-day certificate automatically in the background.

To manually refresh at any time:
- Open SideStore, ensure WireGuard is connected, and tap **Refresh All**.

---
*Created by TWU LLC for authentic, safe, and free mobile OSRS gameplay.*
