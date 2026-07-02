# Nova Bladers — Mobile Companion App

Begleit-App für das Roblox-Spiel **Nova Bladers**. Zeigt Bey-Katalog, Special-Moves, Steuerung und Spielmodi.

## Features

- **Start** — Übersicht, Spielmodi, Arena-Stats
- **Beys** — Katalog mit Stats und Detail-Ansicht inkl. Special-Moves
- **Steuerung** — Tastatur- und Mobile-Controls

## Voraussetzungen

- [Node.js](https://nodejs.org/) 18+
- [Expo Go](https://expo.dev/go) auf dem Handy (zum Testen)

## Starten

```bash
cd mobile
npm install
npm start
```

Scanne den QR-Code mit **Expo Go** (Android) oder der Kamera-App (iOS).

## Plattformen

| Befehl | Plattform |
|--------|-----------|
| `npm start` | Dev-Server + QR-Code |
| `npm run android` | Android Emulator / Gerät |
| `npm run ios` | iOS Simulator (nur macOS) |
| `npm run web` | Browser-Vorschau |

## Build (Production)

Für App Store / Play Store:

```bash
npx eas-cli build --platform all
```

(EAS Build erfordert ein [Expo-Konto](https://expo.dev/signup).)

## Daten

Bey- und Special-Daten spiegeln `src/ReplicatedStorage/NovaBladers/` aus dem Roblox-Projekt.
