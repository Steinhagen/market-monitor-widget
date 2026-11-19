import QtQuick
import QtTest
import "Fixture.js" as Fixture

TestCase {
    name: "WatchlistController"

    Component {
        id: fakeApplet
        QtObject {
            property string multiTickers: "TLV.RO, SAP.DE"
            property bool sortAlphabetically: false
            property string manualPanelTickerOverride: ""
            property string panelTicker: ""
            property string singleTicker: ""
            property string loadingText: "Loading..."
            property string chartRange: "1D"
            property string effectiveChartRange: "1D"
            property bool isMultiMode: true
            property bool showExtendedHours: true
            property int priceDecimals: -1
            property bool formatPrices: true
            property int refreshIntervalMinutes: 5
            property string lastUpdated: ""
            property string nextUpdate: ""

            function applyCachedQuotesToRows() {}
            function scheduleQuoteRetry() {}
            function noteQuoteReceived() {}
            function queueQuotesCacheSave() {}
        }
    }

    Component {
        id: fakeSingleQuotes
        QtObject {
            property int calls: 0
            function process(json, symbol, range) { calls++ }
        }
    }

    function make() {
        var applet = createTemporaryObject(fakeApplet, this);
        var single = createTemporaryObject(fakeSingleQuotes, this);

        var storeComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/state/QuoteStore.qml"));
        var store = storeComponent.createObject(this);
        var marketComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/MarketController.qml"));
        var market = marketComponent.createObject(this, { "showExtendedHours": true, "keepExtendedAfterClose": true });
        var controllerComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/WatchlistController.qml"));
        compare(controllerComponent.status, Component.Ready, controllerComponent.errorString());
        var controller = controllerComponent.createObject(this, {
            "applet": applet, "store": store, "market": market, "singleQuotes": single
        });
        verify(controller !== null);
        return { applet: applet, store: store, market: market, single: single, controller: controller };
    }

    function test_configuredTickers() {
        var o = make();
        o.applet.multiTickers = "TLV.RO, , SAP.DE ";
        compare(o.controller.configuredTickers().join(","), "TLV.RO,SAP.DE");
        o.applet.sortAlphabetically = true;
        compare(o.controller.configuredTickers().join(","), "SAP.DE,TLV.RO");
        // The field is free text: the same ticker typed twice keeps one row, otherwise
        // the second copy can never be fed (replies are matched by ticker).
        o.applet.sortAlphabetically = false;
        o.applet.multiTickers = "AAPL, aapl, TSLA, AAPL";
        compare(o.controller.configuredTickers().join(","), "AAPL,TSLA");
    }

    function test_markInvalidRow() {
        var o = make();
        o.controller.ensureRows(["FBLL"]);
        o.controller.markInvalidRow("FBLL");
        var row = o.controller.model.get(0);
        compare(row.invalid, true);
        compare(row.price, "---");
        compare(row.change, "");
        compare(JSON.parse(row.chartPoints).length, 0);
        // The panel indicator follows this row when it is the panel's ticker.
        compare(o.applet.panelTicker, "FBLL");
        compare(o.store.panelInvalid, true);
        compare(o.store.panelCurrentPrice, "—");
        compare(o.store.panelCurrentPercent, "");
    }

    function test_processRowFeedsEveryCopyOfATicker() {
        // A model built before the list was deduplicated can still hold the same ticker
        // twice; both rows must get the reply instead of the second staying empty.
        var o = make();
        o.controller.ensureRows(["SAP.DE", "SAP.DE"]);
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.processRow("SAP.DE", json, "1D");
        compare(o.controller.model.count, 2);
        verify(o.controller.model.get(0).price.indexOf("213.45") >= 0);
        verify(o.controller.model.get(1).price.indexOf("213.45") >= 0);
    }

    function test_ensureRows() {
        var o = make();
        o.controller.ensureRows(["SAP.DE", "TLV.RO"]);
        compare(o.controller.model.count, 2);
        compare(o.applet.panelTicker, "SAP.DE");
        compare(o.applet.singleTicker, "SAP.DE");
        compare(o.controller.model.get(0).ticker, "SAP.DE");
        // Re-running with the same list keeps the rows.
        o.controller.ensureRows(["SAP.DE", "TLV.RO"]);
        compare(o.controller.model.count, 2);
    }

    function test_processRow() {
        var o = make();
        o.controller.ensureRows(["SAP.DE"]);
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.processRow("SAP.DE", json, "1D");

        compare(o.controller.model.count, 1);
        var row = o.controller.model.get(0);
        compare(row.ticker, "SAP.DE");
        compare(row.currency, "EUR");
        compare(row.decimals, 2);
        verify(row.price.indexOf("213.45") >= 0);
        verify(row.pct.indexOf("%") > 0);
        verify(JSON.parse(row.chartPoints).length > 0);
        compare(JSON.parse(row.chartPoints).length, JSON.parse(row.chartTimes).length);
        compare(row.cached, false);
        // The panel row also refreshes the panel quote and reuses the chart reply.
        compare(o.store.panelCurrentPrice, row.price);
        verify(o.applet.lastUpdated !== "");
        compare(o.single.calls, 1);
    }

    function test_processRowUpdatesTheSingleViewForItsOwnTicker() {
        var o = make();
        o.controller.ensureRows(["SAP.DE"]);
        // The panel indicator may be auto-cycling another stock while the expanded
        // single view still shows SAP.DE; its row must keep the header current.
        o.applet.panelTicker = "OTHER";
        o.applet.singleTicker = "SAP.DE";
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.processRow("SAP.DE", json, "1D");
        compare(o.single.calls, 1);
    }

    function test_processRow_flatIsNeutral() {
        var o = make();
        o.controller.ensureRows(["SAP.DE"]);
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        var meta = json.chart.result[0].meta;
        // The regular quote is unchanged from the previous close: 0.00 (0.00%).
        meta.regularMarketPrice = meta.previousClose;
        meta.regularMarketPreviousClose = meta.previousClose;
        o.controller.processRow("SAP.DE", json, "1D");

        var row = o.controller.model.get(0);
        compare(row.isNeutral, true);
        compare(o.store.panelCurrentIsNeutral, true);
        // The boolean is still the "not negative" fallback; views check neutral first.
        compare(row.isPos, true);
    }

    function test_ensureRows_rebuildsWhenTickersChange() {
        var o = make();
        o.controller.ensureRows(["SAP.DE", "TLV.RO"]);
        compare(o.controller.model.count, 2);
        // Same number of tickers, different symbols: the old rows must not be kept.
        o.applet.multiTickers = "AAPL, MSFT";
        o.controller.ensureRows(["AAPL", "MSFT"]);
        compare(o.controller.model.count, 2);
        compare(o.controller.model.get(0).ticker, "AAPL");
        compare(o.controller.model.get(1).ticker, "MSFT");
    }

    function test_processRow_ignoresRemovedTicker() {
        var o = make();
        o.applet.multiTickers = "NVDA, AMD";
        o.controller.ensureRows(["NVDA", "AMD"]);
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        // A reply left over from the previous watchlist must not add its row back.
        o.controller.processRow("SAP.DE", json, "1D");
        compare(o.controller.model.count, 2);
        compare(o.controller.model.get(0).ticker, "NVDA");
        compare(o.controller.model.get(1).ticker, "AMD");
        // Replies for configured symbols still update their rows.
        o.controller.processRow("NVDA", json, "1D");
        compare(o.controller.model.count, 2);
        verify(o.controller.model.get(0).price.indexOf("213.45") >= 0);
    }
}
