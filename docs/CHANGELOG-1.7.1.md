# NotchMac 1.7.1 — Español completo y pulido de Settings

Patch sobre 1.7.0. Llega selector de idioma in-app (English / Español) con traducción al español de toda la UI, y se limpian apilamientos verticales en varias tarjetas de Settings.

## Idioma

- **Picker English / Español** en Settings → General. Cambia el idioma de toda la app al vuelo sin reiniciar.
- **Traducción al español** de 257+ cadenas (cabeceras, paneles, descripciones, tooltips, botones) — Pomodoro, Shortcuts, Updates, About, Modules, Music, Calendar, Battery, AirPods y onboarding.
- **Refactor i18n:** props `String` ahora se enrutan vía `LocalizedStringKey` cuando llegan a `Text` para que se traduzcan correctamente sin tocar cada vista.

## Settings — layout

- **General:** tarjetas en columna única para evitar cortes en notch estrecho.
- **Pomodoro:** "Durations" e "Indicator" apiladas verticalmente; preview de notch cerrado removido de la tarjeta Indicator (estaba redundante con el preview principal).
- **Updates / About:** apilados en columna; previews redundantes podados.

## Notas

- Sin cambios funcionales fuera de idioma + layout.
- Defaults existentes intactos.
