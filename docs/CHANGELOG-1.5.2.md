# NotchMac 1.5.2 — AirPods oculto temporalmente

El módulo AirPods queda desactivado en esta versión mientras se prepara una página de **debug dedicada** para iterar sobre él. Todo el código permanece intacto bajo un único interruptor (`AirPodsModule.visible`) — flipping it back is one-line.

## Qué cambia

- **Notch sin live activity AirPods**: el chin no se expande al conectar AirPods.
- **Sin pestaña "AirPods"** en el notch abierto.
- **Settings**: se ocultan la sección de AirPods en el sidebar, en la tarjeta "Modules" y la tarjeta de tuning.
- **Sin polling de batería** (no se arranca `AirPodsManager`).

## Qué se preserva

- Los **valores curados** dialed in para AirPods, AirPods 4 ANC, AirPods Pro y AirPods Max quedan bakeados como defaults del struct (`AirPodsTuning.curatedRegular/ANC/Pro/Max`). Cuando el módulo se reactive, cada variante arrancará con su baseline.
- Las tunings guardadas previamente en Defaults por usuarios que probaron 1.5.0 / 1.5.1 siguen ahí.
- Filtro de caja, modelo 3D, asset loader y dashboard quedan intactos en código.
