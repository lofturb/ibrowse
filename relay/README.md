# IBrowse Relay

Servidor local para el **Modo Relay** de IBrowse. Descarga la web desde el PC,
la adapta y se la envía al iPad con iOS 9.

## Requisitos

- Node.js **18.17 o superior** (recomendado 20 LTS).
- PC y iPad en la misma red local.
- Abrir el puerto `8099` en el cortafuegos si no conecta.

## Arrancar

```bash
cd relay
npm install
npm start
```

Salida típica:

```
  IBrowse Relay 1.0.0 escuchando en 0.0.0.0:8099
  En IBrowse → Ajustes → Modo Relay usa:
    http://192.168.1.7:8099
```

En el iPad: **Ajustes → Modo Relay → Activar**, escribe esa dirección y pulsa
**Probar conexión**. Después abre una web normal; IBrowse envolverá las URLs
`http(s)` en `/browse?u=…`.

## Cómo funciona

| Ruta | Función |
|---|---|
| `/browse?u=URL` | Descarga HTML, reescribe enlaces/formularios/assets e inyecta el shim. |
| `/asset?u=URL` | Sirve JS transpilado, CSS reescrito, imágenes, fuentes y descargas. |
| `/api?u=URL` | Proxy para `fetch`/XHR del mismo origen. |
| `/submit?u=URL` | Proxy de formularios POST, conservando cookies. |
| `/health` | JSON de estado que usa el botón «Probar conexión». |

El HTML se procesa con **cheerio**; el JavaScript con **esbuild** apuntando a
`safari9`. Las cookies de la web original se guardan en memoria por host y se
reutilizan en las siguientes peticiones.

### Qué arregla

- Sintaxis moderna que Safari 9 no entiende: `async/await`, optional chaining,
  nullish coalescing, clases, spread, etc.
- URLs relativas que se romperían al servirse desde otro origen.
- Formularios GET/POST y redirecciones.
- `fetch`/XHR del mismo origen.
- CSP que bloquearía los scripts inyectados (se elimina la meta y la cabecera).

### Qué no arregla

- Módulos ES con `import`/`export` reales (iOS 9 no tiene módulos).
- WebAssembly, WebGL moderno, WebRTC, service workers.
- WebSockets (no se proxifican).
- TLS antiguo del iPad: si un sitio no negocia TLS con iOS 9, el relay no puede
  cambiar eso.
- `document.cookie` de la web original: las cookies viven en el servidor, no en
  el WebView. Las sesiones que dependen de leer cookies desde JS pueden fallar.

## Variables de entorno

| Variable | Por defecto | Descripción |
|---|---|---|
| `PORT` | `8099` | Puerto HTTP. |
| `HOST` | `0.0.0.0` | Interfaz de escucha. |
| `RELAY_ALLOW_PRIVATE` | `0` | `1` permite acceder a `localhost`, `192.168.*`, etc. |
| `RELAY_MAX_BYTES` | `12582912` | Tamaño máximo por respuesta (12 MB). |
| `RELAY_MAX_FORM_BYTES` | `2097152` | Tamaño máximo de un formulario (2 MB). |
| `RELAY_TIMEOUT_MS` | `30000` | Timeout de descarga. |
| `RELAY_UA` | Safari 17 macOS | User-Agent que usa el relay. |
| `RELAY_VERBOSE` | `1` | `0` desactiva el log de peticiones. |

Ejemplo en Windows (PowerShell):

```powershell
$env:RELAY_ALLOW_PRIVATE="1"
npm start
```

En Linux/macOS:

```bash
RELAY_ALLOW_PRIVATE=1 npm start
```

## Seguridad

El relay **no tiene autenticación** y ve las páginas y cookies que pasan por él.
Está pensado para una red doméstica de confianza, no para exponerlo a Internet.
No lo abras al exterior con un port forwarding.

Por defecto bloquea destinos privados para evitar que una web use el relay como
puente hacia tu router o tu LAN. Si necesitas acceder a un servidor local,
activa `RELAY_ALLOW_PRIVATE=1` y asume el riesgo.

El bloqueo de IPs privadas se hace por nombre; una web maliciosa con un dominio
que resuelva a una IP privada (DNS rebinding) podría saltárselo. No publiques el
puerto en Internet.

## Problemas frecuentes

**El iPad no conecta**

- Comprueba que está en la misma WiFi.
- Abre `http://IP:8099/health` desde el navegador del PC.
- Permite Node.js en el cortafuegos de Windows.
- Algunos routers aíslan a los clientes WiFi («AP isolation»): desactívalo.

**La web carga pero sin estilos**

- El CSS puede usar `@layer`, `:has()` o contenedores modernos que Safari 9 no
  entiende. El relay reescribe `url()` pero no traduce CSS moderno.
- Revisa la consola del relay para ver si algún asset devuelve 403/502.

**Se queda en «Conectando…»**

- La web puede tardar más que `RELAY_TIMEOUT_MS`.
- Una respuesta puede superar `RELAY_MAX_BYTES`.

**El botón «Probar conexión» falla pero la web carga**

- El test usa `/health` con timeout de 5 s. Si el PC está ocupado, puede fallar
  aunque el relay funcione.

## Desarrollo

```bash
npm run dev      # RELAY_VERBOSE=1
node --check server.js
```
