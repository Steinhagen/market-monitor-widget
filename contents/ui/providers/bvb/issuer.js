.pragma library

.import "../../core/Http.js" as Http
// Issuer news for symbols traded on the Bucharest Stock Exchange (Yahoo symbols
// ending in .RO). The instrument page server-renders the five newest announcements;
// its "Stiri" tab is an ASP.NET postback that returns the last 60 announcements in one
// HTML table (the page's DataTables only paginates them client-side). Replaying that
// postback gives us the full list, which the caller slices to the configured count.
//
// There is no JSON endpoint for these headlines; the page is parsed as HTML. If the
// postback cannot be built or fails, the five entries from the first GET are used.

var SOURCE = "BVB";
var PAGE = "https://www.bvb.ro/FinancialInstruments/Details/FinancialInstrumentsDetails.aspx?s=";

// EL.RO -> EL. Only the simple BVB tickers are accepted; symbols with other exchange
// suffixes are not Bucharest listings and have no page on this site.
function baseSymbol(symbol) {
    var sym = String(symbol === undefined || symbol === null ? "" : symbol).trim().toUpperCase();
    if (!/\.RO$/.test(sym)) return "";
    var base = sym.substring(0, sym.length - 3).trim();
    return /^[A-Z0-9]{1,12}$/.test(base) ? base : "";
}

function detailUrl(symbol) {
    var base = baseSymbol(symbol);
    return base === "" ? "" : PAGE + encodeURIComponent(base);
}

// HTML entities in titles are shown as text, so decode them once.
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

// BVB prints dd.MM.yyyy HH:mm:ss in Romanian and M/d/yyyy h:mm:ss AM/PM in English.
// The widget runs on the user's clock, so this is parsed in the local time zone like
// the rest of the UI.
function parseTime(text) {
    var raw = String(text).trim();
    var m = /^(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})$/.exec(raw);
    var day, month, year, hour, minute, second;
    if (m) {
        day = Number(m[1]); month = Number(m[2]) - 1; year = Number(m[3]);
        hour = Number(m[4]); minute = Number(m[5]); second = Number(m[6]);
    } else {
        m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)?$/i.exec(raw);
        if (!m) return 0;
        month = Number(m[1]) - 1; day = Number(m[2]); year = Number(m[3]);
        hour = Number(m[4]); minute = Number(m[5]); second = Number(m[6]);
        var suffix = (m[7] || "").toUpperCase();
        if (suffix === "PM" && hour < 12) hour += 12;
        if (suffix === "AM" && hour === 12) hour = 0;
    }
    var d = new Date(year, month, day, hour, minute, second);
    var t = Math.floor(d.getTime() / 1000);
    return isFinite(t) ? t : 0;
}

function absoluteLink(href) {
    var link = String(href === undefined || href === null ? "" : href).trim();
    if (link === "") return "";
    if (/^https?:\/\//i.test(link)) return link;
    if (link.indexOf("//") === 0) return "https:" + link;
    if (link.charAt(0) === "/") return "https://www.bvb.ro" + link;
    return "https://www.bvb.ro/" + link;
}

// Read an attribute from one input tag, whichever order the attributes use.
function inputValue(tag, name) {
    if (!new RegExp('\\bname="' + name + '"').test(tag)) return null;
    var m = new RegExp('\\bvalue="([^"]*)"').exec(tag);
    return m ? m[1] : "";
}

// An <input> tag can contain ">" inside an attribute value (a headline such as
// "Notificare prag detineri > 5%"), so the tag is matched with its quotes instead of
// with [^>]*, which would stop at that ">".
var INPUT_TAG = /<input\b(?:[^>"']|"[^"]*"|'[^']*')*>/gi;

function inputTags(html) {
    return String(html).match(INPUT_TAG) || [];
}

function hiddenValue(html, name) {
    var tags = inputTags(html);
    for (var i = 0; i < tags.length; i++) {
        var value = inputValue(tags[i], name);
        if (value !== null) return value;
    }
    return "";
}

// The "Stiri" tab is a submit input named ctl00$body$IFTC$<guid>. Its GUID changes
// between page builds, so locate it by its visible label and the IFTC prefix.
function tabButtonName(html) {
    var tags = inputTags(html);
    for (var i = 0; i < tags.length; i++) {
        var tag = tags[i];
        if (!new RegExp('\\bvalue="Stiri"', "i").test(tag)
                || !new RegExp('\\bname="[^"]*IFTC[^"]*"', "i").test(tag)) continue;
        var m = new RegExp('\\bname="([^"]+)"').exec(tag);
        if (m) return m[1];
    }
    return "";
}

// POST body that selects the "Stiri" tab. Returns "" when the page did not expose
// the ASP.NET state needed for the postback, in which case the top five are used.
function postBody(html) {
    var viewState = hiddenValue(html, "__VIEWSTATE");
    var validation = hiddenValue(html, "__EVENTVALIDATION");
    var generator = hiddenValue(html, "__VIEWSTATEGENERATOR");
    var button = tabButtonName(html);
    if (viewState === "" || validation === "" || button === "") return "";
    return "__VIEWSTATE=" + encodeURIComponent(viewState)
        + "&__VIEWSTATEGENERATOR=" + encodeURIComponent(generator)
        + "&__EVENTVALIDATION=" + encodeURIComponent(validation)
        + "&__EVENTTARGET="
        + "&" + encodeURIComponent(button) + "=" + encodeURIComponent("Stiri");
}

// Filenames carry the language, but an article can have several attachments per
// language. Classify each PDF and, in English mode, pick the one whose slug best
// matches the English article title. BVB itself is asked for the English page with the
// BVBCulturePref cookie, so the title in the table is already in English.
var RO_WORDS = {
    comunicat: 1, presa: 1, raport: 1, raportare: 1, raportul: 1, semestrial: 1,
    semestriala: 1, anual: 1, anuala: 1, convocare: 1, notificare: 1, hotarare: 1,
    decizie: 1, tranzactii: 1, tranzactie: 1, consiliu: 1, adunarea: 1, actionari: 1,
    rezultate: 1, rezult: 1, situatii: 1, financiare: 1, financiar: 1, piete: 1,
    actiuni: 1, emitent: 1, conducere: 1, modificari: 1, echipa: 1, perioada: 1,
    perioad: 1, inchis: 1, nchis: 1, publicarea: 1, programare: 1, reprogramare: 1,
    conferinta: 1, telefonica: 1, ziua: 1, investitorului: 1, prag: 1, detineri: 1,
    depasire: 1, curent: 1, consolidat: 1, consolidate: 1, anexa: 1, intermediar: 1,
    intermediara: 1, auditata: 1, neauditata: 1, dividende: 1, majorare: 1,
    reducere: 1, rascumparare: 1, oferta: 1, prospect: 1, fuziune: 1, cesiune: 1,
    instrainare: 1, ipoteca: 1, garantie: 1, litigiu: 1, insolventa: 1,
    reorganizare: 1, lichidare: 1, dizolvare: 1, semestrial: 1
};
var EN_WORDS = {
    press: 1, release: 1, report: 1, half: 1, yearly: 1, annual: 1, notice: 1,
    notification: 1, convening: 1, resolution: 1, transactions: 1, board: 1,
    shareholders: 1, dividend: 1, dividends: 1, results: 1, financial: 1,
    statements: 1, markets: 1, shares: 1, issuer: 1, management: 1, changes: 1,
    team: 1, period: 1, closed: 1, publication: 1, conference: 1, call: 1,
    investor: 1, investors: 1, day: 1, threshold: 1, holdings: 1, exceeded: 1,
    current: 1, corporate: 1, presentation: 1, interim: 1, audited: 1,
    unaudited: 1, consolidated: 1, annex: 1, increase: 1, decrease: 1,
    buyback: 1, offer: 1, prospectus: 1, merger: 1, transfer: 1, pledge: 1,
    guarantee: 1, litigation: 1, insolvency: 1, restructuring: 1,
    liquidation: 1, dissolution: 1, document: 1, english: 1
};

function fileNameTokens(link) {
    var clean = String(link || "").split(/[?#]/)[0];
    var base = clean.substring(clean.lastIndexOf("/") + 1).replace(/\.pdf$/i, "").toLowerCase();
    base = base.replace(/^\d{8}-/, "");
    return base.split(/[^a-z0-9]+/).filter(function (token) { return token !== ""; });
}

function languageOf(link) {
    var tokens = fileNameTokens(link);
    // An explicit -eng/-ro marker is authoritative: the report filenames contain
    // English words in both variants, so counting alone would tie.
    for (var i = 0; i < tokens.length; i++) {
        var marker = tokens[i];
        if (marker === "eng" || marker === "english" || marker === "en") return "en";
        if (marker === "ro" || marker === "rom" || marker === "romana" || marker === "romanian") return "ro";
    }
    var ro = 0;
    var en = 0;
    for (var j = 0; j < tokens.length; j++) {
        var token = tokens[j];
        if (RO_WORDS[token]) ro++;
        if (EN_WORDS[token]) en++;
    }
    if (en > ro) return "en";
    if (ro > en) return "ro";
    return "";
}

// The attachment search runs against the Romanian table title. Map its common words
// to their English equivalents so the right English PDF wins among several files.
var RO_TO_EN = {
    raport: ["report"], raportul: ["report"], rapoarte: ["reports"],
    raportare: ["reporting"], semestrial: ["half", "yearly"],
    semestriala: ["half", "yearly"], semestriale: ["half", "yearly"],
    anual: ["annual"], anuala: ["annual"], anuale: ["annual"],
    comunicat: ["press", "release"], comunicatul: ["press", "release"], presa: ["press"],
    rezultate: ["results"], rezultat: ["results"], rezult: ["results"],
    financiar: ["financial"], financiare: ["financial"], financiarul: ["financial"],
    situatii: ["statements"], situatia: ["statement"],
    convocare: ["convening"], convocarea: ["convening"],
    notificare: ["notice", "notification"], notificarea: ["notice", "notification"],
    hotarare: ["resolution"], hotararea: ["resolution"], decizie: ["decision", "resolution"],
    tranzactii: ["transactions"], tranzactie: ["transaction"], tranzactiile: ["transactions"],
    consiliu: ["board"], consiliul: ["board"], adunarea: ["meeting"],
    actionari: ["shareholders"], actionarilor: ["shareholders"],
    modificari: ["changes"], modificare: ["change"], modificarea: ["change"],
    echipa: ["team"], echipei: ["team"], perioada: ["period"], perioad: ["period"],
    inchis: ["closed"], nchis: ["closed"], inchisa: ["closed"], nchisa: ["closed"],
    publicarea: ["publication"], publicare: ["publication"],
    programare: ["scheduling"], programarea: ["scheduling"],
    reprogramare: ["rescheduling"], reprogramarea: ["rescheduling"],
    conferinta: ["conference"], conferintei: ["conference"],
    telefonica: ["call"], telefonice: ["call"], ziua: ["day"], zilei: ["day"],
    investitorului: ["investor"], investitor: ["investor"], prag: ["threshold"],
    pragul: ["threshold"], detineri: ["holdings"], detinerile: ["holdings"],
    depasire: ["exceeded"], depasirea: ["exceeded"], curent: ["current"],
    curenta: ["current"], consolidat: ["consolidated"], consolidate: ["consolidated"],
    anexa: ["annex"], intermediar: ["interim"], intermediara: ["interim"],
    auditata: ["audited"], auditat: ["audited"], neauditata: ["unaudited"],
    dividende: ["dividend"], dividend: ["dividend"], majorare: ["increase"],
    majorarea: ["increase"], reducere: ["decrease"], reducerea: ["decrease"],
    rascumparare: ["buyback"], rascumpararea: ["buyback"], oferta: ["offer"],
    ofertei: ["offer"], prospect: ["prospectus"], fuziune: ["merger"],
    fuziunea: ["merger"], cesiune: ["transfer"], cesiunea: ["transfer"],
    instrainare: ["transfer"], ipoteca: ["pledge"], garantie: ["guarantee"],
    litigiu: ["litigation"], insolventa: ["insolvency"],
    reorganizare: ["restructuring"], lichidare: ["liquidation"], dizolvare: ["dissolution"],
    t1: ["q1"], t2: ["q2"], t3: ["q3"], t4: ["q4"], s1: ["1h"], s2: ["2h"]
};

function titleTokens(text) {
    var raw = String(text || "").toLowerCase().split(/[^a-z0-9]+/);
    var words = [];
    for (var i = 0; i < raw.length; i++) {
        var token = raw[i];
        if (token === "") continue;
        if (RO_TO_EN[token]) words = words.concat(RO_TO_EN[token]);
        else words.push(token);
    }
    return words;
}

function linkScore(link, words) {
    var tokens = fileNameTokens(link);
    var score = 0;
    for (var i = 0; i < tokens.length; i++) {
        if (words.indexOf(tokens[i]) >= 0) score++;
    }
    return score;
}

function pickLink(links, title, language) {
    if (!links || links.length === 0) return "";
    if (language !== "english") {
        var roWords = titleTokens(title);
        var bestRo = "";
        var bestRoScore = -1;
        for (var i = 0; i < links.length; i++) {
            if (languageOf(links[i]) !== "ro") continue;
            var roScore = linkScore(links[i], roWords);
            if (roScore > bestRoScore) {
                bestRoScore = roScore;
                bestRo = links[i];
            }
        }
        return bestRo !== "" ? bestRo : links[0];
    }
    var words = titleTokens(title);
    var best = "";
    var bestScore = -1;
    for (var j = 0; j < links.length; j++) {
        if (languageOf(links[j]) === "ro") continue;
        var score = linkScore(links[j], words);
        if (score > bestScore) {
            bestScore = score;
            best = links[j];
        }
    }
    return best;
}

// Turn the chosen English attachment's filename into a headline. The BVB table title
// is Romanian even when the PDF is English, so the English file is the best source.
function englishTitle(link) {
    var clean = String(link || "").split(/[?#]/)[0];
    var base = clean.substring(clean.lastIndexOf("/") + 1).replace(/\.pdf$/i, "");
    var parts = base.split("_");
    var slug = parts.length >= 3 ? parts.slice(2).join("_") : "";
    if (slug === "") return "";
    var tokens = slug.split(/[-_]+/);
    var acronyms = { PCL: 1, PLC: 1, EBITDA: 1, EBIT: 1, AGM: 1, EGM: 1, BVB: 1,
                     IR: 1, PDF: 1, CEO: 1, CFO: 1, MAR: 1 };
    var words = [];
    for (var i = 0; i < tokens.length; i++) {
        var token = tokens[i];
        if (token === "" || /^\d{8}$/.test(token)) continue;
        if (/^(eng|en|english|ro|rom|romana|romanian|final|signed)$/i.test(token)) continue;
        if (/^[A-Z]{4,}$/.test(token) && !acronyms[token])
            token = token.charAt(0) + token.substring(1).toLowerCase();
        words.push(token);
    }
    return words.join(" ").trim();
}

// Rows are: title (input.mLnkbttS), date (p.date), one or two PDF links (the first
// one is the Romanian document, the second the English one). The table is already
// newest-first; sorting by the parsed time keeps it correct and drops rows without a
// title. In English mode only rows with an English attachment are returned.
function parseTable(html, tableId, symbol, limit, language) {
    var table = new RegExp('<table[^>]*\\bid="' + tableId + '"[\\s\\S]*?</table>', "i").exec(String(html));
    if (!table) return [];
    var rows = table[0].match(/<tr\b[\s\S]*?<\/tr>/gi) || [];
    var base = baseSymbol(symbol);
    var items = [];
    var seen = {};
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        var tags = inputTags(row);
        var input = null;
        for (var t = 0; t < tags.length; t++) {
            if (/\bclass="[^"]*mLnkbttS/i.test(tags[t])) {
                input = tags[t];
                break;
            }
        }
        if (input === null) continue;
        var titleMatch = new RegExp('\\bvalue="([^"]*)"', "i").exec(input);
        if (!titleMatch) continue;
        var title = decodeEntities(titleMatch[1]).trim();
        if (title === "") continue;
        var dateMatch = new RegExp('<p[^>]*\\bclass="date[^"]*"[^>]*>([^<]*)<\\/p>', "i").exec(row);
        var time = dateMatch ? parseTime(dateMatch[1]) : 0;
        var links = [];
        var linkPattern = /<a[^>]*\bhref='([^']+)'/gi;
        var linkMatch;
        while ((linkMatch = linkPattern.exec(row)) !== null) {
            var href = absoluteLink(linkMatch[1]);
            if (href !== "") links.push(href);
        }
        var link = pickLink(links, title, language);
        if (link === "") {
            if (language === "english") continue;
            link = detailUrl(symbol);
        } else if (language === "english") {
            title = englishTitle(link);
            if (title === "") continue;
        }
        var key = String(link || title).toLowerCase();
        if (seen[key]) continue;
        seen[key] = true;
        items.push({
            id: "bvb:" + base + ":" + (link || title),
            title: title,
            publisher: SOURCE,
            source: SOURCE,
            lang: language === "english" ? "en" : "ro",
            link: link,
            time: time
        });
    }
    items.sort(function (a, b) { return (b.time || 0) - (a.time || 0); });
    var max = Number(limit);
    return max >= 0 ? items.slice(0, max) : items;
}

// The five announcements embedded in the instrument page.
function parseTop(html, symbol, limit, language) {
    var items = parseTable(html, "gv5News", symbol, limit, language);
    return items.length > 0 ? items : parseTable(html, "gv", symbol, limit, language);
}

// The full list returned by the "Stiri" postback (up to 60 announcements).
function parseFull(html, symbol, limit, language) {
    var items = parseTable(html, "gv", symbol, limit, language);
    return items.length > 0 ? items : parseTable(html, "gv5News", symbol, limit, language);
}

// Provider entry point. The instrument page carries the five newest announcements; when
// more are wanted, the "Stiri" postback is replayed for the full list. A failed POST
// still returns the five from the GET, exactly like the page itself.
function fetch(ctx, done) {
    var symbol = String(ctx.symbol || "").trim();
    var limit = Number(ctx.limit);
    var url = detailUrl(symbol);
    if (url === "") {
        done([], "", {});
        return;
    }
    var finished = false;
    var finish = function(items, error) {
        if (finished) return;
        finished = true;
        done(items, error, {});
    };

    Http.getText(url, { timeout: 20000 }, function(html, error) {
        if (error) {
            finish([], error.message);
            return;
        }
        var topItems = parseTop(html, symbol, limit, ctx.language);
        if (topItems.length >= limit) {
            finish(topItems, "");
            return;
        }
        var body = postBody(html);
        if (body === "") {
            finish(topItems, "");
            return;
        }
        Http.postText(url, body, {
            timeout: 20000,
            headers: { "Content-Type": "application/x-www-form-urlencoded" }
        }, function(reply, postError) {
            var items = [];
            if (!postError) items = parseFull(reply, symbol, limit, ctx.language);
            if (items.length === 0) items = topItems;
            finish(items, "");
        });
    });
}
