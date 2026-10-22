/*
 * IBrowse — puente JS -> nativo.
 * ES5 a propósito: este código se ejecuta en el WebKit de iOS 9.
 */
(function () {
    'use strict';

    if (window.__IB_BRIDGE__) { return; }
    window.__IB_BRIDGE__ = true;

    function post(obj) {
        try {
            if (window.webkit && window.webkit.messageHandlers &&
                window.webkit.messageHandlers.ibrowse) {
                window.webkit.messageHandlers.ibrowse.postMessage(obj);
            }
        } catch (e) { /* la página no es nuestra: silencio */ }
    }

    function absolute(url) {
        try {
            var a = document.createElement('a');
            a.href = url;
            return a.href;
        } catch (e) { return url; }
    }

    function isBinary(url) {
        return /\.(zip|ipa|dmg|pkg|exe|msi|apk|tar|gz|tgz|7z|rar|iso|bin|crx|xpi|epub|mobi)(\?|#|$)/i.test(url);
    }

    function isExternal(url) {
        return /^(mailto:|tel:|sms:|itms-apps:|itms-services:|facetime:|maps:)/i.test(url);
    }

    /* Errores de JavaScript de la página: se registran en el log del iPad.
       Sin esto, una página en blanco no da ninguna pista. */
    window.addEventListener('error', function (ev) {
        post({
            type: 'jserror',
            message: String(ev.message || ''),
            source: String(ev.filename || ''),
            line: ev.lineno || 0,
            page: String(location.href || '')
        });
    }, true);

    /* Enlaces de descarga: el WKWebView de iOS 9 no descarga por su cuenta. */
    document.addEventListener('click', function (ev) {
        if (ev.defaultPrevented || ev.button !== 0 ||
            ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.altKey) {
            return;
        }

        var node = ev.target;
        while (node && node.tagName && node.tagName.toLowerCase() !== 'a') {
            node = node.parentNode;
        }
        if (!node || !node.getAttribute) { return; }

        var href = node.getAttribute('href');
        if (!href || href.charAt(0) === '#') { return; }

        var url = absolute(href);
        if (isExternal(url)) {
            ev.preventDefault();
            post({ type: 'external', url: url });
            return;
        }

        if (node.hasAttribute('download') || isBinary(url)) {
            ev.preventDefault();
            post({
                type: 'download',
                url: url,
                filename: node.getAttribute('download') || ''
            });
        }
    }, true);

    /* El relay avisa de la URL "real" cuando la barra de direcciones no puede
       verla (la página se sirve desde el PC). */
    window.__IB_SET_LOGICAL_URL = function (url) {
        if (!url || window.top !== window) { return; }
        post({ type: 'logicalURL', url: String(url) });
    };

    /* API para la página de inicio local. */
    window.__IB_START = {
        search: function (q) {
            q = (q || '').replace(/^\s+|\s+$/g, '');
            if (q) { post({ type: 'search', q: q }); }
        },
        go: function (url) {
            if (url) { post({ type: 'navigate', url: String(url) }); }
        },
        focusAddress: function () {
            post({ type: 'focusAddress' });
        }
    };

    function ready() {
        post({ type: 'ready' });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', ready);
    } else {
        ready();
    }
})();
