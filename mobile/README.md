# Nova Bladers — Companion App

Begleit-App mit **Special-Move-Vorschau**, Bey-Katalog und Steuerung.

## Handy (empfohlen)

1. **[Expo Go](https://expo.dev/go)** aus dem App Store / Play Store installieren
2. Terminal:

```bash
cd mobile
npm install
npm start
```

3. QR-Code mit Expo Go scannen
4. Tab **„Vorschau“** → Modus **„Video“** — Special Moves als MP4 (Ablauf wie im Spiel)

## Laptop

**Option A — Browser-Videos (kein Node nötig):**

`preview/index.html` im Browser öffnen → Tab **„Videos"**

**Option B — Expo Web:**

```bash
cd mobile
npm install
npm run web
```

Tab **„Vorschau“** in der App.

## Features

| Tab | Inhalt |
|-----|--------|
| Start | Spielübersicht |
| **Vorschau** | Special-Move-Videos + Live-Animation |
| Beys | Katalog + Stats |
| Steuerung | Tasten + Mobile-Controls |

## Plattformen

| Befehl | Plattform |
|--------|-----------|
| `npm start` | Handy via Expo Go (QR-Code) |
| `npm run web` | Laptop-Browser |
| `npm run android` | Android Emulator |
| `npm run ios` | iOS Simulator (macOS) |
