/*
 * IBrowse — bloqueo cosmético y de peticiones.
 * Se ejecuta antes que el resto de scripts de la página. ES5.
 *
 * iOS 9 no tiene WKContentRuleList ni interceptación de red en WKWebView.
 * Por eso el bloqueo es doble:
 *   1. se ocultan/eliminan nodos publicitarios del DOM;
 *   2. se anulan fetch/XHR/beacon hacia dominios de anuncios y analítica.
 * No es un adblock de red: las peticiones de <script src> e <img> ya
 * iniciadas por el HTML pueden salir. Para bloqueo real, usa el relay.
 */
(function () {
    'use strict';

    var cfg = window.__IB_CONFIG || { ads: true, trackers: true };
    var ads = cfg.ads !== false;
    var trackers = cfg.trackers !== false;

    if (!ads && !trackers) { return; }

    var adHosts = [
        'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
        'adservice.google.com', 'pagead2.googlesyndication.com',
        'amazon-adsystem.com', 'moatads.com', 'adnxs.com', 'adsrvr.org',
        'rubiconproject.com', 'pubmatic.com', 'openx.net', 'casalemedia.com',
        'criteo.com', 'criteo.net', 'taboola.com', 'outbrain.com',
        'revcontent.com', 'mgid.com', 'zedo.com', 'adform.net',
        'smartadserver.com', 'teads.tv', 'spotxchange.com', 'yieldmo.com',
        'sharethrough.com', 'gumgum.com', 'indexww.com', '33across.com'
    ];

    var trackerHosts = [
        'google-analytics.com', 'googletagmanager.com', 'googletagservices.com',
        'connect.facebook.net', 'facebook.com/tr', 'analytics.twitter.com',
        'static.ads-twitter.com', 'bat.bing.com', 'clarity.ms',
        'hotjar.com', 'hotjar.io', 'mixpanel.com', 'segment.io',
        'segment.com', 'amplitude.com', 'fullstory.com', 'quantumMetric.com',
        'quantserve.com', 'scorecardresearch.com', 'chartbeat.com',
        'parsely.com', 'newrelic.com', 'nr-data.net', 'bugsnag.com'
    ];

    function hostOf(url) {
        try {
            var a = document.createElement('a');
            a.href = url;
            return (a.hostname || '').toLowerCase();
        } catch (e) { return ''; }
    }

    function matches(host, list) {
        if (!host) { return false; }
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (host === d) { return true; }
            if (d.indexOf('/') !== -1) {
                if ((host + '/').indexOf(d) === 0) { return true; }
            } else if (host.length > d.length &&
                       host.slice(-(d.length + 1)) === '.' + d) {
                return true;
            }
        }
        return false;
    }

    function blocked(url) {
        if (!url) { return false; }
        var s = String(url);
        if (s.indexOf('http') !== 0 && s.indexOf('//') !== 0) { return false; }
        var h = hostOf(s);
        if (!h) { return false; }
        if (ads && matches(h, adHosts)) { return true; }
        if (trackers && matches(h, trackerHosts)) { return true; }
        return false;
    }

    /* --- XHR --- */
    var xhrOpen = XMLHttpRequest.prototype.open;
    var xhrSend = XMLHttpRequest.prototype.send;

    XMLHttpRequest.prototype.open = function (method, url) {
        this.__ibBlocked = blocked(url);
        this.__ibURL = url;
        if (this.__ibBlocked) { return; }
        return xhrOpen.apply(this, arguments);
    };

    XMLHttpRequest.prototype.send = function () {
        if (this.__ibBlocked) {
            var self = this;
            setTimeout(function () {
                try {
                    var ev = document.createEvent('Event');
                    ev.initEvent('error', false, false);
                    self.dispatchEvent(ev);
                    var ev2 = document.createEvent('Event');
                    ev2.initEvent('loadend', false, false);
                    self.dispatchEvent(ev2);
                } catch (e) { /* nada */ }
            }, 0);
            return;
        }
        return xhrSend.apply(this, arguments);
    };

    /* --- fetch --- */
    if (typeof window.fetch === 'function') {
        var nativeFetch = window.fetch;
        window.fetch = function (input, init) {
            var url = (typeof input === 'string') ? input :
                      (input && input.url ? input.url : '');
            if (blocked(url)) {
                return Promise.reject(new TypeError('Bloqueado por IBrowse'));
            }
            return nativeFetch.apply(this, arguments);
        };
    }

    /* --- beacon --- */
    if (navigator.sendBeacon) {
        var nativeBeacon = navigator.sendBeacon;
        navigator.sendBeacon = function (url, data) {
            if (blocked(url)) { return false; }
            return nativeBeacon.call(navigator, url, data);
        };
    }

    /* --- cosmético --- */
    var selectors = [];
    if (ads) {
        selectors = [
            '.adsbygoogle', '.advertisement', '.advertising', '.ad-container',
            '.ad-slot', '.ad-unit', '.ad-wrapper', '.ad-banner', '.ad-label',
            '.sponsored-content', '.sponsored-post', '.promoted-content',
            '.taboola', '.trc_related_container', '.OUTBRAIN',
            '.outbrain-container', '[id^="google_ads"]', '[id^="div-gpt-ad"]',
            '[id^="ad-slot"]', '[id^="ad-slot-"]', '[data-ad-slot]',
            '[data-ad-unit]', '[data-ad-client]', 'iframe[src*="doubleclick.net"]',
            'iframe[src*="googlesyndication.com"]',
            'iframe[src*="amazon-adsystem.com"]',
            'iframe[src*="adnxs.com"]', 'iframe[src*="criteo"]'
        ];
    }

    function clean(root) {
        if (!root || !root.querySelectorAll || !selectors.length) { return; }
        var nodes;
        try { nodes = root.querySelectorAll(selectors.join(',')); }
        catch (e) { return; }

        for (var i = 0; i < nodes.length; i++) {
            var el = nodes[i];
            if (!el || !el.style) { continue; }
            if (el.tagName && el.tagName.toLowerCase() === 'iframe') {
                try { el.parentNode.removeChild(el); } catch (e2) { }
            } else {
                el.style.setProperty('display', 'none', 'important');
                el.setAttribute('data-ibrowse-hidden', '1');
            }
        }
    }

    function start() {
        clean(document);
        if (!window.MutationObserver || !document.documentElement) { return; }
        var obs = new MutationObserver(function (mutations) {
            for (var i = 0; i < mutations.length; i++) {
                var added = mutations[i].addedNodes;
                for (var j = 0; j < added.length; j++) {
                    if (added[j].nodeType === 1) { clean(added[j]); }
                }
            }
        });
        obs.observe(document.documentElement, { childList: true, subtree: true });
    }

    if (selectors.length) {
        var css = selectors.join(',') + '{display:none !important;}';
        var style = document.createElement('style');
        style.type = 'text/css';
        try { style.appendChild(document.createTextNode(css)); } catch (e) { }
        var parent = document.head || document.documentElement;
        if (parent) { parent.appendChild(style); }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }
})();
