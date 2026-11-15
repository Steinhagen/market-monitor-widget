.pragma library
// Number and money formatting. The options are passed in instead of read from the
// configuration, so the same helpers work in the settings pages and in tests.

.import "currencies.js" as Currency

// Two decimals unless decimals are hidden (they are kept for a change, where the
// decimals carry the meaning), with thousands separators when formatting is on.
// `amount` is returned unchanged when it is not a number.
function number(amount, isChange, hideDecimals, formatPrices) {
    var num = parseFloat(amount);
    if (isNaN(num)) return amount;

    var isPositive = num >= 0;
    var absNum = Math.abs(num);

    var hideDecs = hideDecimals && !isChange;
    var formatted = hideDecs ? Math.round(absNum).toString() : absNum.toFixed(2);

    if (formatPrices) {
        var parts = formatted.split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        formatted = parts.join(".");
    }

    var sign = "";
    var roundedZero = hideDecs ? Math.round(absNum) === 0
                               : Number(absNum.toFixed(2)) === 0;
    if (roundedZero) {
        // A tiny negative move must not read "-0.00"; the neutral state shows 0.00.
        formatted = hideDecs ? "0" : "0.00";
    } else if (isChange && isPositive && num > 0) {
        sign = "+";
    } else if (!isPositive) {
        sign = "-";
    }

    return sign + formatted;
}

// True when a change rounds to 0.00 with the two decimals the views use for changes.
// Such a day is flat, not a tiny gain/loss: the arrow and the change text use the
// neutral colour instead of green/red. The percent follows the same change, so it is
// not checked separately (a 0.01 move on a very expensive stock displays 0.00% but is
// still a one-cent move).
function isFlatChange(change) {
    var num = Number(change);
    return isFinite(num) && Math.abs(num) < 0.005;
}

// The symbol in front of a value. Yahoo occasionally reports the literal text "null"
// for a missing currency.
function currencySymbol(code) {
    if (!code || code === "null") return "";
    return Currency.symbol(code);
}

// "-$1,234.50", or "+$1,234.50" when `signed` and the amount is positive.
function money(symbol, value, signed, hideDecimals, formatPrices) {
    var sign = value < 0 ? "-" : (signed && value > 0 ? "+" : "");
    return sign + symbol + number(Math.abs(value), false, hideDecimals, formatPrices);
}
