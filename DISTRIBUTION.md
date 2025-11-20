# Distribution Guide for Photon Browser

## Code Signing for Distribution

### Current Status

Photon is currently signed with **Apple Development** certificate, which is suitable for:
- ✅ Development and testing
- ✅ Personal use
- ❌ Public distribution (Gatekeeper will reject)

### For Public Distribution

To distribute Photon outside the App Store, you need a **Developer ID Application** certificate.

## Getting a Developer ID Certificate

### Step 1: Access Apple Developer Account

1. Go to [Apple Developer](https://developer.apple.com/account)
2. Sign in with your Apple ID
3. Navigate to **Certificates, Identifiers & Profiles**

### Step 2: Create Developer ID Certificate

1. Click **Certificates** → **+** (Create)
2. Select **Developer ID Application** (under "Services")
3. Click **Continue**
4. Upload a Certificate Signing Request (CSR):
   ```bash
   # Generate CSR
   openssl req -new -newkey rsa:2048 -nodes -keyout Photon.key -out Photon.csr
   ```
   Or use Keychain Access:
   - Open **Keychain Access**
   - Go to **Certificate Assistant** → **Request a Certificate From a Certificate Authority**
   - Enter your email and name
   - Save to disk

5. Upload the CSR file
6. Download the certificate
7. Double-click to install in Keychain

### Step 3: Sign with Developer ID

Once installed, the signing script will auto-detect it:

```bash
./sign.sh
```

The script will automatically use Developer ID if available.

## Notarization (Optional but Recommended)

For best user experience, notarize your app:

```bash
# Create a zip for notarization
ditto -c -k --keepParent Photon.app Photon.zip

# Submit for notarization (requires App Store Connect API key)
xcrun notarytool submit Photon.zip \
  --apple-id your@email.com \
  --team-id YOUR_TEAM_ID \
  --password app-specific-password \
  --wait
```

## Current Workaround

If you don't have Developer ID yet, users can bypass Gatekeeper:

1. Right-click the app → **Open**
2. Or use: `xattr -cr Photon.app` then open normally

## Resources

- [Apple Developer Certificates](https://developer.apple.com/support/certificates/)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

