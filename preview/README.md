# Nova Bladers — Vorschau

Interaktive Special-Move-Vorschau (ohne Roblox Studio).

## Laptop (einfachste Methode)

1. Repo klonen oder `preview/index.html` herunterladen
2. Datei doppelklicken — öffnet im Browser (Chrome, Firefox, Edge)
3. Auf eine Special-Karte klicken → Animation abspielen

Alternativ mit lokalem Server:

```bash
cd preview
python3 -m http.server 8080
```

Dann im Browser: http://localhost:8080

## Handy (Expo Go App)

1. **Expo Go** installieren:
   - [Android — Google Play](https://play.google.com/store/apps/details?id=host.exp.exponent)
   - [iOS — App Store](https://apps.apple.com/app/expo-go/id982107779)

2. Am PC im Repo:

```bash
cd mobile
npm install
npm start
```

3. QR-Code mit **Expo Go** scannen (Android) oder Kamera-App (iOS)
4. In der App Tab **„Vorschau“** öffnen → Special antippen

## Laptop (Expo Web)

```bash
cd mobile
npm install
npm run web
```

Browser öffnet sich automatisch → Tab **„Vorschau“**.
