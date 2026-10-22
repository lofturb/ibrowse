/*
 * IBrowse — polyfills para WebKit de iOS 9 (Safari 9).
 *
 * Objetivo: que las webs modernas que sólo fallan por APIs ausentes
 * (fetch, URLSearchParams, IntersectionObserver, TextEncoder...) puedan
 * arrancar. NO puede arreglar sintaxis moderna (async/await, ?., ??),
 * módulos ES, WebAssembly, Web Components ni service workers: eso lo hace
 * el relay del PC.
 *
 * Todo el archivo es ES5 estricto. No usa let/const, arrow functions,
 * template literals ni clases.
 */
(function (global) {
    'use strict';

    var define = function (obj, name, value) {
        try {
            Object.defineProperty(obj, name, {
                value: value,
                writable: true,
                configurable: true,
                enumerable: false
            });
        } catch (e) {
            try { obj[name] = value; } catch (e2) { }
        }
    };

    var hasOwn = Object.prototype.hasOwnProperty;
    var toStr = Object.prototype.toString;

    function isCallable(fn) {
        return typeof fn === 'function' ||
               toStr.call(fn) === '[object Function]';
    }

    function toInteger(value) {
        var n = Number(value);
        if (isNaN(n)) { return 0; }
        if (n === 0 || n === Infinity || n === -Infinity) { return n; }
        return (n > 0 ? 1 : -1) * Math.floor(Math.abs(n));
    }

    function toLength(value) {
        var n = toInteger(value);
        if (n <= 0) { return 0; }
        return Math.min(n, 9007199254740991);
    }

    /* ------------------------------------------------------------------ */
    /* Object                                                              */
    /* ------------------------------------------------------------------ */

    if (!Object.assign) {
        define(Object, 'assign', function (target) {
            if (target == null) {
                throw new TypeError('Cannot convert undefined or null to object');
            }
            var to = Object(target);
            for (var i = 1; i < arguments.length; i++) {
                var source = arguments[i];
                if (source == null) { continue; }
                var keys = Object.keys(Object(source));
                for (var j = 0; j < keys.length; j++) {
                    to[keys[j]] = source[keys[j]];
                }
            }
            return to;
        });
    }

    if (!Object.is) {
        define(Object, 'is', function (a, b) {
            if (a === b) { return a !== 0 || 1 / a === 1 / b; }
            return a !== a && b !== b;
        });
    }

    if (!Object.entries) {
        define(Object, 'entries', function (obj) {
            var keys = Object.keys(Object(obj));
            var out = [];
            for (var i = 0; i < keys.length; i++) {
                out.push([keys[i], obj[keys[i]]]);
            }
            return out;
        });
    }

    if (!Object.values) {
        define(Object, 'values', function (obj) {
            var keys = Object.keys(Object(obj));
            var out = [];
            for (var i = 0; i < keys.length; i++) {
                out.push(obj[keys[i]]);
            }
            return out;
        });
    }

    if (!Object.fromEntries) {
        define(Object, 'fromEntries', function (entries) {
            var obj = {};
            if (!entries) { return obj; }
            for (var i = 0; i < entries.length; i++) {
                var pair = entries[i];
                if (!pair) { continue; }
                obj[pair[0]] = pair[1];
            }
            return obj;
        });
    }

    if (!Object.hasOwn) {
        define(Object, 'hasOwn', function (obj, key) {
            return hasOwn.call(Object(obj), key);
        });
    }

    /* ------------------------------------------------------------------ */
    /* Array                                                               */
    /* ------------------------------------------------------------------ */

    if (!Array.from) {
        define(Array, 'from', function (arrayLike, mapFn, thisArg) {
            var out = [];
            if (arrayLike == null) { return out; }
            var i = 0;
            var iteratorKey = (typeof Symbol !== 'undefined' && Symbol.iterator) ?
                              Symbol.iterator : null;
            var iterator = iteratorKey ? arrayLike[iteratorKey] : null;

            if (iterator && isCallable(iterator) &&
                typeof arrayLike.length !== 'number') {
                var iter = iterator.call(arrayLike);
                var step;
                while (!(step = iter.next()).done) {
                    out.push(mapFn ? mapFn.call(thisArg, step.value, i) : step.value);
                    i++;
                }
                return out;
            }

            var len = toLength(arrayLike.length);
            for (; i < len; i++) {
                var value = arrayLike[i];
                out.push(mapFn ? mapFn.call(thisArg, value, i) : value);
            }
            return out;
        });
    }

    if (!Array.of) {
        define(Array, 'of', function () {
            return Array.prototype.slice.call(arguments);
        });
    }

    if (!Array.prototype.includes) {
        define(Array.prototype, 'includes', function (search, fromIndex) {
            var len = toLength(this.length);
            if (len === 0) { return false; }
            var k = toInteger(fromIndex);
            if (k < 0) { k = Math.max(len + k, 0); }
            for (; k < len; k++) {
                var value = this[k];
                if (value === search ||
                    (value !== value && search !== search)) {
                    return true;
                }
            }
            return false;
        });
    }

    if (!Array.prototype.find) {
        define(Array.prototype, 'find', function (predicate, thisArg) {
            var len = toLength(this.length);
            for (var i = 0; i < len; i++) {
                var value = this[i];
                if (predicate.call(thisArg, value, i, this)) { return value; }
            }
            return undefined;
        });
    }

    if (!Array.prototype.findIndex) {
        define(Array.prototype, 'findIndex', function (predicate, thisArg) {
            var len = toLength(this.length);
            for (var i = 0; i < len; i++) {
                if (predicate.call(thisArg, this[i], i, this)) { return i; }
            }
            return -1;
        });
    }

    if (!Array.prototype.fill) {
        define(Array.prototype, 'fill', function (value, start, end) {
            var len = toLength(this.length);
            var k = toInteger(start);
            var fin = end === undefined ? len : toInteger(end);
            k = k < 0 ? Math.max(len + k, 0) : Math.min(k, len);
            fin = fin < 0 ? Math.max(len + fin, 0) : Math.min(fin, len);
            for (; k < fin; k++) { this[k] = value; }
            return this;
        });
    }

    if (!Array.prototype.flat) {
        define(Array.prototype, 'flat', function (depth) {
            var d = depth === undefined ? 1 : toInteger(depth);
            var out = [];
            function flatten(input, level) {
                for (var i = 0; i < input.length; i++) {
                    var value = input[i];
                    if (level > 0 && Array.isArray(value)) {
                        flatten(value, level - 1);
                    } else if (value !== undefined) {
                        out.push(value);
                    }
                }
            }
            flatten(this, d < 0 ? 0 : d);
            return out;
        });
    }

    if (!Array.prototype.flatMap) {
        define(Array.prototype, 'flatMap', function (mapper, thisArg) {
            var mapped = [];
            for (var i = 0; i < this.length; i++) {
                mapped.push(mapper.call(thisArg, this[i], i, this));
            }
            return Array.prototype.flat.call(mapped, 1);
        });
    }

    if (!Array.prototype.at) {
        define(Array.prototype, 'at', function (index) {
            var len = toLength(this.length);
            var k = toInteger(index);
            if (k < 0) { k = len + k; }
            if (k < 0 || k >= len) { return undefined; }
            return this[k];
        });
    }

    /* ------------------------------------------------------------------ */
    /* String                                                              */
    /* ------------------------------------------------------------------ */

    if (!String.prototype.includes) {
        define(String.prototype, 'includes', function (search, start) {
            if (search instanceof RegExp) {
                throw new TypeError('First argument must not be a RegExp');
            }
            return String(this).indexOf(String(search), start || 0) !== -1;
        });
    }

    if (!String.prototype.startsWith) {
        define(String.prototype, 'startsWith', function (search, position) {
            var str = String(this);
            var pos = toInteger(position);
            pos = pos < 0 ? 0 : Math.min(pos, str.length);
            return str.slice(pos, pos + String(search).length) === String(search);
        });
    }

    if (!String.prototype.endsWith) {
        define(String.prototype, 'endsWith', function (search, endPosition) {
            var str = String(this);
            var end = endPosition === undefined ? str.length : toInteger(endPosition);
            end = Math.min(Math.max(end, 0), str.length);
            var start = end - String(search).length;
            return start >= 0 && str.slice(start, end) === String(search);
        });
    }

    if (!String.prototype.repeat) {
        define(String.prototype, 'repeat', function (count) {
            var n = toInteger(count);
            if (n < 0 || n === Infinity) {
                throw new RangeError('Invalid count value');
            }
            var out = '';
            var str = String(this);
            for (var i = 0; i < n; i++) { out += str; }
            return out;
        });
    }

    if (!String.prototype.padStart) {
        define(String.prototype, 'padStart', function (targetLength, padString) {
            var str = String(this);
            var target = toLength(targetLength);
            if (str.length >= target) { return str; }
            var pad = padString === undefined ? ' ' : String(padString);
            if (!pad) { pad = ' '; }
            var fill = '';
            while (fill.length < target - str.length) { fill += pad; }
            return fill.slice(0, target - str.length) + str;
        });
    }

    if (!String.prototype.padEnd) {
        define(String.prototype, 'padEnd', function (targetLength, padString) {
            var str = String(this);
            var target = toLength(targetLength);
            if (str.length >= target) { return str; }
            var pad = padString === undefined ? ' ' : String(padString);
            if (!pad) { pad = ' '; }
            var fill = '';
            while (fill.length < target - str.length) { fill += pad; }
            return str + fill.slice(0, target - str.length);
        });
    }

    if (!String.prototype.trimStart) {
        define(String.prototype, 'trimStart', function () {
            return String(this).replace(/^\s+/, '');
        });
    }

    if (!String.prototype.trimEnd) {
        define(String.prototype, 'trimEnd', function () {
            return String(this).replace(/\s+$/, '');
        });
    }

    if (!String.prototype.at) {
        define(String.prototype, 'at', function (index) {
            var str = String(this);
            var k = toInteger(index);
            if (k < 0) { k = str.length + k; }
            if (k < 0 || k >= str.length) { return undefined; }
            return str.charAt(k);
        });
    }

    if (!String.prototype.replaceAll) {
        define(String.prototype, 'replaceAll', function (search, replacement) {
            if (search instanceof RegExp) {
                if (!search.global) {
                    throw new TypeError('replaceAll must be called with a global RegExp');
                }
                return String(this).replace(search, replacement);
            }
            return String(this).split(String(search)).join(String(replacement));
        });
    }

    if (!String.prototype.codePointAt) {
        define(String.prototype, 'codePointAt', function (position) {
            var str = String(this);
            var i = toInteger(position);
            if (i < 0 || i >= str.length) { return undefined; }
            var first = str.charCodeAt(i);
            if (first >= 0xD800 && first <= 0xDBFF && i + 1 < str.length) {
                var second = str.charCodeAt(i + 1);
                if (second >= 0xDC00 && second <= 0xDFFF) {
                    return (first - 0xD800) * 0x400 + second - 0xDC00 + 0x10000;
                }
            }
            return first;
        });
    }

    if (!String.fromCodePoint) {
        define(String, 'fromCodePoint', function () {
            var out = '';
            for (var i = 0; i < arguments.length; i++) {
                var cp = Number(arguments[i]);
                if (cp < 0 || cp > 0x10FFFF || cp !== Math.floor(cp)) {
                    throw new RangeError('Invalid code point');
                }
                if (cp <= 0xFFFF) {
                    out += String.fromCharCode(cp);
                } else {
                    cp -= 0x10000;
                    out += String.fromCharCode((cp >> 10) + 0xD800,
                                               (cp % 0x400) + 0xDC00);
                }
            }
            return out;
        });
    }

    /* ------------------------------------------------------------------ */
    /* Number / Math                                                       */
    /* ------------------------------------------------------------------ */

    if (!Number.isNaN) {
        define(Number, 'isNaN', function (value) {
            return typeof value === 'number' && value !== value;
        });
    }

    if (!Number.isFinite) {
        define(Number, 'isFinite', function (value) {
            return typeof value === 'number' && isFinite(value);
        });
    }

    if (!Number.isInteger) {
        define(Number, 'isInteger', function (value) {
            return typeof value === 'number' && isFinite(value) &&
                   Math.floor(value) === value;
        });
    }

    if (!Number.isSafeInteger) {
        define(Number, 'isSafeInteger', function (value) {
            return typeof value === 'number' && isFinite(value) &&
                   Math.floor(value) === value &&
                   Math.abs(value) <= 9007199254740991;
        });
    }

    if (!Number.MAX_SAFE_INTEGER) { Number.MAX_SAFE_INTEGER = 9007199254740991; }
    if (!Number.MIN_SAFE_INTEGER) { Number.MIN_SAFE_INTEGER = -9007199254740991; }
    if (!Number.EPSILON) { Number.EPSILON = Math.pow(2, -52); }
    if (!Number.parseInt) { define(Number, 'parseInt', global.parseInt); }
    if (!Number.parseFloat) { define(Number, 'parseFloat', global.parseFloat); }

    if (!Math.trunc) {
        define(Math, 'trunc', function (x) {
            return x < 0 ? Math.ceil(x) : Math.floor(x);
        });
    }

    if (!Math.sign) {
        define(Math, 'sign', function (x) {
            x = Number(x);
            if (x === 0 || x !== x) { return x; }
            return x > 0 ? 1 : -1;
        });
    }

    if (!Math.log2) {
        define(Math, 'log2', function (x) { return Math.log(x) / Math.LN2; });
    }

    if (!Math.log10) {
        define(Math, 'log10', function (x) { return Math.log(x) / Math.LN10; });
    }

    if (!Math.cbrt) {
        define(Math, 'cbrt', function (x) {
            return Math.pow(x, 1 / 3);
        });
    }

    if (!Math.hypot) {
        define(Math, 'hypot', function () {
            var sum = 0;
            for (var i = 0; i < arguments.length; i++) {
                var n = Number(arguments[i]);
                sum += n * n;
            }
            return Math.sqrt(sum);
        });
    }

    if (!Math.imul) {
        define(Math, 'imul', function (a, b) {
            var ah = (a >>> 16) & 0xFFFF;
            var al = a & 0xFFFF;
            var bh = (b >>> 16) & 0xFFFF;
            var bl = b & 0xFFFF;
            return ((al * bl) + (((ah * bl + al * bh) << 16) >>> 0) | 0);
        });
    }

    /* ------------------------------------------------------------------ */
    /* DOM                                                                 */
    /* ------------------------------------------------------------------ */

    if (global.Element) {
        if (!Element.prototype.matches) {
            var matchesSelector = Element.prototype.webkitMatchesSelector ||
                                  Element.prototype.mozMatchesSelector ||
                                  Element.prototype.msMatchesSelector;
            if (matchesSelector) {
                define(Element.prototype, 'matches', function (selector) {
                    return matchesSelector.call(this, selector);
                });
            }
        }

        if (!Element.prototype.closest) {
            define(Element.prototype, 'closest', function (selector) {
                var el = this;
                while (el && el.nodeType === 1) {
                    if (el.matches && el.matches(selector)) { return el; }
                    el = el.parentElement || el.parentNode;
                }
                return null;
            });
        }

        if (!Element.prototype.remove) {
            define(Element.prototype, 'remove', function () {
                if (this.parentNode) { this.parentNode.removeChild(this); }
            });
        }

        if (!Element.prototype.append) {
            define(Element.prototype, 'append', function () {
                for (var i = 0; i < arguments.length; i++) {
                    var node = arguments[i];
                    if (typeof node === 'string') {
                        node = document.createTextNode(node);
                    }
                    this.appendChild(node);
                }
            });
        }

        if (!Element.prototype.prepend) {
            define(Element.prototype, 'prepend', function () {
                var first = this.firstChild;
                for (var i = 0; i < arguments.length; i++) {
                    var node = arguments[i];
                    if (typeof node === 'string') {
                        node = document.createTextNode(node);
                    }
                    this.insertBefore(node, first);
                }
            });
        }

        if (!Element.prototype.replaceWith) {
            define(Element.prototype, 'replaceWith', function () {
                var parent = this.parentNode;
                if (!parent) { return; }
                var fragment = document.createDocumentFragment();
                for (var i = 0; i < arguments.length; i++) {
                    var node = arguments[i];
                    if (typeof node === 'string') {
                        node = document.createTextNode(node);
                    }
                    fragment.appendChild(node);
                }
                parent.replaceChild(fragment, this);
            });
        }

        if (!Element.prototype.getAttributeNames) {
            define(Element.prototype, 'getAttributeNames', function () {
                var out = [];
                for (var i = 0; i < this.attributes.length; i++) {
                    out.push(this.attributes[i].name);
                }
                return out;
            });
        }
    }

    if (global.NodeList && NodeList.prototype &&
        !NodeList.prototype.forEach) {
        define(NodeList.prototype, 'forEach', Array.prototype.forEach);
    }

    if (global.HTMLCollection && HTMLCollection.prototype &&
        !HTMLCollection.prototype.forEach) {
        define(HTMLCollection.prototype, 'forEach', Array.prototype.forEach);
    }

    if (global.Node && !('isConnected' in Node.prototype)) {
        try {
            Object.defineProperty(Node.prototype, 'isConnected', {
                get: function () {
                    var doc = this.ownerDocument;
                    return !!(doc && doc.documentElement &&
                              doc.documentElement.contains(this));
                },
                configurable: true
            });
        } catch (e) { }
    }

    /* ------------------------------------------------------------------ */
    /* Timing                                                              */
    /* ------------------------------------------------------------------ */

    var raf = global.requestAnimationFrame || global.webkitRequestAnimationFrame;
    if (!raf) {
        raf = function (callback) {
            return global.setTimeout(function () { callback(Date.now()); }, 16);
        };
        define(global, 'requestAnimationFrame', raf);
    }
    if (!global.cancelAnimationFrame) {
        var caf = global.cancelAnimationFrame || global.webkitCancelAnimationFrame;
        define(global, 'cancelAnimationFrame', function (id) {
            if (caf) { caf.call(global, id); }
            else { global.clearTimeout(id); }
        });
    }

    if (!global.performance) { global.performance = {}; }
    if (!global.performance.now) {
        var startTime = Date.now();
        global.performance.now = function () {
            return Date.now() - startTime;
        };
    }

    if (!global.globalThis) {
        try { global.globalThis = global; } catch (e) { }
    }

    if (!global.queueMicrotask) {
        define(global, 'queueMicrotask', function (fn) {
            Promise.resolve().then(fn);
        });
    }

    if (!global.requestIdleCallback) {
        define(global, 'requestIdleCallback', function (callback) {
            return global.setTimeout(function () {
                callback({
                    didTimeout: false,
                    timeRemaining: function () { return 50; }
                });
            }, 1);
        });
    }

    if (!global.cancelIdleCallback) {
        define(global, 'cancelIdleCallback', function (id) {
            global.clearTimeout(id);
        });
    }

    /* ------------------------------------------------------------------ */
    /* Promise extras                                                      */
    /* ------------------------------------------------------------------ */

    if (global.Promise) {
        if (!Promise.prototype.finally) {
            define(Promise.prototype, 'finally', function (callback) {
                var P = this.constructor || Promise;
                return this.then(function (value) {
                    return P.resolve(callback()).then(function () {
                        return value;
                    });
                }, function (reason) {
                    return P.resolve(callback()).then(function () {
                        throw reason;
                    });
                });
            });
        }

        if (!Promise.allSettled) {
            define(Promise, 'allSettled', function (iterable) {
                var items = Array.prototype.slice.call(iterable);
                return Promise.all(items.map(function (item) {
                    return Promise.resolve(item).then(function (value) {
                        return { status: 'fulfilled', value: value };
                    }, function (reason) {
                        return { status: 'rejected', reason: reason };
                    });
                }));
            });
        }

        if (!Promise.any) {
            define(Promise, 'any', function (iterable) {
                var items = Array.prototype.slice.call(iterable);
                return new Promise(function (resolve, reject) {
                    if (!items.length) {
                        reject(new Error('All promises were rejected'));
                        return;
                    }
                    var pending = items.length;
                    items.forEach(function (item) {
                        Promise.resolve(item).then(resolve, function () {
                            pending--;
                            if (pending === 0) {
                                reject(new Error('All promises were rejected'));
                            }
                        });
                    });
                });
            });
        }

        if (!Promise.withResolvers) {
            define(Promise, 'withResolvers', function () {
                var resolve, reject;
                var promise = new Promise(function (res, rej) {
                    resolve = res;
                    reject = rej;
                });
                return { promise: promise, resolve: resolve, reject: reject };
            });
        }
    }

    /* ------------------------------------------------------------------ */
    /* TextEncoder / TextDecoder                                           */
    /* ------------------------------------------------------------------ */

    function utf8Decode(bytes) {
        var out = '';
        var i = 0;
        var len = bytes.length;
        while (i < len) {
            var c = bytes[i++];
            if (c < 0x80) {
                out += String.fromCharCode(c);
            } else if (c >= 0xC2 && c < 0xE0 && i < len) {
                out += String.fromCharCode(((c & 0x1F) << 6) | (bytes[i++] & 0x3F));
            } else if (c >= 0xE0 && c < 0xF0 && i + 1 < len) {
                var c2 = bytes[i++];
                var c3 = bytes[i++];
                out += String.fromCharCode(((c & 0x0F) << 12) |
                                           ((c2 & 0x3F) << 6) |
                                           (c3 & 0x3F));
            } else if (c >= 0xF0 && c < 0xF5 && i + 2 < len) {
                var b2 = bytes[i++];
                var b3 = bytes[i++];
                var b4 = bytes[i++];
                var cp = ((c & 0x07) << 18) |
                         ((b2 & 0x3F) << 12) |
                         ((b3 & 0x3F) << 6) |
                         (b4 & 0x3F);
                if (cp > 0x10FFFF) {
                    out += '\uFFFD';
                } else {
                    cp -= 0x10000;
                    out += String.fromCharCode((cp >> 10) + 0xD800,
                                               (cp % 0x400) + 0xDC00);
                }
            } else {
                out += '\uFFFD';
            }
        }
        return out;
    }

    function utf8Encode(str) {
        var out = [];
        var i = 0;
        while (i < str.length) {
            var c = str.charCodeAt(i++);
            if (c < 0x80) {
                out.push(c);
            } else if (c < 0x800) {
                out.push(0xC0 | (c >> 6), 0x80 | (c & 0x3F));
            } else if (c >= 0xD800 && c <= 0xDBFF && i < str.length) {
                var next = str.charCodeAt(i);
                if (next >= 0xDC00 && next <= 0xDFFF) {
                    i++;
                    var cp = 0x10000 + ((c - 0xD800) << 10) + (next - 0xDC00);
                    out.push(0xF0 | (cp >> 18),
                             0x80 | ((cp >> 12) & 0x3F),
                             0x80 | ((cp >> 6) & 0x3F),
                             0x80 | (cp & 0x3F));
                } else {
                    out.push(0xEF, 0xBF, 0xBD);
                }
            } else {
                out.push(0xE0 | (c >> 12),
                         0x80 | ((c >> 6) & 0x3F),
                         0x80 | (c & 0x3F));
            }
        }
        return new Uint8Array(out);
    }

    if (!global.TextDecoder) {
        var TextDecoderPolyfill = function (encoding) {
            this.encoding = encoding || 'utf-8';
        };
        TextDecoderPolyfill.prototype.decode = function (input) {
            if (input === undefined) { return ''; }
            if (typeof input === 'string') { return input; }
            if (input instanceof ArrayBuffer) {
                input = new Uint8Array(input);
            } else if (input && input.buffer instanceof ArrayBuffer) {
                input = new Uint8Array(input.buffer, input.byteOffset,
                                       input.byteLength);
            }
            return utf8Decode(input);
        };
        global.TextDecoder = TextDecoderPolyfill;
    }

    if (!global.TextEncoder) {
        var TextEncoderPolyfill = function () {
            this.encoding = 'utf-8';
        };
        TextEncoderPolyfill.prototype.encode = function (str) {
            return utf8Encode(String(str === undefined ? '' : str));
        };
        global.TextEncoder = TextEncoderPolyfill;
    }

    /* ------------------------------------------------------------------ */
    /* URLSearchParams                                                     */
    /* ------------------------------------------------------------------ */

    function decodePart(value) {
        try {
            return decodeURIComponent(String(value).replace(/\+/g, ' '));
        } catch (e) {
            return String(value);
        }
    }

    function encodePart(value) {
        return encodeURIComponent(String(value)).replace(/%20/g, '+');
    }

    if (!global.URLSearchParams) {
        var URLSearchParamsPolyfill = function (init) {
            this._pairs = [];
            if (!init) { return; }
            if (typeof init === 'string') {
                var text = init.charAt(0) === '?' ? init.slice(1) : init;
                if (!text) { return; }
                var parts = text.split('&');
                for (var i = 0; i < parts.length; i++) {
                    if (!parts[i]) { continue; }
                    var eq = parts[i].indexOf('=');
                    var name = eq === -1 ? parts[i] : parts[i].slice(0, eq);
                    var value = eq === -1 ? '' : parts[i].slice(eq + 1);
                    this._pairs.push([decodePart(name), decodePart(value)]);
                }
            } else if (init instanceof URLSearchParamsPolyfill) {
                for (var j = 0; j < init._pairs.length; j++) {
                    this._pairs.push([init._pairs[j][0], init._pairs[j][1]]);
                }
            } else if (Object.prototype.toString.call(init) === '[object Array]') {
                for (var k = 0; k < init.length; k++) {
                    this._pairs.push([String(init[k][0]), String(init[k][1])]);
                }
            } else {
                var keys = Object.keys(init);
                for (var m = 0; m < keys.length; m++) {
                    this._pairs.push([keys[m], String(init[keys[m]])]);
                }
            }
        };

        URLSearchParamsPolyfill.prototype.append = function (name, value) {
            this._pairs.push([String(name), String(value)]);
        };

        URLSearchParamsPolyfill.prototype['delete'] = function (name) {
            name = String(name);
            var out = [];
            for (var i = 0; i < this._pairs.length; i++) {
                if (this._pairs[i][0] !== name) { out.push(this._pairs[i]); }
            }
            this._pairs = out;
        };

        URLSearchParamsPolyfill.prototype.get = function (name) {
            name = String(name);
            for (var i = 0; i < this._pairs.length; i++) {
                if (this._pairs[i][0] === name) { return this._pairs[i][1]; }
            }
            return null;
        };

        URLSearchParamsPolyfill.prototype.getAll = function (name) {
            name = String(name);
            var out = [];
            for (var i = 0; i < this._pairs.length; i++) {
                if (this._pairs[i][0] === name) { out.push(this._pairs[i][1]); }
            }
            return out;
        };

        URLSearchParamsPolyfill.prototype.has = function (name) {
            return this.get(name) !== null;
        };

        URLSearchParamsPolyfill.prototype.set = function (name, value) {
            name = String(name);
            value = String(value);
            var found = false;
            for (var i = 0; i < this._pairs.length; i++) {
                if (this._pairs[i][0] === name) {
                    if (!found) {
                        this._pairs[i][1] = value;
                        found = true;
                    } else {
                        this._pairs.splice(i, 1);
                        i--;
                    }
                }
            }
            if (!found) { this._pairs.push([name, value]); }
        };

        URLSearchParamsPolyfill.prototype.sort = function () {
            this._pairs.sort(function (a, b) {
                return a[0] < b[0] ? -1 : (a[0] > b[0] ? 1 : 0);
            });
        };

        URLSearchParamsPolyfill.prototype.toString = function () {
            var out = [];
            for (var i = 0; i < this._pairs.length; i++) {
                out.push(encodePart(this._pairs[i][0]) + '=' +
                         encodePart(this._pairs[i][1]));
            }
            return out.join('&');
        };

        URLSearchParamsPolyfill.prototype.forEach = function (callback, thisArg) {
            for (var i = 0; i < this._pairs.length; i++) {
                callback.call(thisArg, this._pairs[i][1], this._pairs[i][0], this);
            }
        };

        URLSearchParamsPolyfill.prototype.keys = function () {
            var out = [];
            for (var i = 0; i < this._pairs.length; i++) {
                out.push(this._pairs[i][0]);
            }
            return out;
        };

        URLSearchParamsPolyfill.prototype.values = function () {
            var out = [];
            for (var i = 0; i < this._pairs.length; i++) {
                out.push(this._pairs[i][1]);
            }
            return out;
        };

        URLSearchParamsPolyfill.prototype.entries = function () {
            var out = [];
            for (var i = 0; i < this._pairs.length; i++) {
                out.push([this._pairs[i][0], this._pairs[i][1]]);
            }
            return out;
        };

        global.URLSearchParams = URLSearchParamsPolyfill;
    }

    /* ------------------------------------------------------------------ */
    /* Headers / Request / Response / fetch                                */
    /* ------------------------------------------------------------------ */

    function normalizeName(name) {
        return String(name).toLowerCase();
    }

    if (!global.Headers) {
        var HeadersPolyfill = function (init) {
            this._map = {};
            if (!init) { return; }
            if (init instanceof HeadersPolyfill) {
                var self = this;
                init.forEach(function (value, name) {
                    self.append(name, value);
                });
            } else if (Object.prototype.toString.call(init) === '[object Array]') {
                for (var i = 0; i < init.length; i++) {
                    this.append(init[i][0], init[i][1]);
                }
            } else {
                var keys = Object.keys(init);
                for (var j = 0; j < keys.length; j++) {
                    this.append(keys[j], init[keys[j]]);
                }
            }
        };

        HeadersPolyfill.prototype.append = function (name, value) {
            name = normalizeName(name);
            value = String(value);
            if (hasOwn.call(this._map, name)) {
                this._map[name] = this._map[name] + ', ' + value;
            } else {
                this._map[name] = value;
            }
        };

        HeadersPolyfill.prototype.set = function (name, value) {
            this._map[normalizeName(name)] = String(value);
        };

        HeadersPolyfill.prototype.get = function (name) {
            name = normalizeName(name);
            return hasOwn.call(this._map, name) ? this._map[name] : null;
        };

        HeadersPolyfill.prototype.has = function (name) {
            return hasOwn.call(this._map, normalizeName(name));
        };

        HeadersPolyfill.prototype['delete'] = function (name) {
            delete this._map[normalizeName(name)];
        };

        HeadersPolyfill.prototype.forEach = function (callback, thisArg) {
            for (var name in this._map) {
                if (hasOwn.call(this._map, name)) {
                    callback.call(thisArg, this._map[name], name, this);
                }
            }
        };

        global.Headers = HeadersPolyfill;
    }

    function resolveURL(url) {
        try {
            if (global.URL) { return new global.URL(url, global.location.href).href; }
        } catch (e) { }
        try {
            var a = document.createElement('a');
            a.href = url;
            return a.href;
        } catch (e2) {
            return String(url);
        }
    }

    if (!global.Request) {
        var RequestPolyfill = function (input, init) {
            init = init || {};
            if (typeof input === 'string') {
                this.url = resolveURL(input);
                this.method = init.method || 'GET';
                this.headers = new global.Headers(init.headers);
                this.body = init.body === undefined ? null : init.body;
                this.credentials = init.credentials || 'same-origin';
                this.signal = init.signal || null;
                this.mode = init.mode || 'cors';
            } else {
                this.url = input.url;
                this.method = init.method || input.method || 'GET';
                this.headers = new global.Headers(init.headers || input.headers);
                this.body = init.body === undefined ? input.body : init.body;
                this.credentials = init.credentials || input.credentials ||
                                   'same-origin';
                this.signal = init.signal || input.signal || null;
                this.mode = init.mode || input.mode || 'cors';
            }
        };
        RequestPolyfill.prototype.clone = function () {
            return new RequestPolyfill(this.url, {
                method: this.method,
                headers: this.headers,
                body: this.body,
                credentials: this.credentials,
                signal: this.signal,
                mode: this.mode
            });
        };
        global.Request = RequestPolyfill;
    }

    if (!global.Response) {
        var ResponsePolyfill = function (body, init) {
            init = init || {};
            this._body = body === undefined ? null : body;
            this.status = init.status === undefined ? 200 : init.status;
            this.statusText = init.statusText || '';
            this.headers = new global.Headers(init.headers);
            this.url = init.url || '';
            this.ok = this.status >= 200 && this.status < 300;
            this.type = 'basic';
            this.redirected = false;
        };

        ResponsePolyfill.prototype.text = function () {
            var self = this;
            return new Promise(function (resolve, reject) {
                try {
                    if (self._body === null || self._body === undefined) {
                        resolve('');
                    } else if (typeof self._body === 'string') {
                        resolve(self._body);
                    } else {
                        resolve(utf8Decode(new Uint8Array(self._body)));
                    }
                } catch (e) { reject(e); }
            });
        };

        ResponsePolyfill.prototype.json = function () {
            return this.text().then(function (text) {
                return JSON.parse(text);
            });
        };

        ResponsePolyfill.prototype.arrayBuffer = function () {
            var self = this;
            return new Promise(function (resolve) {
                if (self._body === null || self._body === undefined) {
                    resolve(new ArrayBuffer(0));
                } else if (typeof self._body === 'string') {
                    resolve(utf8Encode(self._body).buffer);
                } else {
                    resolve(self._body);
                }
            });
        };

        ResponsePolyfill.prototype.blob = function () {
            var self = this;
            return this.arrayBuffer().then(function (buffer) {
                return new Blob([buffer], {
                    type: self.headers.get('content-type') || ''
                });
            });
        };

        ResponsePolyfill.prototype.clone = function () {
            return new ResponsePolyfill(this._body, {
                status: this.status,
                statusText: this.statusText,
                headers: this.headers,
                url: this.url
            });
        };

        global.Response = ResponsePolyfill;
    }

    if (!global.fetch) {
        define(global, 'fetch', function (input, init) {
            return new Promise(function (resolve, reject) {
                var request = new global.Request(input, init);
                var xhr = new XMLHttpRequest();
                xhr.open(request.method, request.url, true);
                try { xhr.responseType = 'arraybuffer'; } catch (e) { }
                xhr.timeout = 90000;
                if (request.credentials === 'include') {
                    xhr.withCredentials = true;
                }
                request.headers.forEach(function (value, name) {
                    try { xhr.setRequestHeader(name, value); } catch (e) { }
                });

                function fail() {
                    reject(new TypeError('Network request failed'));
                }

                xhr.onload = function () {
                    var headers = new global.Headers();
                    var raw = '';
                    try { raw = xhr.getAllResponseHeaders() || ''; } catch (e) { }
                    var lines = raw.split(/\r?\n/);
                    for (var i = 0; i < lines.length; i++) {
                        var idx = lines[i].indexOf(':');
                        if (idx > 0) {
                            headers.append(lines[i].slice(0, idx),
                                           lines[i].slice(idx + 1).replace(/^\s+/, ''));
                        }
                    }
                    var body = xhr.response;
                    if (body === null || body === undefined) {
                        body = xhr.responseText || '';
                    }
                    resolve(new global.Response(body, {
                        status: xhr.status,
                        statusText: xhr.statusText,
                        headers: headers,
                        url: request.url
                    }));
                };
                xhr.onerror = fail;
                xhr.ontimeout = fail;
                xhr.onabort = function () {
                    reject(new Error('Aborted'));
                };

                if (request.signal) {
                    if (request.signal.aborted) {
                        reject(new Error('Aborted'));
                        return;
                    }
                    request.signal.addEventListener('abort', function () {
                        try { xhr.abort(); } catch (e) { }
                        reject(new Error('Aborted'));
                    });
                }

                try {
                    xhr.send(request.body);
                } catch (e) {
                    reject(e);
                }
            });
        });
    }

    /* ------------------------------------------------------------------ */
    /* AbortController                                                     */
    /* ------------------------------------------------------------------ */

    if (!global.AbortController) {
        var AbortSignalPolyfill = function () {
            this.aborted = false;
            this._listeners = [];
        };
        AbortSignalPolyfill.prototype.addEventListener = function (type, fn) {
            if (type === 'abort' && isCallable(fn)) { this._listeners.push(fn); }
        };
        AbortSignalPolyfill.prototype.removeEventListener = function (type, fn) {
            if (type !== 'abort') { return; }
            var idx = this._listeners.indexOf(fn);
            if (idx !== -1) { this._listeners.splice(idx, 1); }
        };
        AbortSignalPolyfill.prototype.dispatchEvent = function () {
            for (var i = 0; i < this._listeners.length; i++) {
                try { this._listeners[i].call(this, { type: 'abort' }); } catch (e) { }
            }
            return true;
        };

        var AbortControllerPolyfill = function () {
            this.signal = new AbortSignalPolyfill();
        };
        AbortControllerPolyfill.prototype.abort = function () {
            if (this.signal.aborted) { return; }
            this.signal.aborted = true;
            this.signal.dispatchEvent({ type: 'abort' });
        };
        global.AbortController = AbortControllerPolyfill;
    }

    /* ------------------------------------------------------------------ */
    /* Observers                                                           */
    /* ------------------------------------------------------------------ */

    if (!global.IntersectionObserver) {
        var IntersectionObserverPolyfill = function (callback, options) {
            this._callback = callback;
            this._options = options || {};
            this._targets = [];
            this._scheduled = false;
            var self = this;
            this._boundSchedule = function () { self._schedule(); };
            global.addEventListener('scroll', this._boundSchedule, true);
            global.addEventListener('resize', this._boundSchedule, true);
        };

        IntersectionObserverPolyfill.prototype.observe = function (target) {
            if (this._targets.indexOf(target) === -1) {
                this._targets.push(target);
            }
            this._schedule();
        };

        IntersectionObserverPolyfill.prototype.unobserve = function (target) {
            var idx = this._targets.indexOf(target);
            if (idx !== -1) { this._targets.splice(idx, 1); }
        };

        IntersectionObserverPolyfill.prototype.disconnect = function () {
            this._targets = [];
            global.removeEventListener('scroll', this._boundSchedule, true);
            global.removeEventListener('resize', this._boundSchedule, true);
        };

        IntersectionObserverPolyfill.prototype.takeRecords = function () {
            return [];
        };

        IntersectionObserverPolyfill.prototype._schedule = function () {
            if (this._scheduled) { return; }
            this._scheduled = true;
            var self = this;
            global.setTimeout(function () {
                self._scheduled = false;
                self._run();
            }, 60);
        };

        IntersectionObserverPolyfill.prototype._run = function () {
            if (!this._targets.length) { return; }
            var vw = global.innerWidth || document.documentElement.clientWidth;
            var vh = global.innerHeight || document.documentElement.clientHeight;
            var entries = [];
            for (var i = 0; i < this._targets.length; i++) {
                var el = this._targets[i];
                if (!el || !el.getBoundingClientRect) { continue; }
                var rect = el.getBoundingClientRect();
                var visible = rect.top < vh && rect.bottom > 0 &&
                              rect.left < vw && rect.right > 0;
                entries.push({
                    target: el,
                    isIntersecting: visible,
                    intersectionRatio: visible ? 1 : 0,
                    boundingClientRect: rect,
                    intersectionRect: rect,
                    rootBounds: null,
                    time: Date.now()
                });
            }
            if (entries.length) {
                try { this._callback(entries, this); } catch (e) { }
            }
        };

        global.IntersectionObserver = IntersectionObserverPolyfill;
    }

    if (!global.ResizeObserver) {
        var ResizeObserverPolyfill = function (callback) {
            this._callback = callback;
            this._targets = [];
            var self = this;
            this._boundRun = function () { self._run(); };
            global.addEventListener('resize', this._boundRun, true);
        };

        ResizeObserverPolyfill.prototype.observe = function (target) {
            if (this._targets.indexOf(target) === -1) {
                this._targets.push(target);
            }
            this._run();
        };

        ResizeObserverPolyfill.prototype.unobserve = function (target) {
            var idx = this._targets.indexOf(target);
            if (idx !== -1) { this._targets.splice(idx, 1); }
        };

        ResizeObserverPolyfill.prototype.disconnect = function () {
            this._targets = [];
            global.removeEventListener('resize', this._boundRun, true);
        };

        ResizeObserverPolyfill.prototype._run = function () {
            var entries = [];
            for (var i = 0; i < this._targets.length; i++) {
                var el = this._targets[i];
                if (!el || !el.getBoundingClientRect) { continue; }
                var rect = el.getBoundingClientRect();
                entries.push({
                    target: el,
                    contentRect: {
                        x: 0, y: 0,
                        width: rect.width, height: rect.height,
                        top: 0, left: 0, right: rect.width, bottom: rect.height
                    }
                });
            }
            if (entries.length) {
                try { this._callback(entries, this); } catch (e) { }
            }
        };

        global.ResizeObserver = ResizeObserverPolyfill;
    }

    /* ------------------------------------------------------------------ */
    /* Misc web APIs                                                       */
    /* ------------------------------------------------------------------ */

    if (!global.structuredClone) {
        define(global, 'structuredClone', function (value) {
            return JSON.parse(JSON.stringify(value));
        });
    }

    if (navigator && !navigator.sendBeacon) {
        try {
            navigator.sendBeacon = function (url, data) {
                try {
                    var xhr = new XMLHttpRequest();
                    xhr.open('POST', url, true);
                    xhr.send(data);
                    return true;
                } catch (e) {
                    return false;
                }
            };
        } catch (e2) { }
    }

    if (navigator && !navigator.clipboard) {
        try {
            Object.defineProperty(navigator, 'clipboard', {
                value: {
                    writeText: function (text) {
                        return new Promise(function (resolve, reject) {
                            try {
                                var area = document.createElement('textarea');
                                area.value = String(text);
                                area.setAttribute('readonly', 'readonly');
                                area.style.position = 'fixed';
                                area.style.left = '-9999px';
                                document.body.appendChild(area);
                                area.select();
                                document.execCommand('copy');
                                document.body.removeChild(area);
                                resolve();
                            } catch (e) { reject(e); }
                        });
                    },
                    readText: function () {
                        return Promise.reject(new Error('No disponible'));
                    }
                },
                configurable: true
            });
        } catch (e3) { }
    }

    if (document && !document.fonts) {
        try {
            document.fonts = {
                ready: Promise.resolve(),
                status: 'loaded',
                check: function () { return true; },
                load: function () { return Promise.resolve([]); },
                add: function () { },
                'delete': function () { },
                clear: function () { }
            };
        } catch (e) { }
    }

    if (global.CSS && !global.CSS.supports) {
        global.CSS.supports = function (property, value) {
            if (arguments.length === 1) {
                var parts = String(property).split(':');
                if (parts.length !== 2) { return false; }
                property = parts[0];
                value = parts[1];
            }
            var el = document.createElement('div');
            try {
                el.style[property] = value;
                return el.style[property] !== '';
            } catch (e) {
                return false;
            }
        };
    }

    if (global.Element && !Element.prototype.animate) {
        define(Element.prototype, 'animate', function () {
            return {
                finished: Promise.resolve(),
                currentTime: 0,
                playState: 'finished',
                onfinish: null,
                cancel: function () { },
                finish: function () { },
                play: function () { },
                pause: function () { },
                reverse: function () { },
                addEventListener: function () { },
                removeEventListener: function () { }
            };
        });
    }

    if (!global.isSecureContext) {
        try {
            Object.defineProperty(global, 'isSecureContext', {
                get: function () {
                    return global.location.protocol === 'https:' ||
                           global.location.hostname === 'localhost';
                },
                configurable: true
            });
        } catch (e) { }
    }

    if (global.scrollTo) {
        var nativeScrollTo = global.scrollTo;
        define(global, 'scrollTo', function (x, y) {
            if (typeof x === 'object' && x !== null) {
                nativeScrollTo.call(global, x.left || 0, x.top || 0);
            } else {
                nativeScrollTo.call(global, x, y);
            }
        });
    }

    if (global.crypto && !global.crypto.randomUUID) {
        try {
            global.crypto.randomUUID = function () {
                var bytes = new Uint8Array(16);
                if (global.crypto.getRandomValues) {
                    global.crypto.getRandomValues(bytes);
                } else {
                    for (var i = 0; i < 16; i++) {
                        bytes[i] = Math.floor(Math.random() * 256);
                    }
                }
                bytes[6] = (bytes[6] & 0x0F) | 0x40;
                bytes[8] = (bytes[8] & 0x3F) | 0x80;
                var hex = [];
                for (var j = 0; j < 16; j++) {
                    hex.push((bytes[j] + 0x100).toString(16).slice(1));
                }
                return hex.slice(0, 4).join('') + '-' +
                       hex.slice(4, 6).join('') + '-' +
                       hex.slice(6, 8).join('') + '-' +
                       hex.slice(8, 10).join('') + '-' +
                       hex.slice(10, 16).join('');
            };
        } catch (e) { }
    }
})(typeof window !== 'undefined' ? window : this);
