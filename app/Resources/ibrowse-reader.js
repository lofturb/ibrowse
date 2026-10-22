/*
 * IBrowse — extracción de modo lectura.
 * Devuelve un objeto serializable a Objective-C. ES5.
 */
(function () {
    'use strict';

    var article = document.querySelector('article') ||
                  document.querySelector('[role="main"]') ||
                  document.querySelector('main') ||
                  document.body;

    if (!article) {
        return { error: 'No se encontró contenido' };
    }

    var clone = article.cloneNode(true);
    var remove = clone.querySelectorAll(
        'script,style,noscript,iframe,form,nav,aside,footer,header,button,' +
        'svg,canvas,video,audio,input,select,textarea,[aria-hidden="true"],' +
        '[style*="display:none"],[style*="display: none"]'
    );
    for (var i = remove.length - 1; i >= 0; i--) {
        if (remove[i].parentNode) {
            remove[i].parentNode.removeChild(remove[i]);
        }
    }

    var titleEl = document.querySelector('h1') ||
                  document.querySelector('meta[property="og:title"]');
    var title = '';
    if (titleEl) {
        title = titleEl.innerText || titleEl.content || titleEl.textContent || '';
    }
    if (!title) { title = document.title || ''; }

    var authorEl = document.querySelector('meta[name="author"]') ||
                   document.querySelector('[rel="author"]');
    var author = '';
    if (authorEl) {
        author = authorEl.content || authorEl.innerText || authorEl.textContent || '';
    }

    var text = clone.innerText || clone.textContent || '';
    text = text.replace(/\r/g, '')
               .replace(/[ \t]+\n/g, '\n')
               .replace(/\n[ \t]+/g, '\n')
               .replace(/\n{3,}/g, '\n\n')
               .replace(/^\s+|\s+$/g, '');

    if (text.length > 140000) {
        text = text.slice(0, 140000) + '\n\n[Texto truncado por IBrowse]';
    }

    return {
        title: title.replace(/^\s+|\s+$/g, ''),
        author: author.replace(/^\s+|\s+$/g, ''),
        text: text,
        url: location.href,
        length: text.length
    };
})();
