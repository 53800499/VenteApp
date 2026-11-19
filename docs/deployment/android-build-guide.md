# Guide de Compilation & Signature Android

Ce document détaille les étapes techniques pour générer un APK Android de production prêt pour la distribution commerciale.

---

## 1. Préparation du Keystore de Signature

Si le fichier de clé n'existe pas encore :
```bash
keytool -genkey -v -keystore arike-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias arike-release-key
```

Fichier `android/key.properties` :
```properties
storePassword=MonMotDePasseKeystore
keyPassword=MonMotDePasseCle
keyAlias=arike-release-key
storeFile=../keystores/arike-release.jks
```

---

## 2. Commandes de Build

```bash
# Nettoyer les caches de build
flutter clean
flutter pub get

# Générer l'APK universel de production
flutter build apk --release

# Vérifier la taille et le chemin du fichier généré :
# frontend/build/app/outputs/flutter-apk/app-release.apk
```

---

## 3. Autorisations Android Sensibles (`AndroidManifest.xml`)

Vérifier la présence des permissions matérielles requises :
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

