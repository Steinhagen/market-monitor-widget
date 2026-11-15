import QtQuick
import QtTest
import "../../contents/ui/domain/format.js" as Format

TestCase {
    name: "Format"

    function test_number() {
        compare(Format.number(1234.567, false, false, true), "1,234.57");
        compare(Format.number(1234.567, false, true, true), "1,235");
        compare(Format.number(1234.567, false, false, false), "1234.57");
        // A change keeps its decimals even when prices hide them, and carries a sign.
        compare(Format.number(1.5, true, true, false), "+1.50");
        compare(Format.number(-1.5, true, true, false), "-1.50");
        compare(Format.number(0, true, false, false), "0.00");
        // A move that rounds to zero is shown without a sign, matching the neutral state.
        compare(Format.number(-0.001, true, false, false), "0.00");
        compare(Format.number(0.001, true, false, false), "0.00");
        // Non-numeric values are passed through.
        compare(Format.number("n/a", false, false, true), "n/a");
    }

    function test_isFlatChange() {
        verify(Format.isFlatChange(0));
        verify(Format.isFlatChange(0.004));
        verify(Format.isFlatChange(-0.004));
        // 0.005 already rounds to 0.01, so it is a real move.
        verify(!Format.isFlatChange(0.005));
        verify(!Format.isFlatChange(0.01));
        verify(!Format.isFlatChange(-0.01));
        verify(!Format.isFlatChange("n/a"));
    }

    function test_currencySymbol() {
        compare(Format.currencySymbol("USD"), "$");
        compare(Format.currencySymbol("GBp"), "GBp ");
        compare(Format.currencySymbol("null"), "");
        compare(Format.currencySymbol(""), "");
    }

    function test_money() {
        compare(Format.money("$", 1234.5, false, false, true), "$1,234.50");
        compare(Format.money("$", 1234.5, true, false, true), "+$1,234.50");
        compare(Format.money("$", -1234.5, true, false, true), "-$1,234.50");
        compare(Format.money("$", 0, true, false, true), "$0.00");
    }
}
