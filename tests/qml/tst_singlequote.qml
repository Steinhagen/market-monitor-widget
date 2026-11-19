import QtQuick
import QtTest
import "Fixture.js" as Fixture

TestCase {
    name: "SingleQuoteController"

    ListModel { id: stockRows }

    Component {
        id: fakeApplet
        QtObject {
            property string singleTicker: "SAP.DE"
            property string singleCompanyName: ""
            property string effectiveChartRange: "1D"
            property string chartRange: "1D"
            property string panelSymbol: "SAP.DE"
            property bool isMultiMode: false
            property bool showExtendedHours: true
            property int priceDecimals: -1
            property bool formatPrices: true
            property int refreshIntervalMinutes: 5
            property string lastUpdated: ""
            property string nextUpdate: ""
            property bool showingCachedData: true

            function scheduleQuoteRetry() {}
            function noteQuoteReceived() {}
            function queueQuotesCacheSave() {}
        }
    }

    function make() {
        var applet = createTemporaryObject(fakeApplet, this);

        var storeComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/state/QuoteStore.qml"));
        compare(storeComponent.status, Component.Ready, storeComponent.errorString());
        var store = storeComponent.createObject(this);
        verify(store !== null);

        var marketComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/MarketController.qml"));
        compare(marketComponent.status, Component.Ready, marketComponent.errorString());
        var market = marketComponent.createObject(this, { "showExtendedHours": true, "keepExtendedAfterClose": true });
        verify(market !== null);

        var controllerComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/SingleQuoteController.qml"));
        compare(controllerComponent.status, Component.Ready, controllerComponent.errorString());
        var controller = controllerComponent.createObject(this, {
            "applet": applet, "store": store, "market": market, "stockModel": null
        });
        verify(controller !== null);
        return { applet: applet, store: store, market: market, controller: controller };
    }

    function test_process() {
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.process(json, "SAP.DE", "1D");

        compare(o.store.singleDataTicker, "SAP.DE");
        compare(o.store.singleDataRange, "1D");
        compare(o.store.quoteCurrency, "EUR");
        compare(o.store.currentRawPrice, 213.45);
        compare(o.store.priceDecimals, 2);
        verify(o.store.currentPrice.indexOf("213.45") >= 0);
        verify(o.store.previousClose > 0);
        verify(o.store.chartDataPoints.length > 0);
        compare(o.store.chartDataPoints.length, o.store.chartTimestamps.length);
        verify(o.store.chartCandles.length > 0);
        verify(o.applet.lastUpdated !== "");
        verify(o.applet.nextUpdate !== "");
        compare(o.applet.showingCachedData, false);
        verify(o.market.hasSession("SAP.DE"));
        // The chart and the panel use the same configured range here.
        compare(o.store.panelCurrentPrice, o.store.currentPrice);
    }

    function test_processSeedsSingleBarChart() {
        // A symbol that started trading this morning answers the 6 month request with a
        // single daily bar. The controller seeds it from the previous close, so the chart
        // has a segment to draw, and records the listing date for the header note.
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-ant-6m.json")));
        o.controller.process(json, "ANT", "6M");

        compare(o.store.singleDataTicker, "ANT");
        compare(o.store.singleDataRange, "6M");
        compare(o.store.currentRawPrice, 97.77);
        compare(o.store.chartDataPoints.length, 2);
        compare(o.store.chartDataPoints[0], 83);
        compare(o.store.chartDataPoints[1], 97.77);
        compare(o.store.chartTimestamps.length, 2);
        verify(o.store.chartTimestamps[0] < o.store.chartTimestamps[1]);
        verify(o.store.chartCandles.length > 1);
        compare(o.store.chartListedSince, 1794556800);
    }

    function test_processLeavesCompleteHistoryUnannotated() {
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.process(json, "SAP.DE", "6M");
        compare(o.store.chartListedSince, 0);
        // A reply with bars leaves the "no data" state off and asks for no fallback.
        compare(o.store.chartNoData, false);
        compare(o.store.chartDailyFallback, false);
    }

    function test_processHandlesFundWithoutIntradayData() {
        // A mutual fund answers the 1D request with meta only: no timestamps, an empty
        // quote object. The price is still valid and the chart needs the daily fallback.
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-fbllx-1d.json")));
        var points = o.controller.process(json, "FBLLX", "1D");

        compare(points, 0);
        compare(o.store.chartNoData, true);
        compare(o.store.quoteIsDailyOnly, true);
        verify(o.store.currentPrice.indexOf("17.23") >= 0);
        verify(o.store.priceChange.indexOf("0.01") >= 0);
        compare(o.store.chartDataPoints.length, 0);
    }

    function test_processDailyFallbackFillsTheChart() {
        var o = make();
        var daily = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-fbllx-1m-daily.json")));
        var points = o.controller.processDailyFallback(daily, "FBLLX", "1D");

        compare(points, 4);
        compare(o.store.chartDataPoints.length, 4);
        compare(o.store.chartTimestamps.length, 4);
        compare(o.store.chartNoData, false);
        compare(o.store.chartDailyFallback, true);
        verify(o.store.chartCandles.length > 1);
        // A daily series has no session: the 1D session labels must stay off.
        compare(o.store.chartSessions, null);
        compare(o.store.chartSessionStart, 0);
        compare(o.store.chartPreSession, false);
        compare(o.store.chartReferencePrice, 17.9709);
    }

    function test_processPanel() {
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.processPanel(json, "SAP.DE", "1D");
        verify(o.store.panelCurrentPrice.indexOf("213.45") >= 0);
        verify(o.store.panelCurrentPercent.indexOf("%") > 0);
        compare(o.store.panelPriceDecimals, 2);
        compare(o.store.panelCurrentIsCached, false);
    }

    function test_processUsesYahooPrecisionForExchangeRates() {
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        var meta = json.chart.result[0].meta;
        meta.instrumentType = "CURRENCY";
        meta.currency = "USD";
        meta.priceHint = 4;
        meta.regularMarketPrice = 1.101;
        // Yahoo's FX `previousClose` can be stale (EURRON=X: 5.3013 instead of the
        // real 5.3418); the 2-day chart's chartPreviousClose is the correct one.
        meta.regularMarketPreviousClose = null;
        meta.previousClose = 1.0900;
        meta.chartPreviousClose = 1.0995;
        o.controller.process(json, "EURUSD=X", "1D");

        compare(o.store.priceDecimals, 4);
        compare(o.store.previousClose, 1.0995);
        compare(o.store.currentPrice, "$1.1010");
        compare(o.store.priceChange, "+0.0015");
        compare(o.store.percentChange, "+0.14%");
    }

    function test_processKeepsYahooPreviousCloseForEquities() {
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        var meta = json.chart.result[0].meta;
        meta.instrumentType = "EQUITY";
        meta.regularMarketPrice = 101;
        meta.regularMarketPreviousClose = null;
        meta.previousClose = 100;
        // In the 2-day window this points one day further back; equities must not use it.
        meta.chartPreviousClose = 90;
        o.controller.process(json, "TEST", "1D");

        compare(o.store.previousClose, 100);
        compare(o.store.priceChange, "+1.00");
    }

    function test_knownDailyPreviousClose() {
        stockRows.clear();
        stockRows.append({ "ticker": "EURRON=X", "prevClose": 5.3418 });
        var o = make();
        o.controller.stockModel = stockRows;
        o.applet.chartRange = "1D";

        // The 1D row already carries the real daily close, so the 5D/1M chart can
        // draw its reference line on the first paint without a wrong-value flash.
        compare(o.controller.knownDailyPreviousClose("EURRON=X"), 5.3418);

        // A value learned from a daily reply wins; it survives a range change.
        o.controller.rememberDailyClose("EURRON=X", 5.3454);
        compare(o.controller.knownDailyPreviousClose("EURRON=X"), 5.3454);

        // With a 5D list range the row's prevClose is the range start, not a daily
        // close; only an explicitly remembered value is safe to use.
        o.applet.chartRange = "5D";
        o.controller.dailyCloses = ({});
        compare(o.controller.knownDailyPreviousClose("EURRON=X"), 0);
    }
}
