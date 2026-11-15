import QtQuick
import QtTest
import "../../contents/ui/domain/symbols.js" as Symbols

TestCase {
    name: "Symbols"

    function test_companyName() {
        // A padded vendor short name is replaced by the long name.
        compare(Symbols.companyName({ shortName: "DEUTSCHE LUFTHANSA AG         V",
                                      longName: "Deutsche Lufthansa AG" }, "?"),
                "Deutsche Lufthansa AG");
        compare(Symbols.companyName({ shortName: "Apple Inc." }, "?"), "Apple Inc.");
        compare(Symbols.companyName({ shortName: "  A   B " }, "?"), "A B");
        compare(Symbols.companyName({}, "fallback"), "fallback");
        compare(Symbols.companyName(null, "fallback"), "fallback");
    }

    function test_displayTicker() {
        compare(Symbols.displayTicker("brd.ro", 0), "BRD.RO");
        compare(Symbols.displayTicker("brd.ro", 1), "BRD");
        compare(Symbols.displayTicker("brd.ro", 2), "BRD");
        compare(Symbols.displayTicker("aapl", 1), "AAPL");
    }

    function test_exchangeBadge() {
        compare(Symbols.exchangeBadge("BRD.RO", "BVB", 2), "BVB");
        compare(Symbols.exchangeBadge("BRD.RO", "", 2), "BVB");
        compare(Symbols.exchangeBadge("BRD.RO", "BVB", 1), "");
        // A plain US symbol has no suffix to replace.
        compare(Symbols.exchangeBadge("AAPL", "NASDAQ", 2), "");
    }

    function test_nameAndTicker() {
        compare(Symbols.nameAndTicker("Apple Inc.", "AAPL", false, "Loading..."),
                "Apple Inc. (AAPL)");
        compare(Symbols.nameAndTicker("Apple Inc.", "AAPL", true, "Loading..."),
                "AAPL (Apple Inc.)");
        compare(Symbols.nameAndTicker("AAPL", "AAPL", false, "Loading..."), "AAPL");
        compare(Symbols.nameAndTicker("Loading...", "AAPL", false, "Loading..."), "AAPL");
        compare(Symbols.nameAndTicker("", "AAPL", false, "Loading..."), "AAPL");
    }

    function test_isValidSymbol() {
        verify(Symbols.isValidSymbol("AAPL"));
        verify(Symbols.isValidSymbol("brd.ro"));
        verify(Symbols.isValidSymbol("  tlv.ro  "));
        verify(Symbols.isValidSymbol("^GSPC"));
        verify(Symbols.isValidSymbol("EURUSD=X"));
        verify(Symbols.isValidSymbol("BRK-B"));
        verify(Symbols.isValidSymbol("M&M.NS"));
        // Anything that could break a request URL, or is not a symbol at all.
        verify(!Symbols.isValidSymbol(""));
        verify(!Symbols.isValidSymbol("A B"));
        verify(!Symbols.isValidSymbol("A/B"));
        verify(!Symbols.isValidSymbol("AAPL;rm -rf /"));
        verify(!Symbols.isValidSymbol('<img src="https://x">'));
        verify(!Symbols.isValidSymbol(new Array(34).join("A")));
    }
}
