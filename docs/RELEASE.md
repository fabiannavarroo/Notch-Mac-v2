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

## ⚠️ Limitación: "Update Error! An error occurred while launching the installer"

El build es **ad-hoc firmado y NO notarizado**. El helper instalador de Sparkle
(`Autoupdate` + `Installer.xpc` dentro de `Sparkle.framework`) queda con firma
`adhoc` y `TeamIdentifier=not set`. Cuando Sparkle descarga el `.zip`, macOS le
pone el atributo `com.apple.quarantine`; al intentar lanzar el instalador,
Gatekeeper bloquea un helper no notarizado → el auto-update **falla con ese error**.

Esto **no es un bug de una versión concreta** — es el modelo de distribución
ad-hoc chocando con Gatekeeper. El auto-update in-app no es confiable sin
notarización.

### Arreglo definitivo
Notarizar el `.app` con un Apple Developer ID (~$99/año) y añadir el paso
`xcrun notarytool submit` + `stapler staple` al workflow antes de empaquetar.
Con eso el auto-update de Sparkle funciona sin tocar nada más.

### Update manual (mientras no haya notarización)
Instrucciones para compartir con usuarios cuando aparezca el error:

1. Cancela el error en la app.
2. Baja el `.zip` más reciente de
   https://github.com/fabiannavarroo/Notch-Mac-v2/releases/latest
3. Descomprime y arrastra `NotchMac.app` a `/Applications` (reemplaza la vieja).
4. Quita la cuarentena para que abra sin avisos y para que el próximo
   auto-update tenga más opción de funcionar:
   ```bash
   xattr -dr com.apple.quarantine /Applications/NotchMac.app
   ```
5. Primera apertura: clic derecho en la app → **Abrir**.
