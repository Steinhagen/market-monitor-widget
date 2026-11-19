.pragma library
// Yahoo's symbol search, used by the Symbols & Lists page. Returns the same compact
// { symbol, name } records the settings list shows.

.import "../../core/Http.js" as Http
.import "../../domain/symbols.js" as Symbols

function searchUrl(query) {
    return "https://query2.finance.yahoo.com/v1/finance/search?q=" + encodeURIComponent(query);
}

function parse(reply) {
    var quotes = reply && Array.isArray(reply.quotes) ? reply.quotes : [];
    var results = [];
    for (var i = 0; i < quotes.length; i++) {
        var item = quotes[i];
        if (!item || !item.symbol) continue;
        // A feed value must not become an arbitrary config string: keep only
        // symbols that the quote request and the widget's URL encoding can use.
        var symbol = String(item.symbol).trim().toUpperCase();
        if (!Symbols.isValidSymbol(symbol)) continue;
        results.push({
            symbol: symbol,
            name: item.shortname || item.longname || symbol
        });
    }
    return results;
}

// done(results, error) with results = [{ symbol, name }].
function search(query, done) {
    var text = String(query === undefined || query === null ? "" : query).trim();
    if (text === "") {
        done([], null);
        return;
    }
    Http.getJson(searchUrl(text), { timeout: 20000 }, function(reply, error) {
        if (error) {
            done(null, error);
            return;
        }
        done(parse(reply), null);
    });
}

// The same chart endpoint the quotes use, for one symbol. A 404 there is Yahoo saying
// the symbol does not exist, which is the check the settings page needs.
function checkUrl(symbol) {
    return "https://query1.finance.yahoo.com/v8/finance/chart/" + encodeURIComponent(symbol)
           + "?range=1d&interval=1d";
}

// done(valid, error): valid is true for a known symbol and false for one Yahoo does not
// have. A network failure passes valid = null with the error, so a valid symbol is never
// reported as unknown just because the check could not run.
function check(symbol, done) {
    var text = String(symbol === undefined || symbol === null ? "" : symbol).trim().toUpperCase();
    if (text === "" || !Symbols.isValidSymbol(text)) {
        done(false, null);
        return;
    }
    Http.getJson(checkUrl(text), { timeout: 15000 }, function(reply, error) {
        if (error) {
            if (error.status === 404 || error.status === 400) done(false, null);
            else done(null, error);
            return;
        }
        var result = reply && reply.chart ? reply.chart.result : null;
        done(!!(result && result.length > 0 && result[0] && result[0].meta), null);
    });
}
