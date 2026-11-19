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
    // Epoch seconds of the symbol's first trading day when the selected range starts
    // before it (a recent IPO), so the view can say how far back the history goes.
    // 0 when the range is fully covered by the symbol's history.
    property double chartListedSince: 0
    // True once a reply arrived and it had no bars at all: the view then shows "no data
    // for this range" instead of an endless loading state.
    property bool chartNoData: false
    // True when the chart shows the daily month fallback used for instruments without
    // intraday data (mutual funds), where the 1D request returns no series at all.
    property bool chartDailyFallback: false
    // The quote is published once a day (a mutual fund), so the regular session has no
    // "first quote" to wait for; the price on screen is the current one.
    property bool quoteIsDailyOnly: false
    // Yahoo answered 404 for the selected symbol: it does not exist, so there is no
    // price or chart to show and the view says so instead of keeping stale values.
    property bool quoteInvalid: false
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
    // The panel indicator shows a symbol Yahoo does not know: the price and the change
    // are meaningless, so the indicator says "invalid" instead.
    property bool panelInvalid: false

    // The last chart per "symbol|range". The list only carries the chart of its own range,
    // so a chart viewed with another range (the in-chart buttons) was fetched again on
    // every selection; this keeps it for the next one.
    property var chartCache: ({})
}
