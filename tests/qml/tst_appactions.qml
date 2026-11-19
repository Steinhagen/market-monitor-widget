import QtQuick
import QtTest

TestCase {
    name: "AppActions"

    Component {
        id: fakeApplet
        QtObject {
            property string panelTicker: ""
            property string manualPanelTickerOverride: ""
            property string singleTicker: ""
            property string singleCompanyName: ""
            property string singleExchange: ""
            property string singleExchangeFull: ""
            property string currentPrice: "---"
            property double currentRawPrice: 0
            property int quoteDecimals: 2
            property string priceChange: ""
            property string percentChange: ""
            property bool isPositive: true
            property bool isNeutral: false
            property double previousClose: 0
            property string currencySym: ""
            property string quoteCurrency: ""
            property double quoteTimestamp: 0
            property var chartDataPoints: []
            property var chartTimestamps: []
            property var chartSessions: null
            property var chartCandles: []
            property double chartReferencePrice: 0
            property double chartListedSince: 0
            property bool chartDailyFallback: false
            property bool chartNoData: false
            property bool panelInvalid: false
            property bool quoteInvalid: false
            property var chartCache: ({})
            property int refreshIntervalMinutes: 5
            property bool chartPreSession: false
            property double chartSessionStart: 0
            property bool chartSessionCurrent: true
            property string panelCurrentPrice: "---"
            property string panelCurrentPercent: "+0.00%"
            property bool panelCurrentIsPositive: true
            property bool panelCurrentIsNeutral: false
            property bool panelCurrentIsCached: false
            property string chartRange: "1D"
            property string effectiveChartRange: "1D"
            property string chartViewRangeActive: "1D"
            property int chartStyle: 0
            property int twoColumnLeftWidth: 0
            property string mouseRowLeftAction: "select"
            property string mouseMiddleAction: "refresh"
            property string mouseDoubleClickAction: "open"

            property int fetches: 0
            property int refreshes: 0
            function fetchSingleStock(symbol, range) { fetches++ }
            function refreshData() { refreshes++ }
        }
    }

    QtObject {
        id: fakeConfiguration
        property string selectedTicker: ""
        property string chartViewRange: ""
        property int chartStyle: 0
        property int twoColumnLeftWidth: 0
    }

    ListModel { id: rows }

    function make() {
        rows.clear();
        rows.append({
            "ticker": "SAP.DE", "name": "SAP SE", "price": "€213.45",
            "change": "+1.20", "pct": "+0.57%", "isPos": true,
            "chartPoints": "[211,212]", "chartTimes": "[10,20]",
            "chartSessions": ({}), "chartCandles": "[]", "chartRef": 212.25,
            "chartPre": false, "chartSessionStart": 0, "chartSessionCurrent": true,
            "quoteTime": 5, "prevClose": 212.25, "currentRaw": 213.45,
            "decimals": 2,
            "currencySym": "€ ", "currency": "EUR",
            "exchange": "XETRA", "exchangeFull": "XETRA", "invalid": false, "cached": false
        });
        var applet = createTemporaryObject(fakeApplet, this);
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/app/AppActions.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var actions = component.createObject(this, {
            "applet": applet, "model": rows, "configuration": fakeConfiguration
        });
        verify(actions !== null);
        return { applet: applet, actions: actions };
    }

    function resetConfig() {
        fakeConfiguration.selectedTicker = "";
        fakeConfiguration.chartViewRange = "";
        fakeConfiguration.chartStyle = 0;
        fakeConfiguration.twoColumnLeftWidth = 0;
    }

    function test_selectTicker() {
        resetConfig();
        var o = make();
        o.actions.selectTicker("SAP.DE", true);
        compare(o.applet.panelTicker, "SAP.DE");
        compare(o.applet.singleTicker, "SAP.DE");
        compare(o.applet.currentPrice, "€213.45");
        compare(o.applet.quoteDecimals, 2);
        compare(o.applet.chartDataPoints.length, 2);
        compare(fakeConfiguration.selectedTicker, "SAP.DE");
        // The row already had a chart for the selected range.
        compare(o.applet.fetches, 0);
    }

    function test_selectTickerWithoutPersisting() {
        resetConfig();
        var o = make();
        o.actions.selectTicker("SAP.DE", false);
        compare(fakeConfiguration.selectedTicker, "");
        compare(o.applet.panelTicker, "SAP.DE");
    }

    function test_selectTickerWithoutCachedChartClearsTheOldOne() {
        // A row that has not been quoted yet must not leave the previous ticker's chart
        // and change under the new name while its own request is in flight.
        resetConfig();
        var o = make();
        o.applet.chartDataPoints = [1, 2];
        o.applet.priceChange = "+1.20";
        o.applet.percentChange = "+0.57%";
        rows.set(0, { "chartPoints": "[]", "chartTimes": "[]", "chartCandles": "[]" });

        o.actions.selectTicker("SAP.DE", false);
        compare(o.applet.chartDataPoints.length, 0);
        compare(o.applet.priceChange, "");
        compare(o.applet.percentChange, "");
        compare(o.applet.fetches, 1);
    }

    function test_updatePanelFromRow() {
        var o = make();
        o.actions.updatePanelFromRow("SAP.DE");
        compare(o.applet.panelCurrentPrice, "€213.45");
        compare(o.applet.panelCurrentPercent, "+0.57%");
        compare(o.applet.panelCurrentIsCached, false);
    }

    function test_selectTickerReusesTheChartCacheForAnotherRange() {
        // The list row only carries the list range. With the in-chart buttons showing a
        // different range, the chart this ticker already produced for it is reused, so a
        // selection is not a network round trip.
        resetConfig();
        var o = make();
        o.applet.chartRange = "1D";
        o.applet.effectiveChartRange = "Max";
        o.applet.chartCache = {
            "SAP.DE|Max": {
                time: Date.now(),
                points: [1, 2, 3], times: [10, 20, 30], candles: [], sessions: null,
                reference: 2, previousClose: 2, change: "+1.00", pct: "+0.50%",
                isPositive: true, isNeutral: false
            }
        };

        o.actions.selectTicker("SAP.DE", false);
        compare(o.applet.chartDataPoints.length, 3);
        compare(o.applet.chartTimestamps.length, 3);
        compare(o.applet.priceChange, "+1.00");
        compare(o.applet.percentChange, "+0.50%");
        compare(o.applet.previousClose, 2);
        compare(o.applet.fetches, 0);

        // An entry older than a refresh cycle is still shown at once, and refreshed in
        // the background instead of leaving the card empty.
        o.applet.chartCache = {
            "SAP.DE|Max": { time: Date.now() - 3600000, points: [1, 2, 3], times: [10, 20, 30] }
        };
        o.actions.selectTicker("SAP.DE", false);
        compare(o.applet.chartDataPoints.length, 3);
        compare(o.applet.fetches, 1);
    }

    function test_panelInvalidFollowsTheSelectedRow() {
        // Selecting an unknown ticker marks the panel; selecting a valid one after it must
        // clear the mark and show that row's values again.
        resetConfig();
        var o = make();
        rows.append({
            "ticker": "FBLL", "name": "FBLL", "price": "---",
            "change": "", "pct": "", "isPos": true,
            "chartPoints": "[]", "chartTimes": "[]",
            "chartCandles": "[]", "cached": false, "invalid": true
        });

        o.actions.selectTicker("FBLL", false);
        compare(o.applet.panelInvalid, true);
        compare(o.applet.panelCurrentPrice, "—");
        compare(o.applet.panelCurrentPercent, "");

        o.applet.quoteInvalid = true;
        o.actions.selectTicker("SAP.DE", false);
        compare(o.applet.panelInvalid, false);
        compare(o.applet.quoteInvalid, false);
        verify(o.applet.panelCurrentPrice.indexOf("213.45") >= 0);
        compare(o.applet.panelCurrentPercent, "+0.57%");
    }

    function test_chartRangeAndStyle() {
        resetConfig();
        var o = make();
        o.applet.singleTicker = "SAP.DE";
        o.actions.setChartViewRange("5D");
        compare(o.applet.chartViewRangeActive, "5D");
        compare(fakeConfiguration.chartViewRange, "5D");
        compare(o.applet.fetches, 1);

        o.actions.setChartStyle(1);
        compare(fakeConfiguration.chartStyle, 1);
    }

    function test_twoColumnWidth() {
        resetConfig();
        var o = make();
        o.actions.setTwoColumnLeftWidth(-4);
        compare(o.applet.twoColumnLeftWidth, 0);
        o.actions.setTwoColumnLeftWidth(320.4);
        compare(o.applet.twoColumnLeftWidth, 320);
        o.actions.saveTwoColumnLeftWidth();
        compare(fakeConfiguration.twoColumnLeftWidth, 320);
    }

    function test_mouseActions() {
        var o = make();
        compare(o.actions.performMiddleClick("SAP.DE"), true);
        compare(o.applet.refreshes, 1);
    }
}
