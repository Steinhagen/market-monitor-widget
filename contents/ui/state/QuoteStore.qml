import QtQuick

// The quote and chart data the single-stock view and the panel show for the selected
// symbol. It is plain state with change notifications: the controller fills it, the
// views read it, and main.qml exposes the same property names as before via aliases.
QtObject {
    // Single-stock quote
    property string singleExchange: ""
    property string singleExchangeFull: ""
    property string currentPrice: "---"
    property double currentRawPrice: 0
    // Decimals the current price/change use, resolved per instrument by the controller.
    property int priceDecimals: 2
    property double quoteTimestamp: 0
    property string priceChange: "+0.00"
    property string percentChange: "+0.00%"
    property string currencySym: ""
    property string quoteCurrency: ""
    property double previousClose: 0
    property bool isPositive: true
    // The visible change is flat (0.00): use the neutral colour, not green/red.
    property bool isNeutral: false

    // Chart data for the shown range
    property var chartDataPoints: []
    property var chartTimestamps: []
    property var chartSessions: null
    property var chartCandles: []
    property double chartReferencePrice: 0
    property double chartSessionStart: 0
    property bool chartSessionCurrent: true
    property bool chartPreSession: false

    // Which request produced the single view / the panel values
    property string singleDataRange: ""
    property string singleDataTicker: ""

    // Compact panel quote
    property string panelCurrentPrice: "---"
    property int panelPriceDecimals: 2
    property string panelCurrentPercent: "+0.00%"
    property bool panelCurrentIsPositive: true
    property bool panelCurrentIsNeutral: false
    property bool panelCurrentIsCached: false
}
