import QtQuick
import QtTest
import "../../contents/ui/core/Text.js" as Text

TestCase {
    name: "Text"

    function test_escapeHtml() {
        compare(Text.escapeHtml("A & B < C > D"), "A &amp; B &lt; C &gt; D");
        compare(Text.escapeHtml("plain"), "plain");
        compare(Text.escapeHtml(null), "");
        compare(Text.escapeHtml(undefined), "");
        compare(Text.escapeHtml(42), "42");
    }

    function test_plainText() {
        // Used for ToolTip.text, which Qt Quick Controls always parses as rich text.
        compare(Text.plainText('<img src="https://x">'), 'img src="https://x"');
        compare(Text.plainText("a < b > c"), "a  b  c");
        compare(Text.plainText("plain"), "plain");
        compare(Text.plainText(null), "");
        compare(Text.plainText(undefined), "");
        compare(Text.plainText(42), "42");
    }
}
