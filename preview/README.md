# Nova Bladers — Special Move Videos

Vorgefertigte **MP4-Videos** aller Special Moves — gleiche Phasen und Timings wie im Roblox-Spiel (`BeyConfig.lua`).

## Laptop — Videos ansehen

1. `preview/index.html` im Browser öffnen
2. Tab **„Videos“** — jedes Special als MP4 mit Play/Pause/Loop

Oder direkt die Dateien abspielen:

```
preview/videos/NovaMeteorShower.mp4
preview/videos/IronVaultLock.mp4
preview/videos/VoltSonicTempest.mp4
preview/videos/ShadowEclipseFang.mp4
```

## Videos neu rendern

Falls du Animationen im Code änderst:

```bash
cd preview
npm install
npm run generate-videos
```

Das Skript rendert frame-genau (30 FPS) via Headless Chrome + ffmpeg nach `preview/videos/`.

## Phasen pro Special

| Special | Phasen | Dauer |
|---------|--------|-------|
| Nova Meteor Shower | Windup → Rush → Meteor Barrage | ~1.35s |
| Iron Vault Lock | Burrow → Wall → Pulse | ~1.85s |
| Volt Sonic Tempest | Charge → Sonic → Orbit | ~1.75s |
| Shadow Eclipse Fang | Aura → Dive → Venom Burst | ~1.0s |

Jedes Video hat +0.4s Puffer am Ende.
