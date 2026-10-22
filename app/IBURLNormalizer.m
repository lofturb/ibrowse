#import "IBURLNormalizer.h"
#import "IBSettings.h"

@implementation IBURLNormalizer

+ (NSString *)encodedQuery:(NSString *)query {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"];
    return [query stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

+ (BOOL)looksLikeURL:(NSString *)text {
    if (text.length == 0) { return NO; }
    if ([text rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
        return NO;
    }
    NSString *lower = [text lowercaseString];
    if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"] ||
        [lower hasPrefix:@"file://"] || [lower hasPrefix:@"about:"] ||
        [lower hasPrefix:@"ibrowse://"]) {
        return YES;
    }
    if ([lower hasPrefix:@"localhost"] || [lower hasPrefix:@"127.0.0.1"] ||
        [lower hasPrefix:@"192.168."] || [lower hasPrefix:@"10."] ||
        [lower hasPrefix:@"172.16."] || [lower hasPrefix:@"172.17."] ||
        [lower hasPrefix:@"172.18."] || [lower hasPrefix:@"172.19."] ||
        [lower hasPrefix:@"172.2"] || [lower hasPrefix:@"172.30."] ||
        [lower hasPrefix:@"172.31."]) {
        return YES;
    }
    if ([lower rangeOfString:@"."].location != NSNotFound) {
        return YES;
    }
    if ([lower rangeOfString:@":"].location != NSNotFound) {
        return YES;
    }
    return NO;
}

+ (BOOL)isStartURL:(NSURL *)url {
    if (!url) { return NO; }
    NSString *scheme = [url.scheme lowercaseString];
    if ([scheme isEqualToString:@"ibrowse"]) { return YES; }
    if ([scheme isEqualToString:@"about"] &&
        [[url.absoluteString lowercaseString] isEqualToString:@"about:start"]) {
        return YES;
    }
    return NO;
}

+ (BOOL)isHTTPURL:(NSURL *)url {
    NSString *scheme = [url.scheme lowercaseString];
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

+ (NSURL *)searchURLForQuery:(NSString *)query engine:(NSString *)engine {
    NSString *q = [self encodedQuery:query];
    NSString *format = nil;
    if ([engine isEqualToString:@"google"]) {
        format = @"https://www.google.com/search?q=%@";
    } else if ([engine isEqualToString:@"bing"]) {
        format = @"https://www.bing.com/search?q=%@";
    } else if ([engine isEqualToString:@"startpage"]) {
        format = @"https://www.startpage.com/sp/search?query=%@";
    } else if ([engine isEqualToString:@"brave"]) {
        format = @"https://search.brave.com/search?q=%@";
    } else if ([engine isEqualToString:@"wikipedia"]) {
        format = @"https://es.wikipedia.org/w/index.php?search=%@";
    } else {
        format = @"https://html.duckduckgo.com/html/?q=%@";
    }
    return [NSURL URLWithString:[NSString stringWithFormat:format, q]];
}

+ (NSURL *)URLFromUserInput:(NSString *)text {
    return [self URLFromUserInput:text
                     searchEngine:[[IBSettings sharedSettings] searchEngine]];
}

+ (NSURL *)URLFromUserInput:(NSString *)text searchEngine:(NSString *)engine {
    if (!text) { return nil; }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) { return nil; }

    NSString *lower = [trimmed lowercaseString];

    /* Esquemas que no queremos pasar al WebView. */
    if ([lower hasPrefix:@"javascript:"] || [lower hasPrefix:@"data:"]) {
        return [self searchURLForQuery:trimmed engine:engine];
    }

    if ([lower hasPrefix:@"ibrowse://"]) {
        return [NSURL URLWithString:trimmed];
    }

    if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"] ||
        [lower hasPrefix:@"file://"] || [lower hasPrefix:@"about:"]) {
        NSURL *url = [NSURL URLWithString:trimmed];
        if (url) { return url; }
    }

    if ([lower hasPrefix:@"//"]) {
        return [NSURL URLWithString:[@"https:" stringByAppendingString:trimmed]];
    }

    if ([trimmed rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
        return [self searchURLForQuery:trimmed engine:engine];
    }

    if (![self looksLikeURL:trimmed]) {
        return [self searchURLForQuery:trimmed engine:engine];
    }

    NSString *candidate = trimmed;
    if ([lower hasPrefix:@"localhost"] ||
        [lower hasPrefix:@"127.0.0.1"] ||
        [lower hasPrefix:@"192.168."] ||
        [lower hasPrefix:@"10."] ||
        [lower hasPrefix:@"172.16."] ||
        [lower hasPrefix:@"172.17."] ||
        [lower hasPrefix:@"172.18."] ||
        [lower hasPrefix:@"172.19."] ||
        [lower hasPrefix:@"172.2"] ||
        [lower hasPrefix:@"172.30."] ||
        [lower hasPrefix:@"172.31."] ||
        [lower hasSuffix:@".local"] ||
        [lower hasSuffix:@".test"]) {
        candidate = [@"http://" stringByAppendingString:trimmed];
    } else {
        candidate = [@"https://" stringByAppendingString:trimmed];
    }

    candidate = [candidate stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
    NSURL *url = [NSURL URLWithString:candidate];
    if (!url) {
        return [self searchURLForQuery:trimmed engine:engine];
    }
    return url;
}

+ (NSString *)relayWrappedURLString:(NSURL *)url baseURL:(NSString *)baseURL {
    if (!url) { return nil; }
    if (![self isHTTPURL:url]) { return nil; }
    if (!baseURL || baseURL.length == 0) { return nil; }
    if ([self isRelayURL:url baseURL:baseURL]) { return nil; }
    NSString *encoded = [self encodedQuery:url.absoluteString];
    return [NSString stringWithFormat:@"%@/browse?u=%@", baseURL, encoded];
}

+ (NSURL *)originalURLFromRelayURL:(NSURL *)url baseURL:(NSString *)baseURL {
    if (!url || !baseURL) { return nil; }
    if (![self isRelayURL:url baseURL:baseURL]) { return nil; }
    NSString *query = url.query;
    if (!query) { return nil; }
    NSArray *parts = [query componentsSeparatedByString:@"&"];
    for (NSString *part in parts) {
        if ([part hasPrefix:@"u="]) {
            NSString *value = [part substringFromIndex:2];
            NSString *decoded = [value stringByRemovingPercentEncoding];
            if (!decoded) { decoded = value; }
            return [NSURL URLWithString:decoded];
        }
    }
    return nil;
}

+ (BOOL)isRelayURL:(NSURL *)url baseURL:(NSString *)baseURL {
    if (!url || !baseURL || baseURL.length == 0) { return NO; }
    NSString *absolute = url.absoluteString;
    if (![absolute hasPrefix:baseURL]) { return NO; }
    NSString *path = url.path;
    return [path isEqualToString:@"/browse"] ||
           [path isEqualToString:@"/asset"] ||
           [path isEqualToString:@"/api"] ||
           [path isEqualToString:@"/submit"];
}

+ (NSString *)displayHostForURL:(NSURL *)url {
    NSString *host = url.host;
    if (!host || host.length == 0) { return url.absoluteString ? url.absoluteString : @""; }
    if ([host hasPrefix:@"www."]) {
        host = [host substringFromIndex:4];
    }
    return host;
}

@end
