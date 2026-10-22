'use strict';

/*
 * IBrowse Relay
 * -------------
 * Servidor local (Node 18+) que hace de intermediario entre el iPad con
 * iOS 9 y las webs modernas:
 *
 *   /browse?u=URL   -> descarga HTML, reescribe enlaces y ejecuta esbuild
 *   /asset?u=URL    -> sirve JS transpilado, CSS reescrito, imagenes, fuentes…
 *   /api?u=URL      -> proxy para fetch/XHR del mismo origen
 *   /submit?u=URL   -> proxy de formularios POST
 *   /health         -> comprobacion desde Ajustes
 *
 * Limites conocidos: no es un navegador remoto ni un motor JS completo.
 * No arregla WebAssembly, WebGL moderno, TLS antiguo ni APIs que dependen
 * del sistema operativo. Ve el trafico que pasa por el: usalo en una red
 * de confianza.
 */

const http = require('node:http');
const os = require('node:os');
const { URL } = require('node:url');
const cheerio = require('cheerio');
const esbuild = require('esbuild');

const PORT = Number(process.env.PORT || 8099);
const HOST = process.env.HOST || '0.0.0.0';
const MAX_BYTES = Number(process.env.RELAY_MAX_BYTES || 12 * 1024 * 1024);
const MAX_FORM_BYTES = Number(process.env.RELAY_MAX_FORM_BYTES || 2 * 1024 * 1024);
const TIMEOUT_MS = Number(process.env.RELAY_TIMEOUT_MS || 30000);
const ALLOW_PRIVATE = process.env.RELAY_ALLOW_PRIVATE === '1';
const VERBOSE = process.env.RELAY_VERBOSE !== '0';
const VERSION = '1.0.0';

const MODERN_UA = process.env.RELAY_UA ||
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ' +
  'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15';

const cookieJar = new Map();

function log() {
  if (!VERBOSE) { return; }
  console.log('[relay]', new Date().toISOString(), ...arguments);
}

function escapeHTML(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function isPrivateHost(hostname) {
  let host = String(hostname || '').toLowerCase().replace(/^\[|\]$/g, '');
  if (host === 'localhost' || host === '0.0.0.0' || host === '::1' ||
      host === '::' || host.endsWith('.local') || host.endsWith('.internal')) {
    return true;
  }
  if (/^127\./.test(host) || /^10\./.test(host) || /^169\.254\./.test(host) ||
      /^192\.168\./.test(host)) {
    return true;
  }
  const m = host.match(/^172\.(\d+)\./);
  if (m) {
    const second = Number(m[1]);
    if (second >= 16 && second <= 31) { return true; }
  }
  if (host.startsWith('fc') || host.startsWith('fd') || host.startsWith('fe80:')) {
    return true;
  }
  return false;
}

function assertTarget(url) {
  if (!/^https?:$/.test(url.protocol)) {
    throw new Error('Solo se permiten direcciones http y https.');
  }
  if (!ALLOW_PRIVATE && isPrivateHost(url.hostname)) {
    throw new Error('El relay bloquea direcciones privadas por defecto. ' +
                    'Arrancalo con RELAY_ALLOW_PRIVATE=1 para permitirlas.');
  }
}

function targetFromRequest(requestURL) {
  const raw = requestURL.searchParams.get('u');
  if (!raw) { return null; }

  let target;
  try {
    target = new URL(raw);
  } catch (e) {
    return null;
  }
  assertTarget(target);

  for (const [key, value] of requestURL.searchParams) {
    if (key === 'u' || key === 'm') { continue; }
    target.searchParams.append(key, value);
  }
  return target;
}

function cookieHeaderFor(url) {
  const host = url.hostname.toLowerCase();
  const pairs = [];
  for (const [domain, jar] of cookieJar.entries()) {
    if (host === domain || host.endsWith('.' + domain)) {
      for (const [name, value] of jar.entries()) {
        pairs.push(name + '=' + value);
      }
    }
  }
  return pairs.join('; ');
}

function getSetCookies(response) {
  if (typeof response.headers.getSetCookie === 'function') {
    return response.headers.getSetCookie();
  }
  const raw = response.headers.get('set-cookie');
  if (!raw) { return []; }
  return raw.split(/,(?=[^;,]+=)/);
}

function storeCookies(url, response) {
  const host = url.hostname.toLowerCase();
  let jar = cookieJar.get(host);
  if (!jar) {
    jar = new Map();
    cookieJar.set(host, jar);
  }

  for (const raw of getSetCookies(response)) {
    const parts = String(raw).split(';').map(function (part) {
      return part.trim();
    });
    const pair = parts.shift() || '';
    const index = pair.indexOf('=');
    if (index <= 0) { continue; }

    const name = pair.slice(0, index).trim();
    const value = pair.slice(index + 1).trim();
    const flags = parts.map(function (part) {
      return part.toLowerCase();
    });

    const expired = flags.some(function (flag) {
      return flag === 'max-age=0' ||
        flag.indexOf('expires=thu, 01 jan 1970') === 0;
    });

    if (expired) {
      jar.delete(name);
    } else {
      jar.set(name, value);
    }
  }
}

async function fetchTarget(url, options) {
  const opts = options || {};
  const controller = new AbortController();
  const timer = setTimeout(function () {
    controller.abort();
  }, TIMEOUT_MS);

  const headers = Object.assign({
    'user-agent': MODERN_UA,
    'accept-language': 'es-ES,es;q=0.9,en;q=0.8',
    'accept-encoding': 'gzip, deflate, br'
  }, opts.headers || {});

  const cookie = cookieHeaderFor(url);
  if (cookie) { headers.cookie = cookie; }

  try {
    const response = await fetch(url.href, {
      method: opts.method || 'GET',
      headers: headers,
      body: opts.body,
      redirect: 'manual',
      signal: controller.signal
    });
    storeCookies(url, response);
    return response;
  } finally {
    clearTimeout(timer);
  }
}

async function readBody(response) {
  const declared = Number(response.headers.get('content-length') || 0);
  if (declared > MAX_BYTES) {
    throw new Error('La respuesta supera el limite de ' +
                    Math.round(MAX_BYTES / 1024 / 1024) + ' MB.');
  }
  const buffer = Buffer.from(await response.arrayBuffer());
  if (buffer.length > MAX_BYTES) {
    throw new Error('La respuesta supera el limite de ' +
                    Math.round(MAX_BYTES / 1024 / 1024) + ' MB.');
  }
  return buffer;
}

function readRequestBody(request) {
  return new Promise(function (resolve, reject) {
    const chunks = [];
    let total = 0;

    request.on('data', function (chunk) {
      total += chunk.length;
      if (total > MAX_FORM_BYTES) {
        reject(new Error('El formulario es demasiado grande.'));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', function () {
      resolve(Buffer.concat(chunks));
    });
    request.on('error', reject);
  });
}

function charsetFor(contentType) {
  const match = String(contentType || '').match(/charset\s*=\s*["']?([^;"'\s]+)/i);
  return match ? match[1].toLowerCase() : 'utf-8';
}

function decodeBuffer(buffer, contentType) {
  const charset = charsetFor(contentType);
  try {
    return new TextDecoder(charset).decode(buffer);
  } catch (e) {
    return buffer.toString('utf8');
  }
}

function isHTML(contentType) {
  return /html/i.test(contentType || '');
}

function isJavaScript(contentType, url) {
  if (/javascript|ecmascript/i.test(contentType || '')) { return true; }
  try {
    return /\.m?js$/i.test(new URL(url).pathname);
  } catch (e) {
    return false;
  }
}

function isCSS(contentType, url) {
  if (/text\/css/i.test(contentType || '')) { return true; }
  try {
    return /\.css$/i.test(new URL(url).pathname);
  } catch (e) {
    return false;
  }
}

function skipProxy(raw) {
  return !raw || raw.charAt(0) === '#' ||
    /^(data:|javascript:|mailto:|tel:|sms:|blob:|about:|file:)/i.test(raw) ||
    /^\/(browse|asset|api|submit)\?/i.test(raw);
}

function absolute(raw, base) {
  try {
    return new URL(raw, base).href;
  } catch (e) {
    return null;
  }
}

function proxyURL(kind, raw, base) {
  if (skipProxy(raw)) { return raw; }
  const target = absolute(raw, base);
  if (!target || !/^https?:/i.test(target)) { return raw; }
  return '/' + kind + '?u=' + encodeURIComponent(target);
}

function rewriteSrcset(value, base) {
  if (!value || /data:/i.test(value)) { return value; }
  return String(value).split(',').map(function (part) {
    const trimmed = part.trim();
    if (!trimmed) { return trimmed; }
    const bits = trimmed.split(/\s+/);
    const first = bits.shift();
    const proxied = proxyURL('asset', first, base);
    return [proxied].concat(bits).join(' ');
  }).join(', ');
}

function rewriteCSS(css, base) {
  let output = String(css || '');

  output = output.replace(
    /@import\s+(?:url\(\s*)?["']?([^"')\s;]+)["']?\s*\)?[^;]*;/gi,
    function (match, href) {
      if (skipProxy(href)) { return match; }
      return '@import url("' + proxyURL('asset', href, base) + '");';
    }
  );

  output = output.replace(
    /url\(\s*(["']?)([^"')]+)\1\s*\)/gi,
    function (match, quote, href) {
      const clean = href.trim();
      if (skipProxy(clean)) { return match; }
      return 'url(' + quote + proxyURL('asset', clean, base) + quote + ')';
    }
  );

  return output;
}

function transpile(source, isModule) {
  if (isModule && /(^|[^.\w$])(import|export)\s/.test(source)) {
    /* iOS 9 no entiende modulos y resolver imports por HTTP es otro juego. */
    return null;
  }
  try {
    const result = esbuild.transformSync(source, {
      loader: 'js',
      target: 'safari9',
      format: isModule ? 'iife' : 'preserve',
      sourcemap: false,
      legalComments: 'none'
    });
    return result.code;
  } catch (error) {
    log('esbuild:', error.message);
    return null;
  }
}

function relayShim(logicalURL) {
  const original = JSON.stringify(logicalURL);
  return [
    '(function(){',
    'var original=' + original + ';',
    'function parse(u){var a=document.createElement("a");a.href=u;return a;}',
    'var base=parse(original);',
    'var origin=base.protocol+"//"+base.host;',
    'function abs(u){try{return parse(u).href;}catch(e){return u;}}',
    'function same(u){try{var a=parse(u);return (a.protocol+"//"+a.host)===origin;}catch(e){return false;}}',
    'function prox(u){return "/api?u="+encodeURIComponent(u);}',
    'if(window.fetch){var f=window.fetch;',
    'window.fetch=function(input,init){try{',
    'var u=(typeof input==="string")?input:(input&&input.url);',
    'if(u){var a=abs(u);if(same(a)){var p=prox(a);',
    'if(typeof input==="string"){input=p;}else if(window.Request){input=new Request(p,input);}',
    '}}}catch(e){}return f.call(this,input,init);};}',
    'if(window.XMLHttpRequest){var xo=XMLHttpRequest.prototype.open;',
    'XMLHttpRequest.prototype.open=function(method,url){try{',
    'var a=abs(url);if(same(a)){url=prox(a);}}catch(e){}',
    'var args=[method,url].concat(Array.prototype.slice.call(arguments,2));',
    'return xo.apply(this,args);};}',
    'function logical(){try{var p=parse(location.href);',
    'if(/^\\/(browse|asset|api|submit)$/.test(p.pathname)){',
    'var m=p.search.match(/[?&]u=([^&]*)/);if(m){return decodeURIComponent(m[1]);}',
    '}}catch(e){}return original;}',
    'function notify(){try{if(window.top===window&&window.__IB_SET_LOGICAL_URL){',
    'window.__IB_SET_LOGICAL_URL(logical());}}catch(e){}}',
    'window.__IB_RELAY_LOGICAL__=logical;',
    'try{var push=history.pushState;history.pushState=function(){',
    'var r=push.apply(this,arguments);notify();return r;};',
    'var replace=history.replaceState;history.replaceState=function(){',
    'var r=replace.apply(this,arguments);notify();return r;};}catch(e){}',
    'window.addEventListener("popstate",notify);',
    'window.addEventListener("hashchange",notify);',
    'window.addEventListener("load",notify);',
    'notify();',
    '})();'
  ].join('');
}

function rewriteHTML(html, target) {
  const $ = cheerio.load(html, { decodeEntities: false });

  let base = target.href;
  const baseElement = $('base[href]').first();
  if (baseElement.length) {
    const resolved = absolute(baseElement.attr('href'), target.href);
    if (resolved) { base = resolved; }
  }
  $('base').remove();

  $('meta').each(function (_, element) {
    const equiv = $(element).attr('http-equiv');
    if (equiv && /content-security-policy/i.test(equiv)) {
      $(element).remove();
    }
  });

  $('script[integrity], link[integrity]').removeAttr('integrity');
  $('script[nonce], link[nonce]').removeAttr('nonce');
  $('[crossorigin]').removeAttr('crossorigin');

  $('a[href], area[href]').each(function (_, element) {
    const href = $(element).attr('href');
    if (href && !skipProxy(href) && href.charAt(0) !== '#') {
      $(element).attr('href', proxyURL('browse', href, base));
    }
  });

  $('form').each(function (_, element) {
    const form = $(element);
    const action = form.attr('action') || base;
    const method = String(form.attr('method') || 'get').toLowerCase();
    const kind = method === 'post' ? 'submit' : 'browse';
    form.attr('action', proxyURL(kind, action, base));
  });

  $('img[src], script[src], iframe[src], source[src], video[src], audio[src],' +
    'track[src], embed[src], input[type="image"][src]').each(function (_, element) {
    const node = $(element);
    const src = node.attr('src');
    if (src) {
      let replacement = proxyURL('asset', src, base);
      const type = String(node.attr('type') || '');
      if (element.tagName === 'script' && /module/i.test(type)) {
        replacement += (replacement.indexOf('?') === -1 ? '?' : '&') + 'm=1';
      }
      node.attr('src', replacement);
    }
  });

  $('link[href]').each(function (_, element) {
    const href = $(element).attr('href');
    if (href) { $(element).attr('href', proxyURL('asset', href, base)); }
  });

  $('img[srcset], source[srcset]').each(function (_, element) {
    const value = $(element).attr('srcset');
    if (value) { $(element).attr('srcset', rewriteSrcset(value, base)); }
  });

  $('video[poster]').each(function (_, element) {
    const poster = $(element).attr('poster');
    if (poster) { $(element).attr('poster', proxyURL('asset', poster, base)); }
  });

  $('object[data]').each(function (_, element) {
    const data = $(element).attr('data');
    if (data) { $(element).attr('data', proxyURL('asset', data, base)); }
  });

  $('style').each(function (_, element) {
    const css = $(element).html();
    if (css) { $(element).text(rewriteCSS(css, base)); }
  });

  $('[style]').each(function (_, element) {
    const style = $(element).attr('style');
    if (style) { $(element).attr('style', rewriteCSS(style, base)); }
  });

  $('script').each(function (_, element) {
    const node = $(element);
    if (node.attr('src')) { return; }

    const type = String(node.attr('type') || '');
    if (type && !/javascript|ecmascript|module/i.test(type)) { return; }

    const source = node.html();
    if (!source) { return; }

    const isModule = /module/i.test(type);
    const compiled = transpile(source, isModule);
    if (compiled == null) { return; }

    node.text(compiled);
    if (isModule) { node.attr('type', 'text/javascript'); }
  });

  if (!$('meta[name="viewport"]').length) {
    $('head').prepend('<meta name="viewport" content="width=device-width, initial-scale=1">');
  }

  const shim = '<script>' + relayShim(target.href) + '</script>';
  if ($('head').length) {
    $('head').prepend(shim);
  } else {
    $('html').prepend('<head>' + shim + '</head>');
  }

  $('body').append('<script>' +
    'window.addEventListener("DOMContentLoaded",function(){try{' +
    'if(window.top===window&&window.__IB_SET_LOGICAL_URL){' +
    'window.__IB_SET_LOGICAL_URL((window.__IB_RELAY_LOGICAL__||function(){' +
    'return location.href;})());}}catch(e){}});</script>');

  return $.html();
}

function sendBuffer(response, status, headers, buffer, method) {
  const output = Object.assign({
    'X-IBrowse-Relay': VERSION,
    'Cache-Control': 'no-store'
  }, headers || {});

  if (buffer) { output['Content-Length'] = buffer.length; }
  response.writeHead(status, output);
  if (method === 'HEAD' || !buffer) {
    response.end();
  } else {
    response.end(buffer);
  }
}

function sendError(response, status, message, extra) {
  const html = '<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<style>body{margin:0;padding:40px 24px;font-family:-apple-system,' +
    'Helvetica,Arial,sans-serif;background:#0a1020;color:#eaf2ff;line-height:1.5}' +
    'h1{font-size:22px;margin:0 0 12px}p{color:#a9b8d6;font-size:15px}' +
    'code{background:rgba(255,255,255,.08);padding:2px 6px;border-radius:4px}' +
    'a{color:#7fb2ff}</style></head><body><h1>IBrowse Relay</h1><p>' +
    escapeHTML(message) + '</p>' + (extra ? '<p>' + extra + '</p>' : '') +
    '</body></html>';
  sendBuffer(response, status, {
    'Content-Type': 'text/html; charset=utf-8'
  }, Buffer.from(html, 'utf8'));
}

async function handleBrowse(request, response, target) {
  log('browse', request.method, target.href);
  const fetched = await fetchTarget(target, {
    method: 'GET',
    headers: { accept: 'text/html,application/xhtml+xml,*/*;q=0.8' }
  });

  if (fetched.status >= 300 && fetched.status < 400) {
    const location = fetched.headers.get('location');
    if (location) {
      const next = absolute(location, target.href);
      if (next) {
        sendBuffer(response, 302, {
          'Location': '/browse?u=' + encodeURIComponent(next)
        }, Buffer.from('Redirigiendo…', 'utf8'), request.method);
        return;
      }
    }
  }

  if (fetched.status === 204 || fetched.status === 304) {
    sendBuffer(response, fetched.status, {}, null, request.method);
    return;
  }

  const contentType = fetched.headers.get('content-type') || 'text/html';
  const buffer = await readBody(fetched);

  if (!isHTML(contentType)) {
    const headers = { 'Content-Type': contentType };
    const disposition = fetched.headers.get('content-disposition');
    if (disposition) { headers['Content-Disposition'] = disposition; }
    sendBuffer(response, fetched.status, headers, buffer, request.method);
    return;
  }

  const html = decodeBuffer(buffer, contentType);
  let rewritten;
  try {
    rewritten = rewriteHTML(html, target);
  } catch (error) {
    log('rewrite error:', error.message);
    sendError(response, 502, 'La pagina se descargo, pero no se pudo reescribir: ' +
              error.message);
    return;
  }

  sendBuffer(response, 200, {
    'Content-Type': 'text/html; charset=utf-8'
  }, Buffer.from(rewritten, 'utf8'), request.method);
}

async function handleAsset(request, response, target, isModule) {
  log('asset', target.href);
  const fetched = await fetchTarget(target, {
    method: 'GET',
    headers: { accept: '*/*' }
  });

  if (fetched.status >= 300 && fetched.status < 400) {
    const location = fetched.headers.get('location');
    if (location) {
      const next = absolute(location, target.href);
      if (next) {
        sendBuffer(response, 302, {
          'Location': '/asset?u=' + encodeURIComponent(next)
        }, null, request.method);
        return;
      }
    }
  }

  const contentType = fetched.headers.get('content-type') || 'application/octet-stream';
  const buffer = await readBody(fetched);

  if (isJavaScript(contentType, target.href)) {
    const source = buffer.toString('utf8');
    const compiled = transpile(source, Boolean(isModule));
    if (compiled != null) {
      sendBuffer(response, 200, {
        'Content-Type': 'text/javascript; charset=utf-8'
      }, Buffer.from(compiled, 'utf8'), request.method);
      return;
    }
  }

  if (isCSS(contentType, target.href)) {
    const css = decodeBuffer(buffer, contentType);
    const rewritten = rewriteCSS(css, target.href);
    sendBuffer(response, 200, {
      'Content-Type': 'text/css; charset=utf-8'
    }, Buffer.from(rewritten, 'utf8'), request.method);
    return;
  }

  if (isHTML(contentType)) {
    const html = decodeBuffer(buffer, contentType);
    try {
      sendBuffer(response, 200, {
        'Content-Type': 'text/html; charset=utf-8'
      }, Buffer.from(rewriteHTML(html, target), 'utf8'), request.method);
      return;
    } catch (error) {
      log('iframe rewrite error:', error.message);
    }
  }

  const headers = { 'Content-Type': contentType };
  const disposition = fetched.headers.get('content-disposition');
  if (disposition) { headers['Content-Disposition'] = disposition; }
  sendBuffer(response, fetched.status, headers, buffer, request.method);
}

async function handleAPI(request, response, target) {
  log('api', request.method, target.href);

  let body;
  const headers = {};
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    body = await readRequestBody(request);
    if (request.headers['content-type']) {
      headers['content-type'] = request.headers['content-type'];
    }
  }
  if (request.headers.accept) { headers.accept = request.headers.accept; }
  headers.referer = target.href;
  headers.origin = target.origin;

  const fetched = await fetchTarget(target, {
    method: request.method === 'HEAD' ? 'GET' : request.method,
    headers: headers,
    body: body
  });

  if (fetched.status >= 300 && fetched.status < 400) {
    const location = fetched.headers.get('location');
    if (location) {
      const next = absolute(location, target.href);
      if (next) {
        sendBuffer(response, fetched.status, {
          'Location': '/api?u=' + encodeURIComponent(next)
        }, null, request.method);
        return;
      }
    }
  }

  const contentType = fetched.headers.get('content-type') || 'application/octet-stream';
  const buffer = await readBody(fetched);
  sendBuffer(response, fetched.status, {
    'Content-Type': contentType
  }, buffer, request.method);
}

async function handleSubmit(request, response, target) {
  log('submit', target.href);

  const body = await readRequestBody(request);
  const headers = {
    'content-type': request.headers['content-type'] || 'application/x-www-form-urlencoded',
    'referer': target.href,
    'origin': target.origin
  };

  const fetched = await fetchTarget(target, {
    method: 'POST',
    headers: headers,
    body: body
  });

  if (fetched.status >= 300 && fetched.status < 400) {
    const location = fetched.headers.get('location');
    if (location) {
      const next = absolute(location, target.href);
      if (next) {
        sendBuffer(response, 303, {
          'Location': '/browse?u=' + encodeURIComponent(next)
        }, Buffer.from('Redirigiendo…', 'utf8'), request.method);
        return;
      }
    }
  }

  const contentType = fetched.headers.get('content-type') || 'text/html';
  const buffer = await readBody(fetched);

  if (!isHTML(contentType)) {
    sendBuffer(response, fetched.status, {
      'Content-Type': contentType
    }, buffer, request.method);
    return;
  }

  const html = decodeBuffer(buffer, contentType);
  const rewritten = rewriteHTML(html, target);
  sendBuffer(response, 200, {
    'Content-Type': 'text/html; charset=utf-8'
  }, Buffer.from(rewritten, 'utf8'), request.method);
}

function lanAddresses() {
  const result = [];
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const entry of interfaces[name] || []) {
      if (entry.family === 'IPv4' && !entry.internal) {
        result.push(entry.address);
      }
    }
  }
  return result;
}

const server = http.createServer(function (request, response) {
  let requestURL;
  try {
    requestURL = new URL(request.url, 'http://relay.local');
  } catch (error) {
    sendError(response, 400, 'Peticion no valida.');
    return;
  }

  if (requestURL.pathname === '/health') {
    const payload = JSON.stringify({
      ok: true,
      app: 'ibrowse-relay',
      version: VERSION,
      node: process.version,
      privateAllowed: ALLOW_PRIVATE
    });
    sendBuffer(response, 200, {
      'Content-Type': 'application/json; charset=utf-8'
    }, Buffer.from(payload, 'utf8'), request.method);
    return;
  }

  if (requestURL.pathname === '/') {
    const addresses = lanAddresses();
    const list = addresses.length
      ? addresses.map(function (ip) {
          return '<li><code>http://' + ip + ':' + PORT + '</code></li>';
        }).join('')
      : '<li>Usa la IP local del PC.</li>';
    const html = '<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width, initial-scale=1">' +
      '<style>body{margin:0;padding:40px 24px;font-family:-apple-system,' +
      'Helvetica,Arial,sans-serif;background:#0a1020;color:#eaf2ff;line-height:1.55}' +
      'h1{margin:0 0 8px;font-size:26px}p,li{color:#a9b8d6;font-size:15px}' +
      'code{background:rgba(255,255,255,.08);padding:2px 6px;border-radius:4px}' +
      'a{color:#7fb2ff}</style></head><body><h1>IBrowse Relay</h1>' +
      '<p>Servidor activo. En IBrowse, Ajustes → Modo Relay, escribe una de estas ' +
      'direcciones:</p><ul>' + list + '</ul>' +
      '<p><a href="/health">Comprobar /health</a></p>' +
      '<p>Limite por respuesta: ' + Math.round(MAX_BYTES / 1024 / 1024) +
      ' MB. Las direcciones privadas estan ' + (ALLOW_PRIVATE ? 'permitidas' : 'bloqueadas') +
      '.</p></body></html>';
    sendBuffer(response, 200, {
      'Content-Type': 'text/html; charset=utf-8'
    }, Buffer.from(html, 'utf8'), request.method);
    return;
  }

  const known = ['/browse', '/asset', '/api', '/submit'];
  if (known.indexOf(requestURL.pathname) === -1) {
    sendError(response, 404, 'Ruta desconocida. Usa /browse?u=…, /asset?u=…, ' +
              '/api?u=… o /submit?u=…');
    return;
  }

  if (request.method !== 'GET' && request.method !== 'POST' &&
      request.method !== 'HEAD') {
    sendError(response, 405, 'Metodo no permitido.');
    return;
  }

  let target;
  try {
    target = targetFromRequest(requestURL);
  } catch (error) {
    sendError(response, 403, error.message);
    return;
  }

  if (!target) {
    sendError(response, 400, 'Falta el parametro u con una URL http(s) valida.');
    return;
  }

  const isModule = requestURL.searchParams.get('m') === '1';

  let work;
  if (requestURL.pathname === '/browse') {
    work = handleBrowse(request, response, target);
  } else if (requestURL.pathname === '/asset') {
    work = handleAsset(request, response, target, isModule);
  } else if (requestURL.pathname === '/api') {
    work = handleAPI(request, response, target);
  } else {
    work = handleSubmit(request, response, target);
  }

  Promise.resolve(work).catch(function (error) {
    log('error:', error && error.stack ? error.stack : error);
    if (!response.headersSent) {
      sendError(response, 502, 'No se pudo completar la peticion: ' +
                (error && error.message ? error.message : 'error desconocido'),
                'Comprueba la conexion del PC y que la web siga disponible.');
    } else {
      response.end();
    }
  });
});

server.listen(PORT, HOST, function () {
  console.log('');
  console.log('  IBrowse Relay ' + VERSION + ' escuchando en ' + HOST + ':' + PORT);
  const addresses = lanAddresses();
  if (addresses.length) {
    console.log('  En IBrowse → Ajustes → Modo Relay usa:');
    for (const ip of addresses) {
      console.log('    http://' + ip + ':' + PORT);
    }
  }
  console.log('  Salud: /health · Privadas: ' + (ALLOW_PRIVATE ? 'permitidas' : 'bloqueadas'));
  console.log('');
});

process.on('SIGINT', function () {
  console.log('\nCerrando relay…');
  server.close(function () { process.exit(0); });
});
