# IBrowse — compilación automática

IPA para **iPad mini 1 / iOS 9.3.6 (armv7)** compilado con Theos, el toolchain
LLVM de L1ghtmann, el SDK iPhoneOS9.3 y `ldid`.

## Instalación

1. Descarga `IBrowse-ipa-armv7` desde los artefactos de la ejecución (o el `.ipa` del Release).
2. Con el iPad conectado por USB y `ideviceinstaller` instalado en el PC:

   ```bash
   ideviceinstaller -i IBrowse.ipa
   ```

3. Alternativa sin cable: copia el `.ipa` al iPad con Filza/AFC y ábrelo con AppSync Unified.

## Requisitos en el iPad

- Jailbreak con **AppSync Unified** (para aceptar la firma de `ldid`).
- iOS 9.x, armv7.

## Notas

- Si una web no carga, activa **Modo Relay** en Ajustes y arranca el servidor
  de `relay/` en el PC (misma red local).
- El IPA no está firmado con un certificado de Apple. No se instala en un
  dispositivo sin jailbreak.
- Esta compilación no incluye telemetría.
