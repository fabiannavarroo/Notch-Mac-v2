# NotchMac 1.6.0 — Apple Intelligence, efectos de música y Ajustes premium

Release grande tras la racha 1.5.x. Llega Apple Intelligence al Shelf, nuevos efectos visuales en el módulo de música, un panel de Ajustes de Calendario rediseñado, una tarjeta General con estado en vivo de la app, y todos los toggles del header / batería / barra de menú ahora reaccionan sin reiniciar.

## Novedades

- **Apple Intelligence en el Shelf:** nueva tarjeta de chat + resumen de PDF directamente desde la bandeja del notch. Toggle dedicado en Ajustes → Shelf.
- **Apple Intelligence en Ajustes → Módulos:** tarjeta propia para controlar la integración desde la pestaña Modules.
- **Efectos opt-in en música:** parallax del artwork, animación de flip y wavy slider en el módulo expandido. Persisten vía `Defaults.Toggle`.
- **Flip en notch cerrado:** la animación de flip del artwork ahora también se aplica a la live activity de música cuando el notch está cerrado.
- **Panel premium de Calendario:** Ajustes → Calendario rediseñado con bindings en vivo (no más reiniciar para ver cambios).
- **General App card:** Ajustes muestra el estado de la app en tiempo real y expone un Quit discreto pero accesible.

## Mejoras

- Pomodoro mantiene el music visualizer visible cuando el ring indicator está activo (regression fix de 1.5.x).
- Toggles del header reactivos: Caffeinate, indicador de batería, % de batería y power-status icons aplican al momento.
- Toggle "icono en barra de menús" entra/sale sin reiniciar la app.
- Toggle "mostrar en pantalla bloqueada" aplica en vivo si la pantalla ya está bloqueada.
- `FocusSessionModel` puede recalcular total/restante cuando editas minutos focus/break con sesión en curso.

## Notas

- Sparkle EdDSA + ad-hoc sign. Si es la primera instalación, clic derecho → Abrir.
- Sin cambios destructivos en defaults; quien tenía AirPods bakeado en 1.5.3 lo mantiene.
