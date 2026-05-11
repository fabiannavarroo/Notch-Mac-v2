# NotchMac

App de macOS que aprovecha el notch del Mac como widget multifunción: música, calendario, batería, AirPods, temporizador, pomodoro, portapapeles, atajos rápidos y más.

Personalización personal de [**boring.notch**](https://github.com/TheBoredTeam/boring.notch) (GPL-3.0, © TheBoredTeam).

## Atribución

Este proyecto deriva de **boring.notch** por **TheBoredTeam**. Distribuido bajo **GNU GPL v3.0** (igual que el original).

- Original: https://github.com/TheBoredTeam/boring.notch
- Licencia: [LICENSE](./LICENSE) (GPL-3.0)
- Terceros: [THIRD_PARTY_LICENSES](./THIRD_PARTY_LICENSES)

## Requisitos

- macOS 14 Sonoma o superior (Apple Silicon o Intel)
- Xcode 15+ con Command Line Tools

## Compilar

```bash
git clone https://github.com/fabiannavarroo/Notch-Mac-v2.git
cd Notch-Mac-v2
open boringNotch.xcodeproj
```

En Xcode: target **boringNotch** → Run (⌘R). La app aparece en la barra de menú; el notch se muestra al hover sobre el cutout o con la hotkey configurada.

## Estructura

- `boringNotch/` — código fuente principal (SwiftUI + AppKit).
- `BoringNotchXPCHelper/` — helper XPC para acciones privilegiadas / streaming MediaRemote.
- `mediaremote-adapter/` — framework + script Perl para sortear deprecaciones de MediaRemote en macOS 15+.
- `updater/` — appcast Sparkle (desactivado en este fork; sin auto-update).
- `Configuration/` — config Xcode.

## Diferencias con boring.notch upstream

- Bundle id: `com.fabiannavarrofonte.notchmac` (en lugar de `theboringteam.boringnotch`).
- Display name: **NotchMac**.
- Sparkle auto-update **desactivado** (sin recibir notificaciones del repo original).
- Personalizaciones visuales y de features irán acumulándose en commits de este repo.

## Roadmap personal

- [x] Clon limpio + rebranding bundle id / nombre
- [ ] Iconografía propia
- [ ] Strings traducidos / personalizados
- [ ] Ajustes de layout para mi Mac (1710×1112, notch 209×38)
- [ ] Features extra integradas (pomodoro persistente, clipboard avanzado, etc.)

## Versión v1 (archivada)

Mi intento anterior de notch app desde cero está archivado en https://github.com/fabiannavarroo/Notch-Mac (rama `feature/notch-utility-redesign`). Sin actualizaciones; NotchMac v2 toma su lugar.
