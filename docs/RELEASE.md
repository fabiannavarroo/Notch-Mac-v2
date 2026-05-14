# Distribuir NotchMac a otra persona con auto-update

Pipeline: hace push de un tag `vX.Y.Z` → GitHub Action builds → sube `.zip` firmado con EdDSA y actualiza `updater/appcast.xml` → la app instalada en el Mac del amigo lo detecta vía Sparkle y se actualiza sola.

## Setup inicial (UNA SOLA VEZ)

### 1. Generar par de claves EdDSA

```bash
brew install --cask sparkle           # o descarga Sparkle-2.x.tar.xz
# Si lo descargaste manual:
cd ~/Downloads/Sparkle-2.6.4/bin
./generate_keys
```

Salida:
```
A key has been generated and saved in your keychain.
In your app's Info.plist add the following line:
<key>SUPublicEDKey</key>
<string>AbCdEfGh...==</string>
```

### 2. Exportar la clave privada

```bash
./generate_keys -x ed25519_priv.key    # exporta clave privada a archivo
cat ed25519_priv.key                   # copia todo el contenido
```

### 3. GitHub Secret

GitHub → repo → Settings → Secrets and variables → Actions → **New repository secret**
- Name: `SPARKLE_ED_PRIVATE_KEY`
- Value: pega el contenido de `ed25519_priv.key`

Borra `ed25519_priv.key` del disco una vez subida.

### 4. Pega la clave pública en Info.plist

Edita [NotchMac/Info.plist](../NotchMac/Info.plist) y reemplaza `REPLACE_WITH_PUBLIC_KEY` por la `SUPublicEDKey` que dió `generate_keys`.

```xml
<key>SUPublicEDKey</key>
<string>AbCdEfGh...==</string>
```

Commit + push.

### 5. Build inicial + enviar al amigo

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Action arranca. Cuando termine:
- Hay un release `v1.0.0` con `NotchMac-1.0.0.zip`
- `updater/appcast.xml` actualizado en `main`

Descarga el `.zip`, descomprime, manda `NotchMac.app` al amigo. Primera vez tendrá que hacer **clic derecho → Abrir** para saltarse Gatekeeper (ad-hoc sign, no notarizado).

## A partir de ahí, cada update

```bash
# Haces tus cambios, commiteas, etc.
git tag v1.1.0
git push origin v1.1.0
```

El amigo recibe el update en máximo 1 hora (intervalo de chequeo) o cuando abra la app. Sparkle valida la firma EdDSA con la clave pública embebida → descarga → reemplaza la app → reinicia.

## Notas

- **No es necesario Apple Developer ID** para esta vía. Solo ad-hoc + EdDSA.
- Si quieres quitar el aviso "app dañada / fabricante no identificado", añade notarización con tu Apple ID (extra steps, ~$99/año Developer Program).
- El intervalo de chequeo se cambia en `Info.plist` con `SUScheduledCheckInterval` (segundos, actual = 3600 = 1h).
- El usuario puede forzar check desde el menú de ajustes de la app si está conectado a la UI.
