# NotchMac 1.5.0 — AirPods en el notch

Esta versión añade una *live activity* completa para AirPods en el notch: detección automática al conectar, modelo 3D oficial de Apple girando, batería por auricular y caja, notificaciones de batería baja, y una sección de ajustes para afinar la apariencia de cada modelo.

## Nuevo: módulo AirPods

- **Detección automática al conectar** — escucha cambios de salida CoreAudio + Bluetooth y reconoce AirPods, AirPods 4, AirPods 4 con ANC, AirPods Pro y AirPods Max.
- **Sneak peek en el notch cerrado** — al conectar, el notch se expande durante 5 s mostrando el modelo 3D de los AirPods girando + un anillo verde con la batería media. Mismo lenguaje visual que la live activity de música.
- **Dashboard expandido** — pestaña "AirPods" en el notch abierto con el modelo completo (auriculares + caja) rotando, batería separada por L / R / Case y nombre del dispositivo.
- **Modelo 3D oficial de Apple** — descarga perezosa de los USDZ públicos del AR Quick Look de apple.com (uno por variante), cacheados en `~/Library/Caches/NotchMac/airpods/`. No se redistribuyen binarios de Apple dentro del .app.
- **Batería precisa** — vía `system_profiler SPBluetoothDataType -json`, sin APIs privadas. Polling adaptativo: 60 s en idle, 30 s normal, 15 s cuando baja del 30 %.
- **Notificaciones de batería** — alertas nativas macOS al cruzar 50 % / 20 % / 10 % bajando; se rearman cuando recarga por encima del 60 %. Configurable.

## Ajustes finos por variante

- Cada modelo (AirPods, AirPods 4 ANC, AirPods Pro, AirPods Max) guarda **su propia configuración** de:
  - Layout del tile en el notch cerrado (ancho, padding, desplazamiento).
  - Render del modelo 3D (zoom, inclinación X, desplazamiento vertical, cámara FOV/Z/Y, velocidad y dirección de rotación).
  - Filtro de caja (línea de corte Y, umbral de área, modo estricto que quita LED + bisagra).
  - Anillo de batería del mini (diámetro, grosor, padding, tamaño del %).
  - Modelo expandido del dashboard (tamaño del tile, zoom, cámara, rotación, mostrar caja).
- **Vista previa en vivo** dentro de Ajustes → Módulos → "AirPods — apariencia": dos tarjetas (mini + expandido) que se actualizan al instante mientras mueves los sliders.
- **Selector de variante** para previsualizar cualquier modelo aunque no lo tengas conectado.
- **Preview pinneado** mientras haces scroll por los sliders, para no perderlo de vista.
- **Valor numérico grande** en cada slider — badge verde menta monospace con transición animada.

## Fixes técnicos relevantes

- El modelo 3D usa filtrado por *footprint horizontal* en lugar de extent vertical: ahora se preservan los palos (stems) del AirPods Pro y se eliminan correctamente caja + LED + barra de metal de la bisagra.
- SceneKit reconfiguración incremental — al arrastrar sliders el modelo aplica zoom / cámara / rotación en vivo sobre la escena existente; solo rebuild completo cuando cambia geometría (filtros, mostrar caja). La rotación ya no se reinicia con cada tick.
- `AirPodsTuningCenter` (singleton ObservableObject) republica las escrituras de tuning para que los cambios se reflejen al instante en el notch real y en las previews — sin necesidad de cambiar de pestaña en Ajustes para refrescar.

## Bundle + compatibilidad

- Sigue sobre macOS 14+, sin notarización (firma ad-hoc, primer arranque por click-derecho → Abrir).
- Auto-update vía Sparkle: la 1.4.0 detectará 1.5.0 automáticamente.
