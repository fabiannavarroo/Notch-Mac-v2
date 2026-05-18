# NotchMac 1.7.0 — Ajustes premium, Updates en vivo y Pomodoro completo

Release de pulido tras 1.6.0. Settings rediseñado a fondo (sidebar charcoal premium con General / Notch / Modules / About), pane de Shortcuts nuevo con detección de conflictos en vivo, pane de Updates conectado a Sparkle sin polling, About que reabre el onboarding al instante, y Pomodoro con auto-cadena focus/break + sonido + notificación.

## Novedades

- **Settings premium:** sidebar reordenado (General · Notch · Modules · Music · Shelf · Calendar · Battery · AirPods · Pomodoro · HUD · Shortcuts · Updates · About) con fondo charcoal oscuro. Nuevas rutas `.general` (sistema / privacidad / estado app), `.notch` (behavior / sizing / gestures / auto-hide), `.modules` (overview + preview en vivo cerrado/abierto) y `.about` (créditos del fork, versión, update). Todos los toggles siguen con `@Default`, así que el notch refleja cambios en vivo sin reiniciar.
- **Shortcuts pane rediseñado:** tarjeta Media con recorder de Sneak Peek, tarjeta Notch con recorder de Toggle Notch Open + keycap readonly ⌥X para Manual Hide Island, tarjeta Actions con Reset / Clear (confirmación destructiva), y tarjeta Conflicts con detección de duplicados que se refresca al instante mediante la notificación de la librería KeyboardShortcuts.
- **Updates pane en vivo:** nuevo `UpdatesStatusModel` que actúa como `SPUUpdaterDelegate` y publica `check-in-progress`, `last-checked` y `update-available` como `ObservableObject`. El pane reacciona sin polling.
- **About → Reset Onboarding:** botón en Diagnostics reabre la ventana de onboarding al vuelo vía `.nmShowOnboarding`, observado por `AppDelegate`. Si `userInfo["reset"] == true`, también pone `BoringViewCoordinator.firstLaunch = true` para mostrar el paso de bienvenida.

## Pomodoro

- Settings → Pomodoro ahora abre el panel nuevo `NMPomodoroPanel` (reemplaza la llamada stale a `NMPomodoroSettingsCard`).
- `FocusSessionModel` gana:
  - `hasStarted` para distinguir sesión activa vs reset.
  - Helpers `startFocus()`, `startBreak()`, `reset()`.
  - `handleCompletion` con sonido **Glass** opcional, banner vía `UNUserNotificationCenter`, y auto-encadenado a break/focus.
- Nuevos defaults: `pomodoroAutoStartBreak`, `pomodoroAutoStartFocus`, `pomodoroPlaySoundOnEnd`, `pomodoroShowCompletionNotification` — todos expuestos en la nueva tarjeta Behavior.

## Notas

- Sparkle EdDSA + ad-hoc sign. Primera instalación: clic derecho → Abrir.
- Sin cambios destructivos en defaults; configuración existente se mantiene.
