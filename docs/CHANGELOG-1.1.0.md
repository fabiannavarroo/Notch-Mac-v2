# NotchMac 1.1.0 — Notas de parche

## Cambios principales

- **Icono nuevo**: ahora usa `dock-icon-v3.png` (sin fondo negro residual). Todos los tamaños del icon set regenerados.
- **Borde modo expandido**: añadido el trazo blanco sutil del original boring.notch (`stroke(.white.opacity(0.10), lineWidth: 0.7)`) alrededor del shape abierto.
- **Drag-and-drop**:
  - El shelf ahora se desplaza con la rueda del ratón. Se cambió la lista horizontal por un `LazyVGrid` vertical con autoscroll.
  - Padding superior añadido para no chocar con el notch.
  - Botón de papelera al hacer hover sobre cualquier archivo del shelf (borrado individual).
- **Pomodoro**:
  - Indicador "dot" con grosor 3.5 (antes 2). Más visible en el notch.
  - Picker en ajustes: Off / Dot / Ring (anillo perimetral).
- **Animación de ocultación**: Opt+X y auto-hide ahora usan un fade `NSAnimationContext` de 0.32s en lugar de desaparecer de golpe.
- **Reaparecer al hover**: con la isla oculta, mover el ratón al hueco del notch la trae de vuelta y abre el modo expandido automáticamente.
- **Mutex Música/Calendario**: si desactivas Música y Calendario está apagado, Calendario se enciende solo (y viceversa). Pomodoro y Shelf siguen siendo libres de apagar.
- **Shelf desactivado con archivos**: ya no se queda en negro. Se cambia automáticamente a Home.
- **Iconos superiores**: reducidos de 30→26pt (gear/camera) y batería 30→24pt para evitar recorte en pantallas con notch pequeño.
- **Modo pantalla completa**: `hideNotchOption` ahora `.always` por defecto. La isla se oculta cuando hay cualquier app en pantalla completa.
- **Selector salida de audio**: portado el `SystemVolumeService` de NotchMac v1 como `AudioOutputManager`. Botón altavoz en la esquina inferior derecha del módulo de música cuando es el único módulo activo (sin calendario ni pomodoro). Al pulsar abre popover con los dispositivos disponibles (AirPods, altavoces internos, AirPlay…).

## Notas técnicas

- 3 archivos nuevos añadidos al target NotchMac vía edición directa de `project.pbxproj`:
  - `NotchMac/observers/HiddenHoverDetector.swift`
  - `NotchMac/managers/AudioOutputManager.swift`
  - `NotchMac/components/Music/AudioOutputPicker.swift`
- Bordes expandidos: ahora 28/32pt en `cornerRadiusInsets.opened`.
- Animación pomodoro: timer a 0.1s + animación lineal 0.18s para movimiento continuo.
