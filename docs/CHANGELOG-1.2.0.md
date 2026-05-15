# NotchMac 1.2.0 — Notas de parche

## Cambios

- **Bordes modo expandido**: revertidos a los valores exactos de boring.notch upstream (`opened.top = 19`, `opened.bottom = 24`) y eliminado el stroke blanco overlay añadido en 1.1.0. Ahora la silueta coincide con la app original.
- **Notch más alto/bajo**: `openNotchSize.height` 190 → 215. El modo expandido tiene 25pt más de altura para que el contenido respire y no quede pegado a la barra de menús.
- **Pomodoro dot con gradiente**: el círculo interno (estilo "Dot inside notch") ahora se renderiza con un `AngularGradient` ámbar→naranja→rosa→ámbar en lugar de amarillo plano.
- **Icono app**: aplicada máscara squircle a `dock-icon-v3.png` para que los 4 ángulos sean transparentes — adiós al borde blanco residual.
- **Toggles Música/Pomodoro**: refactorizados `NMSidebarToggle` y `NMModuleRow` para usar `Defaults.Toggle` directo (binding nativo del paquete Defaults). Antes el `@State` interno podía quedarse desincronizado.
- **Shelf desactivado con archivos**: cuando el módulo Shelf se apaga mientras `currentView == .shelf`, ahora se renderiza Home como fallback y se cambia `currentView` automáticamente (en lugar de `EmptyView` → pantalla negra). Mismo fix aplicado al módulo Focus/Pomodoro.
- **`vm.close()` respeta `boringShelf`**: ya no vuelve a `.shelf` cuando hay archivos pero el módulo está apagado.
- **Hover-to-unhide arreglado**: `HiddenHoverDetector` ahora usa `Timer` a 60Hz contra `NSEvent.mouseLocation` en lugar de un global monitor (que requería permisos de accesibilidad y no se disparaba). Mover el ratón sobre la zona del notch oculto lo reabre instantáneamente en modo expandido.
- **Botón vaciar shelf**: añadido botón papelera rojo en la esquina superior derecha del panel del shelf — limpia todos los archivos de un clic.

## Plan de pruebas

- Toggle Music off → debería desaparecer del notch (cerrado y expandido) y forzar Calendar on si estaba off.
- Toggle Pomodoro off → si estabas en focus view, vuelve a home.
- Toggle Shelf off con archivos dentro → no se queda en negro.
- Opt+X → fade-out 0.32s. Mover el cursor sobre el notch → reaparece y se expande.
- Pomodoro dot indicator → debe verse gradiente ámbar→rosa.
