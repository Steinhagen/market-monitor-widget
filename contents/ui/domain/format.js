.pragma library
// Number and money formatting. The options are passed in instead of read from the
// configuration, so the same helpers work in the settings pages and in tests.

.import "currencies.js" as Currency

// Automatic precision: use the hint Yahoo Finance sends with every quote.
var AUTO_DECIMALS = -1;
// Enough for sub-cent crypto prices; wider values would be unreadable.
var MAX_DECIMALS = 8;

// A configured precision is an integer from 0 to MAX_DECIMALS, or AUTO_DECIMALS.
function clampDecimals(value) {
    if (value === undefined || value === null || value === "") return AUTO_DECIMALS;
    var num = Number(value);
    if (!isFinite(num)) return AUTO_DECIMALS;
    num = Math.round(num);
    if (num < 0) return AUTO_DECIMALS;
    return Math.min(MAX_DECIMALS, num);
}

// The number of decimals to show for one instrument. `setting` is the user's choice:
// AUTO_DECIMALS follows Yahoo's priceHint (2 for shares, 4 for FX and small crypto,
// 5-6 for sub-cent coins), a value from 0 to MAX_DECIMALS forces that many.
//
// A very small price can need more decimals than the hint carries to stay readable
// (0.00000386 instead of 0.00000), so the automatic mode extends the hint until at
// least two significant digits are visible.
function decimalsFor(meta, setting) {
    var chosen = clampDecimals(setting);
    if (chosen >= 0) return chosen;

    var hint = Number(meta && meta.priceHint);
    if (!isFinite(hint) || hint < 0) hint = 2;
    hint = clampDecimals(hint);

    var price = Math.abs(Number(meta && meta.regularMarketPrice));
    if (!isFinite(price) || price <= 0) return hint;

    // Older cached replies have no hint; exchange rates always need four decimals.
    if (!meta || meta.priceHint === undefined || meta.priceHint === null) {
        if (String(meta && meta.instrumentType) === "CURRENCY" && hint < 4) hint = 4;
    }

    // Fewer than two significant digits would round a sub-cent price to all zeros.
    if (price * Math.pow(10, hint) < 10) {
        var needed = Math.ceil(-Math.log(price) / Math.LN10) + 2;
        if (needed > hint) hint = needed;
    }
    return Math.min(MAX_DECIMALS, hint);
}

// Changes are money amounts too: keep at least two decimals for a readable "+0.01",
// even when prices are shown as whole numbers.
function changeDecimals(decimals) {
    var dec = clampDecimals(decimals);
    if (dec < 0) dec = 2;
    return Math.max(2, dec);
}

// Formats an amount with the given number of decimals (AUTO_DECIMALS falls back to 2),
// with thousands separators when formatting is on. A change always gets a "+" or "-"
// sign and at least two decimals. `amount` is returned unchanged when it is not a
// number.
function number(amount, isChange, decimals, formatPrices) {
    var num = parseFloat(amount);
    if (isNaN(num)) return amount;

    var dec = isChange ? changeDecimals(decimals) : clampDecimals(decimals);
    if (dec < 0) dec = 2;

    var isPositive = num >= 0;
    var absNum = Math.abs(num);

    var formatted = absNum.toFixed(dec);

    if (formatPrices) {
        var parts = formatted.split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        formatted = parts.join(".");
    }

    var sign = "";
    var roundedZero = Number(absNum.toFixed(dec)) === 0;
    if (roundedZero) {
        // A tiny negative move must not read "-0.00"; the neutral state shows 0.00.
        formatted = dec > 0 ? "0." + new Array(dec + 1).join("0") : "0";
    } else if (isChange && isPositive && num > 0) {
        sign = "+";
    } else if (!isPositive) {
        sign = "-";
    }

    return sign + formatted;
}

// Percentages always use two decimals, whatever precision the price uses.
function percent(value, formatPrices) {
    return number(value, true, 2, formatPrices) + "%";
}

// True when a change rounds to zero at the precision the views use for changes. Such a
// day is flat, not a tiny gain/loss: the arrow and the change text use the neutral colour
// instead of green/red. The percent follows the same change, so it is not checked
// separately.
function isFlatChange(change, decimals) {
    var num = Number(change);
    if (!isFinite(num)) return false;
    var dec = changeDecimals(decimals);
    // Half of the smallest amount that would still round to a non-zero change.
    return Math.abs(num) < 0.5 / Math.pow(10, dec);
}

// The symbol in front of a value. Yahoo occasionally reports the literal text "null"
// for a missing currency.
function currencySymbol(code) {
    if (!code || code === "null") return "";
    return Currency.symbol(code);
}

// "-$1,234.50", or "+$1,234.50" when `signed` and the amount is positive.
function money(symbol, value, signed, decimals, formatPrices) {
    var sign = value < 0 ? "-" : (signed && value > 0 ? "+" : "");
    return sign + symbol + number(Math.abs(value), false, decimals, formatPrices);
}
