# IBrowse

Navegador para **iPad mini 1 (armv7) con iOS 9.3.6**, pensado para seguir usando
un iPad de 2012 con webs actuales. Está construido sobre **WKWebView** (el motor
que trae iOS 9) y añade lo que se puede añadir desde la app: polyfills, bloqueo
de anuncios, modo lector, descargas y un **Modo Relay** opcional que adapta el
JavaScript moderno desde un PC de la red local.

> **Honestidad primero:** iOS 9 no permite sustituir WebKit. Ningún navegador
> de la App Store puede hacerlo y compilar un motor nuevo para armv7 no es
> viable. IBrowse reduce los fallos todo lo que se puede reducir, pero no
> convierte un iPad mini 1 en un iPad moderno. Las webs que dependen de
> WebAssembly, WebGL pesado, módulos ES, service workers o TLS moderno seguirán
> fallando.

## Qué incluye

- **Pestañas** con tira superior, restauración de sesión y modo privado.
- **Barra de direcciones** con búsqueda (DuckDuckGo, Google, Bing, Startpage,
  Brave o Wikipedia), botones atrás/adelante/recargar y estrella de marcadores.
- **Historial, marcadores y descargas** persistentes.
- **Bloqueo de anuncios y rastreadores** con listas propias inyectadas antes de
  cargar la página.
- **Compatibilidad JS**: polyfills ES5 para `Promise`, `fetch` parcial,
  `URLSearchParams`, `IntersectionObserver`, `matchMedia`, `requestAnimationFrame`,
  `TextEncoder`, `ResizeObserver`, etc.
- **Modo lector** que extrae el texto del artículo y lo muestra con tipografía
  de lectura.
- **Descargas** interceptadas y guardadas en
  `/var/mobile/Media/IBrowse/Downloads` (visibles desde Filza/AFC).
- **Modo Relay opcional**: un servidor Node 18 en el PC descarga la web,
  reescribe HTML/CSS, transpila JavaScript moderno con esbuild a `safari9` y
  mantiene las cookies de sesión.
- **Sin telemetría, sin cuentas, sin publicidad**.

## Requisitos

| | |
|---|---|
| Dispositivo | iPad mini 1 (iPad2,5) u otro armv7 |
| Sistema | iOS 9.x (probado como objetivo 9.3.6) |
| Jailbreak | Sí, con **AppSync Unified** |
| Compilación | Theos + toolchain LLVM de L1ghtmann + SDK `iPhoneOS9.3` + `ldid` |
| Relay (opcional) | Node.js 18+ en el PC |

El proyecto está preparado para compilarse **sin Mac** mediante GitHub Actions,
igual que la guía `Guia-IPA-iOS9`.

## Compilar

### GitHub Actions (recomendado en Windows)

1. Sube el repositorio a GitHub.
2. Ve a **Actions → Construir IPA (IBrowse / iOS 9 armv7) → Run workflow**.
3. Al terminar, descarga el artefacto **`IBrowse-ipa-armv7`**.
4. El workflow también crea un Release con el `.ipa` si se ejecuta a mano o se
   sube a `main`.

El flujo comprueba fuentes, metadatos, recursos, sintaxis JavaScript, compila
con Theos, verifica que el binario sea armv7 y revisa la estructura del IPA.

### Local (macOS o Linux)

```bash
export THEOS=/ruta/a/theos
make -C app clean
make -C app package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
```

Necesitas el SDK 9.3 y el toolchain en `$THEOS`. El `Makefile` ya declara
`TARGET = iphone:clang:9.3:9.0`, `ARCHS = armv7` y los entitlements para escribir
en `/var/mobile/Media`.

## Instalar en el iPad

Descarga el IPA ya compilado desde
[**Releases → último build**](https://github.com/lofturb/ibrowse/releases/latest):

```text
https://github.com/lofturb/ibrowse/releases/latest/download/com.lofturb.ibrowse_1.0.0.ipa
```

Con el iPad conectado por USB y `ideviceinstaller` en el PC:

```bash
ideviceinstaller -i IBrowse.ipa
```

Alternativas:

- Copiar el `.ipa` al iPad con Filza/AFC y abrirlo (AppSync Unified debe estar
  instalado).
- Usar `entrega-web/servir.py` y abrir la página desde Safari en el iPad.

El IPA va firmado con `ldid`, **no** con un certificado de Apple: no se instala
en un dispositivo sin jailbreak.

## Modo Relay

El relay es opcional. Sin él, IBrowse funciona como un navegador WKWebView con
polyfills. Con él, las webs que usan sintaxis moderna (`async/await`, optional
chaining, clases, módulos sin imports…) tienen una segunda oportunidad.

```bash
cd relay
npm install
npm start
```

Abre en el PC `http://IP-DEL-PC:8099/` para ver la dirección que debes escribir
en **IBrowse → Ajustes → Modo Relay**. El botón **Probar conexión** consulta
`/health`.

El servidor:

- descarga el HTML y reescribe enlaces, formularios, imágenes, CSS y scripts;
- transpila JavaScript con esbuild (`target: safari9`);
- conserva cookies de sesión en memoria por host;
- limita el tamaño de respuesta (12 MB por defecto) y bloquea direcciones
  privadas salvo que arranques con `RELAY_ALLOW_PRIVATE=1`;
- **ve todo el tráfico que pasa por él**. Úsalo solo en una red de confianza.

Detalles y variables de entorno en [`relay/README.md`](relay/README.md).

## Estructura

```
app/
  Makefile                 fuentes, frameworks y entitlements
  control                  metadatos del paquete
  main.m / AppDelegate.m
  IBBrowserViewController  interfaz principal, pestañas, barra y menú
  IBWebTab                 WKWebView, navegación, puente JS, descargas
  IBSettings               preferencias y user agents
  IBContentBlocker         inyección de polyfills/bloqueador/puente
  IBHistoryStore           historial en plist
  IBBookmarkStore          marcadores en plist
  IBDownloadManager        descargas con NSURLSession
  IBListViewController     marcadores e historial
  IBDownloadsViewController
  IBReaderViewController   modo lector
  IBSettingsViewController
  IBAboutViewController
  IBTheme / IBStore / IBURLNormalizer / IBTabChipView / IBErrorView
  Resources/
    Info.plist
    start.html
    ibrowse-polyfills.js
    ibrowse-blocker.js
    ibrowse-bridge.js
    ibrowse-reader.js
    iconos y LaunchImage-*.png
tools/
  generar_recursos.py      iconos y arranque sin dependencias
  comprobar_fuentes.py     coherencia Makefile/Info.plist/control
  verificar_recursos.py    PNG, JS y referencias de Info.plist
  extraer_js_inline.py     JS inline para node --check
  afc_*.py, servir.py, verificar_ipa.py, simbolizar*.py
relay/
  server.js                proxy/transpilador para el iPad
  package.json
entrega-web/
  index.html               página de instalación local
  servir.py                servidor con MIME correcto para .ipa
.github/workflows/
  build-ipa.yml
```

## Limitaciones conocidas

- **WebKit es el de iOS 9**. Safari 9 no tiene módulos ES, `async/await`,
  service workers, `IntersectionObserver` nativo, `fetch` nativo ni buena parte
  de CSS moderno. Los polyfills cubren APIs, no sintaxis.
- **TLS**: el almacén de certificados de iOS 9 es de 2016. Instala el perfil
  `CertificadosModernos.mobileconfig` de la guía si ves errores HTTPS. IBrowse
  permite HTTP plano (`NSAllowsArbitraryLoads`), pero eso no valida certificados.
- **Vídeo**: H.264 básico funciona; códecs modernos, DRM y algunas webs de
  streaming no.
- **Relay**: no proxyfica WebSockets, no resuelve módulos ES con imports, no
  ejecuta WebAssembly y no arregla TLS del lado del iPad. Tampoco es un
  navegador remoto: el HTML sigue renderizándose en el iPad.
- **Rendimiento**: 512 MB de RAM y un A5. Muchas pestañas abiertas se notan.
  IBrowse descarga las pestañas no visibles cuando hay poca memoria.
- **App Store**: no es instalable desde la App Store; requiere jailbreak.

## Privacidad

IBrowse no envía telemetría. El historial, los marcadores, la sesión y las
descargas se guardan en el iPad (`Documents` y `/var/mobile/Media/IBrowse`).
El Modo Relay es un servidor tuyo y solo se usa si lo activas; aun así, ve las
páginas y las cookies que pasan por él.

## Créditos

- Estructura de compilación basada en **Guia-IPA-iOS9**.
- Theos, toolchain LLVM de **L1ghtmann**, SDK `iPhoneOS9.3`, `ldid`.
- **esbuild** y **cheerio** para el relay.
- WebKit es propiedad de Apple.

Licencia MIT. Proyecto personal, sin afiliación con Apple, Brave ni DuckDuckGo.
