import QtQuick
import QtTest
import "../../contents/ui/domain/format.js" as Format

TestCase {
    name: "Format"

    function test_number() {
        compare(Format.number(1234.567, false, 2, true), "1,234.57");
        compare(Format.number(1234.567, false, 0, true), "1,235");
        compare(Format.number(1234.567, false, 2, false), "1234.57");
        compare(Format.number(1234.567, false, 4, true), "1,234.5670");
        // A change keeps at least two decimals even when prices hide them, and carries a sign.
        compare(Format.number(1.5, true, 0, false), "+1.50");
        compare(Format.number(-1.5, true, 0, false), "-1.50");
        compare(Format.number(0, true, 2, false), "0.00");
        // An exchange-rate change keeps the price's four decimals.
        compare(Format.number(0.0012, true, 4, false), "+0.0012");
        // A move that rounds to zero is shown without a sign, matching the neutral state.
        compare(Format.number(-0.001, true, 2, false), "0.00");
        compare(Format.number(0.001, true, 2, false), "0.00");
        compare(Format.number(-0.00001, true, 4, false), "0.0000");
        // Non-numeric values are passed through.
        compare(Format.number("n/a", false, 2, true), "n/a");
    }

    function test_autoDecimals() {
        // Yahoo's own hint: 2 decimals for shares, 4 for exchange rates.
        compare(Format.decimalsFor({ instrumentType: "EQUITY", regularMarketPrice: 213.45, priceHint: 2 }, -1), 2);
        compare(Format.decimalsFor({ instrumentType: "CURRENCY", regularMarketPrice: 1.101, priceHint: 4 }, -1), 4);
        // A fixed setting overrides the hint.
        compare(Format.decimalsFor({ instrumentType: "CURRENCY", regularMarketPrice: 1.101, priceHint: 4 }, 2), 2);
        compare(Format.decimalsFor({ instrumentType: "EQUITY", regularMarketPrice: 213.45, priceHint: 2 }, 0), 0);
        // A tiny crypto price needs more decimals than its hint to stay readable.
        compare(Format.decimalsFor({ instrumentType: "CRYPTOCURRENCY", regularMarketPrice: 0.00000386, priceHint: 5 }, -1), 8);
        // A price with a usable hint is left alone.
        compare(Format.decimalsFor({ instrumentType: "CRYPTOCURRENCY", regularMarketPrice: 0.0593, priceHint: 4 }, -1), 4);
        // A missing hint falls back to the instrument type and the magnitude.
        compare(Format.decimalsFor({ instrumentType: "CURRENCY", regularMarketPrice: 5.3454 }, -1), 4);
        compare(Format.decimalsFor({ regularMarketPrice: 213.45 }, -1), 2);
    }

    function test_percent() {
        compare(Format.percent(0.567, true), "+0.57%");
        compare(Format.percent(-1.234, false), "-1.23%");
        // Percentages stay at two decimals even when prices use more.
        compare(Format.percent(0.1234, false), "+0.12%");
    }

    function test_isFlatChange() {
        verify(Format.isFlatChange(0, 2));
        verify(Format.isFlatChange(0.004, 2));
        verify(Format.isFlatChange(-0.004, 2));
        // 0.005 already rounds to 0.01, so it is a real move.
        verify(!Format.isFlatChange(0.005, 2));
        verify(!Format.isFlatChange(0.01, 2));
        verify(!Format.isFlatChange(-0.01, 2));
        verify(!Format.isFlatChange("n/a", 2));
        // With four decimals a 0.0001 move is not flat any more.
        verify(Format.isFlatChange(0.00004, 4));
        verify(!Format.isFlatChange(0.0001, 4));
    }

    function test_currencySymbol() {
        compare(Format.currencySymbol("USD"), "$");
        compare(Format.currencySymbol("GBp"), "GBp ");
        compare(Format.currencySymbol("null"), "");
        compare(Format.currencySymbol(""), "");
    }

    function test_money() {
        compare(Format.money("$", 1234.5, false, 2, true), "$1,234.50");
        compare(Format.money("$", 1234.5, true, 2, true), "+$1,234.50");
        compare(Format.money("$", -1234.5, true, 2, true), "-$1,234.50");
        compare(Format.money("$", 0, true, 2, true), "$0.00");
        compare(Format.money("$", 1234.5, false, 4, true), "$1,234.5000");
    }
}
