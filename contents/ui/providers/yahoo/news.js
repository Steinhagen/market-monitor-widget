.pragma library

.import "../../core/Http.js" as Http
// Latest headlines for one symbol, from the Yahoo search endpoint the symbol search in
// the settings already uses (no cookie or crumb needed):
//   https://query2.finance.yahoo.com/v1/finance/search?q=<query>&quotesCount=0&newsCount=<n>
//   &lang=<lang>&region=<region>
// Each news[] item has uuid, title, publisher, link, providerPublishTime (unix seconds)
// and relatedTickers[]. Only items tagged with the symbol are kept.
//
// The endpoint is the same API the regional portals use (they call it on query1 with
// lang/region): it returns the requested edition's headlines, tagged with the same
// tickers as the English edition. English uses en-US/US; German, French, Spanish and
// Italian have localised editions. Other languages are not localised by this endpoint
// (it falls back to the US English feed or returns nothing), so they are skipped rather
// than labelled with a language the headlines are not in.
//
// Callers must not set a User-Agent. Yahoo's edge answers 429 to non-browser agents,
// and Qt's default "Mozilla/5.0" is accepted.

// Yahoo deduplicates its own results and returns about n - 1 items for newsCount=n, and
// the ticker filter can drop a few more. Ask for a few extra and cut after filtering.
var EXTRA_REQUESTED = 4;

// Source label attached to this endpoint's headlines. The news view builds its filter
// buttons from the labels of the shown items, so another provider (BVB, for example)
// only has to return its own label here.
var YAHOO_SOURCE = "Yahoo";

// Edition a language code asks for. These are the languages Yahoo localises; the same
// table drives supportsLanguage(), so the controller and the fetch agree on what can be
// requested. `site`/`news` point the More on Yahoo Finance link at the edition's own
// news page; the regional portals translate the route name.
var LOCALES = {
    en: { lang: "en-US", region: "US", site: "finance.yahoo.com", news: "news" },
    de: { lang: "de-DE", region: "DE", site: "de.finance.yahoo.com", news: "nachrichten" },
    fr: { lang: "fr-FR", region: "FR", site: "fr.finance.yahoo.com", news: "actualites" },
    es: { lang: "es-ES", region: "ES", site: "es.finance.yahoo.com", news: "noticias" },
    it: { lang: "it-IT", region: "IT", site: "it.finance.yahoo.com", news: "notizie" }
};

function supportsLanguage(code) {
    return Object.prototype.hasOwnProperty.call(LOCALES, String(code || "").toLowerCase());
}

function searchUrl(query, shown, language) {
    var edition = LOCALES[String(language || "en").toLowerCase()] || LOCALES.en;
    return "https://query2.finance.yahoo.com/v1/finance/search?q=" + encodeURIComponent(query)
        + "&quotesCount=0&newsCount=" + (Number(shown) + EXTRA_REQUESTED)
        + "&lang=" + edition.lang + "&region=" + edition.region;
}

// The edition's news page for a symbol: the footer link and the fallback for odd
// article links. The regional portals use their own route name (nachrichten,
// actualites, noticias, notizie) and need the trailing slash; the English edition keeps
// the global /news/ route.
function newsPageUrl(symbol, language) {
    var edition = LOCALES[String(language || "en").toLowerCase()] || LOCALES.en;
    return "https://" + edition.site + "/quote/"
        + encodeURIComponent(String(symbol).trim()) + "/" + edition.news + "/";
}

// Only secure web links are opened. Anything else (http:, javascript:, file:, empty)
// opens the symbol's news page instead.
function safeLink(url, symbol, language) {
    var link = String(url === undefined || url === null ? "" : url).trim();
    return /^https:\/\//i.test(link) ? link : newsPageUrl(symbol, language);
}

// One pass, so "&amp;lt;" becomes "&lt;" and is not decoded twice. The result is shown
// as plain text, so tags in a title stay visible text and are never rendered.
function decodeEntities(s) {
    var named = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'" };
    return String(s === undefined || s === null ? "" : s).replace(/&(#[xX][0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);/g,
        function (match, entity) {
            if (entity.charAt(0) !== "#") return named[entity];
            var hex = entity.charAt(1) === "x" || entity.charAt(1) === "X";
            var code = parseInt(entity.substring(hex ? 2 : 1), hex ? 16 : 10);
            if (!isFinite(code) || code <= 0 || code > 0x10FFFF) return match;
            return String.fromCodePoint(code);
        });
}

// The RSS feed is the only Yahoo endpoint that carries news for some BVB symbols:
// the search endpoint above returns no news for WINE.RO, while
// https://finance.yahoo.com/rss/headline?s=WINE.RO has the English articles shown on
// the quote page. It is a fallback, only for .RO symbols on the English leg, because
// the feed follows the listing's market language (SAP.DE returns German, AI.PA French)
// and its per-symbol relevance is weaker than the search endpoint's ticker tags.
var RSS_BASE = "https://finance.yahoo.com/rss/headline?s=";

function rssUrl(symbol) {
    return RSS_BASE + encodeURIComponent(String(symbol || "").trim());
}

function canUseRss(symbol, language) {
    return String(language || "").toLowerCase() === "en"
        && /\.RO$/i.test(String(symbol || "").trim());
}

var RSS_MONTHS = { Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5,
                   Jul: 6, Aug: 7, Sep: 8, Oct: 9, Nov: 10, Dec: 11 };

function rssTagText(block, name) {
    var m = new RegExp("<" + name + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + name + ">", "i").exec(String(block));
    if (!m) return "";
    return m[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
}

// The feed prints RFC 822 dates ("Wed, 09 Sep 2026 01:00:23 +0000").
function parseRssDate(text) {
    var m = /(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})/.exec(String(text || ""));
    if (!m) return 0;
    var key = m[2].charAt(0).toUpperCase() + m[2].substring(1).toLowerCase();
    var month = RSS_MONTHS[key];
    if (month === undefined) return 0;
    var t = Date.UTC(Number(m[3]), month, Number(m[1]), Number(m[4]), Number(m[5]), Number(m[6]));
    return isFinite(t) ? Math.floor(t / 1000) : 0;
}

function publisherFromLink(link) {
    var m = /^https?:\/\/([^\/?#]+)/i.exec(String(link || ""));
    if (!m) return "";
    var host = m[1].toLowerCase().replace(/^www\./, "");
    if (host === "finance.yahoo.com" || host === "yahoo.com") return "Yahoo Finance";
    var label = host.split(".")[0].replace(/[-_]+/g, " ").trim();
    if (label === "") return "";
    return label.replace(/\b[a-z]/g, function (c) { return c.toUpperCase(); });
}

// Words that identify the company in a headline. Legal forms and generic words are
// dropped so "Purcari Wineries Public Company Limited" matches "Purcari Wineries".
var RSS_STOPWORDS = {
    "the": 1, "and": 1, "for": 1, "of": 1, "a": 1, "an": 1, "to": 1, "in": 1, "on": 1,
    "public": 1, "company": 1, "limited": 1, "pcl": 1, "plc": 1, "sa": 1, "ag": 1,
    "nv": 1, "group": 1, "groupe": 1, "holding": 1, "holdings": 1, "corporation": 1,
    "corp": 1, "inc": 1, "ltd": 1, "co": 1, "societe": 1, "societatea": 1, "srl": 1,
    "spa": 1
};

function significantWords(name) {
    var text = String(name === undefined || name === null ? "" : name)
        .toLowerCase().replace(/[^a-z0-9]+/g, " ");
    var parts = text.split(/\s+/);
    var words = [];
    for (var i = 0; i < parts.length; i++) {
        var word = parts[i];
        if (word.length < 3 || RSS_STOPWORDS[word] || words.indexOf(word) >= 0) continue;
        words.push(word);
    }
    return words;
}

// RSS items have no ticker tags, so keep only headlines that mention the base symbol
// or a significant company-name word. This removes the unrelated market articles the
// feed occasionally mixes in (TLV.RO returned Japanese stocks in the sampled feed).
function rssTitleMatches(title, symbol, name) {
    var text = " " + String(title === undefined || title === null ? "" : title)
        .toLowerCase().replace(/[^a-z0-9]+/g, " ").replace(/\s+/g, " ").trim() + " ";
    var sym = String(symbol === undefined || symbol === null ? "" : symbol).trim().toUpperCase();
    var dot = sym.lastIndexOf(".");
    var base = (dot > 0 ? sym.substring(0, dot) : sym).toLowerCase();
    if (base.length >= 3 && text.indexOf(" " + base + " ") >= 0) return true;
    var words = significantWords(name);
    for (var i = 0; i < words.length; i++) {
        if (text.indexOf(" " + words[i] + " ") >= 0) return true;
    }
    return false;
}

// `text` is the RSS body. Returns the same item shape as parse(), with the language
// requested for the leg (the .RO feed is English).
function parseRss(text, symbol, name, limit, language) {
    var xml = String(text === undefined || text === null ? "" : text);
    var blocks = xml.match(/<item\b[\s\S]*?<\/item>/gi) || [];
    var lang = String(language || "en").toLowerCase();
    var items = [];
    var seen = {};
    for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i];
        var link = decodeEntities(rssTagText(block, "link")).trim();
        if (link === "") continue;
        var title = decodeEntities(rssTagText(block, "title")).trim();
        if (title === "" || !rssTitleMatches(title, symbol, name)) continue;
        var guid = decodeEntities(rssTagText(block, "guid")).trim();
        var id = guid !== "" ? guid : link;
        var keys = ["u:" + id.toLowerCase(), "l:" + link.toLowerCase(), "t:" + title.toLowerCase()];
        var duplicate = false;
        for (var k = 0; k < keys.length; k++) {
            if (keys[k].length > 2 && seen[keys[k]]) duplicate = true;
        }
        if (duplicate) continue;
        for (var m = 0; m < keys.length; m++) {
            if (keys[m].length > 2) seen[keys[m]] = true;
        }
        items.push({
            id: id,
            title: title,
            publisher: publisherFromLink(link),
            source: YAHOO_SOURCE,
            lang: lang,
            link: link,
            time: parseRssDate(rssTagText(block, "pubDate"))
        });
    }
    items.sort(function (a, b) { return b.time - a.time; });
    var max = Number(limit);
    return max >= 0 ? items.slice(0, max) : items;
}

function fetchRss(ctx, language, done) {
    Http.getText(rssUrl(ctx.symbol), { timeout: 20000 }, function(body, error) {
        if (error) {
            // The search endpoint already answered; a failed fallback means no
            // headlines, not a source error.
            done([], "");
            return;
        }
        try {
            done(parseRss(body, ctx.symbol, ctx.name, ctx.limit, language), "");
        } catch (e) {
            done([], "");
        }
    });
}

function matchesSymbol(related, symbol, base) {
    if (!Array.isArray(related)) return false;
    for (var i = 0; i < related.length; i++) {
        var tag = String(related[i]).trim().toUpperCase();
        if (tag === symbol || (base !== "" && tag === base)) return true;
    }
    return false;
}

// `data` is the parsed JSON reply. Returns [{id, title, publisher, source, lang, link,
// time}], newest first and at most `limit` items. `allowBase` also accepts the symbol
// without its exchange suffix (SAP.DE -> SAP). Use it only for the company-name query:
// for a ticker query the base can be another company (RRC.RO is not Range Resources,
// RRC). `language` is the edition that was requested, so each item carries its language.
function parse(data, symbol, allowBase, limit, language) {
    if (!data || !Array.isArray(data.news)) return [];
    var sym = String(symbol === undefined || symbol === null ? "" : symbol).trim().toUpperCase();
    if (sym === "") return [];
    var dot = sym.lastIndexOf(".");
    var base = allowBase && dot > 0 ? sym.substring(0, dot) : "";
    var lang = String(language || "en").toLowerCase();

    var items = [];
    var seen = {};
    for (var i = 0; i < data.news.length; i++) {
        var item = data.news[i];
        if (!item || !matchesSymbol(item.relatedTickers, sym, base)) continue;
        var title = decodeEntities(item.title).trim();
        if (title === "") continue;
        var link = String(item.link === undefined || item.link === null ? "" : item.link).trim();
        var id = item.uuid ? String(item.uuid) : (link !== "" ? link : title);
        var keys = ["u:" + (item.uuid || ""), "l:" + link, "t:" + title];
        var duplicate = false;
        for (var k = 0; k < keys.length; k++) {
            if (keys[k].length > 2 && seen[keys[k]]) duplicate = true;
        }
        if (duplicate) continue;
        for (var m = 0; m < keys.length; m++) {
            if (keys[m].length > 2) seen[keys[m]] = true;
        }
        items.push({
            id: id,
            title: title,
            publisher: decodeEntities(item.publisher).trim(),
            source: YAHOO_SOURCE,
            lang: lang,
            link: link,
            time: Number(item.providerPublishTime) || 0
        });
    }
    items.sort(function (a, b) { return b.time - a.time; });
    var max = Number(limit);
    return max >= 0 ? items.slice(0, max) : items;
}

// One language leg: the ticker query keeps only items tagged with the symbol; when it
// finds nothing, the company name is searched and the base symbol is accepted too.
// `ctx.name` is null while the quote has not supplied the name: the caller is told that
// the source needs the name and retries when it is known.
function fetchLanguage(ctx, language, done) {
    var symbol = String(ctx.symbol || "").trim();
    var limit = Number(ctx.limit);
    var search = function(query, allowBase) {
        Http.getJson(searchUrl(query, limit, language), { timeout: 20000 }, function(data, error) {
            if (error) {
                done([], error.message, {});
                return;
            }
            var items = parse(data, symbol, allowBase, limit, language);
            if (items.length === 0 && !allowBase) {
                var name = ctx.name;
                if (name === null) {
                    done([], "", { needsName: true });
                    return;
                }
                if (name !== "") {
                    search(name, true);
                    return;
                }
            }
            if (items.length === 0 && canUseRss(symbol, language)) {
                fetchRss(ctx, language, function (rssItems) { done(rssItems, "", {}); });
                return;
            }
            done(items, "", {});
        });
    };
    search(symbol, false);
}

// Provider entry point. One query per active language Yahoo has an edition for. A
// language the endpoint does not localise is skipped rather than fetched from the US
// edition; the controller's edition table already keeps it out, and this is the second
// guard for direct callers.
function fetch(ctx, done) {
    var wanted = ctx.languages && ctx.languages.length
                 ? ctx.languages : [{ code: "en" }];
    var languages = [];
    for (var i = 0; i < wanted.length; i++) {
        var code = String(wanted[i].code || "").toLowerCase();
        if (supportsLanguage(code) && languages.indexOf(code) < 0) languages.push(code);
    }
    if (languages.length === 0) {
        done([], "", {});
        return;
    }

    var remaining = languages.length;
    var all = [];
    var failed = 0;
    var firstError = "";
    var needsName = false;
    var finished = false;
    var finish = function(items, error, flags) {
        if (finished) return;
        finished = true;
        done(items, error, flags || {});
    };

    var collect = function(items, error, flags) {
        remaining--;
        if (error) {
            failed++;
            if (firstError === "") firstError = error;
        }
        if (flags && flags.needsName) needsName = true;
        all = all.concat(items || []);
        if (remaining > 0) return;
        if (all.length === 0) {
            finish([], failed === languages.length ? (firstError || "unexpected reply") : "",
                   { needsName: needsName });
            return;
        }
        all.sort(function (a, b) { return (b.time || 0) - (a.time || 0); });
        var seen = {};
        var merged = [];
        for (var j = 0; j < all.length; j++) {
            var item = all[j];
            var keys = ["l:" + String(item.link || "").toLowerCase(),
                        "t:" + String(item.title || "").toLowerCase()];
            var duplicate = false;
            for (var k = 0; k < keys.length; k++) {
                if (keys[k].length > 2 && seen[keys[k]]) duplicate = true;
            }
            if (duplicate) continue;
            for (var m = 0; m < keys.length; m++) {
                if (keys[m].length > 2) seen[keys[m]] = true;
            }
            merged.push(item);
        }
        // Keep the flag even when another language already produced items: the retry
        // with the company name can add the headlines the ticker query missed.
        finish(merged, "", { needsName: needsName });
    };

    for (var j = 0; j < languages.length; j++) fetchLanguage(ctx, languages[j], collect);
}
