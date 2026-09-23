# Flutter platform configuration

Run `flutter create --platforms=android,ios,web --project-name mimi_store .` before applying these settings.

## Android

Add the following inside `android/app/src/main/AndroidManifest.xml`, immediately below the opening `<manifest>` element:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Do not enable cleartext HTTP traffic in the release manifest. Use an HTTPS API endpoint for production.

Manual payment uses the external phone dialer through a `tel:` URL. It does not request direct-call or SIM-reading permissions. The app displays phone payment instructions whenever dialing is unavailable.

Configure a unique application ID such as `rw.mimistore.app`, upload signing, Play App Signing and a release keystore outside the repository.

## iOS

Add this key to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Mimi Store uses your location only when you choose to share a delivery pin.</string>
```

Set a unique bundle identifier, Apple development team and App Store signing profile in Xcode. The minimum deployment target must satisfy the selected geolocation and secure-storage package versions.

## Secure storage

`flutter_secure_storage` stores session tokens in Android encrypted storage and iOS Keychain. Do not log tokens, copy them into preferences, or put them in URLs.

## Production API URL

Always provide the endpoint during compilation:

```bash
--dart-define=API_BASE_URL=https://api.your-domain.rw/api/v1
```

If this value is omitted, the development default is `http://localhost:8080/api/v1`.
