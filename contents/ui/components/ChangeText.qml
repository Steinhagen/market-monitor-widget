import QtQuick

// "+1.23 (+0.98%)" in the gain/loss colour. The sign carries the direction, so no
// triangle is added (it would look like the "^" index tickers start with).
Text {
    id: change

    property var applet
    property bool positive: true
    property bool neutral: false
    property string amount: ""
    property string percent: ""

    text: amount !== "" ? amount + (percent !== "" ? " (" + percent + ")" : "") : ""
    color: neutral ? (applet ? applet.neutralColor : "#8e8e93")
                    : positive ? (applet ? applet.positiveColor : "#4cd964")
                               : (applet ? applet.negativeColor : "#FF3B30")
    textFormat: Text.PlainText
    elide: Text.ElideRight
}
