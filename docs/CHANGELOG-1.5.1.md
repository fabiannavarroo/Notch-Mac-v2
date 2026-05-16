# NotchMac 1.5.1 — Recupera tuning AirPods por variante

Hot-fix de 1.5.0.

## Fix

- **Migración V2**: cuando el debug panel todavía no era por variante, todos los ajustes se guardaban en claves globales. La migración V1 (en 1.5.0) solo los volcó al slot **AirPods Pro**, dejando AirPods, AirPods 4 ANC y AirPods Max en los valores por defecto del struct. Esta versión añade una segunda migración que copia el tuning de Pro a cualquier variante que siga en valores por defecto, así cada modelo arranca desde el mismo baseline que ya tenías afinado.

Si ya tunearás algún modelo no-Pro después de instalar 1.5.0, esos valores se respetan — solo se rellena lo que aún estaba en defaults.
