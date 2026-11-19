import QtQuick
import "../domain/chart.js" as Chart
import "../domain/candles.js" as Candles
import "../domain/exchanges.js" as Exchanges
import "../domain/format.js" as Format
import "../domain/symbols.js" as Symbols
import "../providers/yahoo/chart.js" as YahooChart

// The single-stock and panel quote requests: fetching one symbol and turning the Yahoo
// chart reply into the values QuoteStore exposes. The multi-stock list keeps its own
// row processing in main.qml for now; it calls process() when it can reuse a reply.
Item {
    id: quotes

    property var applet
    property var store
    property var market
    property var stockModel
    // Last known daily close per FX symbol, so a non-1D chart can draw its
    // reference line correctly on the first paint instead of flashing Yahoo's
    // stale intraday previousClose and correcting a moment later.
    property var dailyCloses: ({})

    function rememberDailyClose(symbol, value) {
        var close = Number(value);
        if (!(close > 0) || Number(dailyCloses[symbol]) === close) return;
        var copy = Object.assign({}, dailyCloses);
        copy[symbol] = close;
        dailyCloses = copy;
    }

    // The 1D list row already carries the real daily close when the list range is
    // 1D; otherwise use a value remembered from an earlier 1D/daily reply.
    function knownDailyPreviousClose(symbol) {
        var cached = Number(dailyCloses[symbol]);
        if (cached > 0) return cached;
        if (stockModel && applet.chartRange === "1D") {
            for (var i = 0; i < stockModel.count; i++) {
                var row = stockModel.get(i);
                if (row.ticker !== symbol) continue;
                var prev = Number(row.prevClose);
                if (prev > 0) return prev;
            }
        }
        return 0;
    }

    function fetch(symbol, range) {
        var chartRange = range || applet.effectiveChartRange;
        // The header's change belongs to the range that produced it. Clear it while a
        // different range loads, so the previous range's percentage does not flash
        // under the new one for a moment.
        if (symbol === applet.singleTicker && chartRange !== store.singleDataRange) {
            store.priceChange = "";
            store.percentChange = "";
            store.isNeutral = false;
        }
        YahooChart.get(symbol, chartRange, applet.showExtendedHours, function(response, error) {
            if (error) { applet.scheduleQuoteRetry(); return; }
            // Ignore a reply for a range or symbol the user has already switched away from.
            if (chartRange !== applet.effectiveChartRange || symbol !== applet.singleTicker) return;
            process(response, symbol, chartRange);
        });
    }

    // Quote for the compact panel indicator, fetched separately when the chart uses a
    // range of its own. The panel always follows the configured data range.
    function fetchPanel(symbol) {
        var range = applet.chartRange;
        YahooChart.get(symbol, range, applet.showExtendedHours, function(response, error) {
            if (error) { applet.scheduleQuoteRetry(); return; }
            if (range !== applet.chartRange || symbol !== applet.panelSymbol) return;
            processPanel(response, symbol, range);
        });
    }

    function processPanel(json, symbol, range) {
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            market.setMarketSession(symbol, meta);
            if (!applet.isMultiMode && symbol === applet.singleTicker) {
                store.singleExchange = Exchanges.shortLabel(symbol, meta.exchangeName, meta.fullExchangeName);
                store.singleExchangeFull = Exchanges.fullLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            }
            var current = meta.regularMarketPrice;
            var curSym = Format.currencySymbol(meta.currency);
            var decimals = Format.decimalsFor(meta, applet.priceDecimals);
            var prev;
            if (range === "1D") {
                prev = Chart.previousCloseFor(meta, range);
            } else {
                prev = meta.chartPreviousClose;
                if (!prev || prev === 0) {
                    var quotes = result.indicators.quote[0].close;
                    var timestamps = result.timestamp;
                    var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
                    var cleanData = Chart.cleanChartData(quotes, timestamps, startTime, range).values;
                    prev = cleanData.length > 0 ? cleanData[0] : meta.regularMarketPreviousClose;
                }
            }
            if (range === "1D" && String(meta.instrumentType) === "CURRENCY")
                rememberDailyClose(symbol, prev);
            var change = current - prev;
            store.panelPriceDecimals = decimals;
            store.panelCurrentPrice = curSym + Format.number(current, false, decimals, applet.formatPrices);
            store.panelCurrentPercent = Format.percent(prev > 0 ? (change / prev) * 100 : 0,
                                                      applet.formatPrices);
            store.panelCurrentIsPositive = change >= 0;
            store.panelCurrentIsNeutral = Format.isFlatChange(change, decimals);
            store.panelCurrentIsCached = false;
            applet.noteQuoteReceived();
        } catch (e) { console.log("Error parsing panel quote: " + e); }
    }

    // The daily bars carry the real close for FX; keep only the reply that still
    // belongs to the symbol and range on screen.
    function refreshDailyPreviousClose(symbol, range) {
        YahooChart.getDaily(symbol, function(response, error) {
            if (error) return;
            var prev = Chart.lastCompletedDailyClose(response);
            if (!(prev > 0)) return;
            rememberDailyClose(symbol, prev);
            if (symbol !== applet.singleTicker || range !== applet.effectiveChartRange) return;
            if (store.chartPreSession) return;
            store.chartReferencePrice = prev;
            // The list-row cache reuses chartRef when that row is selected again.
            if (applet.isMultiMode && stockModel) {
                for (var i = 0; i < stockModel.count; i++) {
                    if (stockModel.get(i).ticker === symbol) {
                        stockModel.set(i, { "chartRef": prev });
                        break;
                    }
                }
            }
        });
    }

    function process(json, fallbackSymbol, range) {
        try {
            var chartRange = range || applet.effectiveChartRange;
            var result = json.chart.result[0];
            var meta = result.meta;
            var symbol = fallbackSymbol || applet.singleTicker;
            market.setMarketSession(symbol, meta);
            var quote = result.indicators.quote[0] || {};
            var quotes = quote.close || [];
            var timestamps = result.timestamp;

            applet.singleCompanyName = Symbols.companyName(meta, fallbackSymbol || applet.singleTicker);
            store.singleExchange = Exchanges.shortLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            store.singleExchangeFull = Exchanges.fullLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            store.currencySym = Format.currencySymbol(meta.currency);
            store.quoteCurrency = meta.currency || "";
            store.currentRawPrice = meta.regularMarketPrice;
            store.quoteTimestamp = meta.regularMarketTime || 0;
            // Yahoo's priceHint is the precision the quote page uses (2 for shares,
            // 4 for exchange rates). A fixed setting overrides it.
            var decimals = Format.decimalsFor(meta, applet.priceDecimals);
            store.priceDecimals = decimals;
            store.currentPrice = store.currencySym
                                 + Format.number(meta.regularMarketPrice, false,
                                                 decimals, applet.formatPrices);

            var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
            // The 1D chart plots the running pre-market, or the last completed regular
            // session when there is nothing current to show (see chartDayFor).
            var chartDay = chartRange === "1D" ? Chart.chartDayFor(meta, timestamps, quotes) : null;
            var preChart = chartRange === "1D" && Chart.isPreSessionDay(meta, chartDay);
            var day = (chartRange === "1D" && applet.showExtendedHours) ? chartDay : null;
            store.chartSessionStart = (chartDay && chartDay.regular) ? chartDay.regular.start : 0;
            // The chart is "current" when it shows today's pre-market or regular session;
            // otherwise it still shows a previous session and the view labels it.
            store.chartSessionCurrent = !(store.chartSessionStart > 0)
                || !(meta.currentTradingPeriod)
                || (meta.currentTradingPeriod.regular && store.chartSessionStart === meta.currentTradingPeriod.regular.start)
                || (meta.currentTradingPeriod.pre && store.chartSessionStart === meta.currentTradingPeriod.pre.start);
            store.chartPreSession = preChart;
            var chart = Chart.cleanChartData(quotes, timestamps, startTime, chartRange, quote, day);
            if (chartRange === "1D") {
                Chart.seedFirstSessionPoint(chart, (day && day.regular) ? day.regular.start : startTime, meta);
                store.chartListedSince = 0;
            } else {
                // A just-listed symbol has a single bar on the daily and coarser ranges;
                // seed it so the chart shows the move since the previous close instead of
                // staying blank, and remember that the range reaches past the listing.
                Chart.seedSinglePointSeries(chart, meta, chartRange);
                var firstTrade = Number(meta.firstTradeDate) || 0;
                var rangeStart = Chart.rangeStartTime(chartRange);
                store.chartListedSince = (firstTrade > 0 && rangeStart > 0 && firstTrade > rangeStart)
                                         ? firstTrade : 0;
            }
            var cleanData = chart.values;
            store.chartSessions = (day && cleanData.length >= 2)
                                  ? Chart.extendedSessionSeries(quotes, timestamps, day) : null;
            store.chartDataPoints = cleanData;
            store.chartTimestamps = chart.times;

            // The candlestick chart can be drawn from the same response; the reference
            // chart marks yesterday's close, so it reads the same way as the daily change.
            store.chartCandles = Candles.chartCandlesFor(chart, chartRange, quote, timestamps, day);
            // The pre-market is measured against the last regular close (the official
            // close, as shown in the regular quote); the regular chart uses the close
            // before the session it shows.
            var reference = preChart ? (meta.regularMarketPrice || 0) : 0;
            var fxRange = chartRange !== "1D"
                          && String(meta.instrumentType) === "CURRENCY" && !preChart;
            if (reference <= 0 && fxRange)
                reference = knownDailyPreviousClose(symbol);
            if (reference <= 0 && fxRange) {
                // No reliable daily close yet. Hide the reference line for the moment
                // instead of flashing Yahoo's stale intraday previousClose and then
                // replacing it when the daily reply arrives.
                store.chartReferencePrice = 0;
            } else {
                store.chartReferencePrice = reference > 0 ? reference
                    : Chart.dailyPreviousClose(meta, cleanData.length > 0 ? cleanData[0] : 0, chartRange);
            }
            // Yahoo's intraday meta repeats a stale previousClose for FX on every range
            // (EURRON=X: 5.3013 instead of the real daily close 5.3418). Longer ranges
            // do not carry a daily bar, so fetch the last completed daily close and use
            // it for the chart's "Previous close" line.
            if (fxRange)
                refreshDailyPreviousClose(symbol, chartRange);

            // Keep the row's cached chart in sync with every fresh chart, so choosing that
            // row again does not briefly show the older snapshot from the list refresh.
            if (applet.isMultiMode && chartRange === applet.chartRange && stockModel) {
                for (var ci = 0; ci < stockModel.count; ci++) {
                    if (stockModel.get(ci).ticker === symbol) {
                        stockModel.set(ci, {
                            "chartPoints": JSON.stringify(cleanData),
                            "chartTimes": JSON.stringify(chart.times),
                            "chartSessions": store.chartSessions,
                            "chartCandles": JSON.stringify(store.chartCandles),
                            "chartRef": store.chartReferencePrice,
                            "chartListedSince": store.chartListedSince,
                            "chartPre": store.chartPreSession,
                            "chartSessionStart": store.chartSessionStart,
                            "chartSessionCurrent": store.chartSessionCurrent,
                            "quoteTime": store.quoteTimestamp
                        });
                        break;
                    }
                }
            }

            if (chartRange === "1D") {
                store.previousClose = Chart.previousCloseFor(meta, chartRange);
            } else {
                store.previousClose = meta.chartPreviousClose;
                if (!store.previousClose || store.previousClose === 0) {
                    store.previousClose = cleanData.length > 0 ? cleanData[0] : meta.regularMarketPreviousClose;
                }
            }
            if (chartRange === "1D" && String(meta.instrumentType) === "CURRENCY")
                rememberDailyClose(symbol, store.previousClose);

            var change = meta.regularMarketPrice - store.previousClose;
            store.isPositive = change >= 0;
            store.isNeutral = Format.isFlatChange(change, decimals);
            store.priceChange = Format.number(change, true, decimals, applet.formatPrices);
            store.percentChange = Format.percent((change / store.previousClose) * 100,
                                                applet.formatPrices);

            // In single mode this response can also serve the panel when the chart is
            // showing the configured range. When the chart has its own range, a separate
            // panel request supplies these values instead.
            if (!applet.isMultiMode && chartRange === applet.chartRange) {
                store.panelCurrentPrice = store.currentPrice;
                store.panelCurrentPercent = store.percentChange;
                store.panelCurrentIsPositive = store.isPositive;
                store.panelCurrentIsNeutral = store.isNeutral;
                store.panelCurrentIsCached = false;
            }

            var now = new Date();
            applet.lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
            var next = new Date(now.getTime() + (applet.refreshIntervalMinutes * 60000));
            applet.nextUpdate = next.toLocaleTimeString(Qt.locale(), "HH:mm");
            store.singleDataRange = chartRange;
            store.singleDataTicker = symbol;
            if (!applet.isMultiMode) applet.showingCachedData = false;
            applet.noteQuoteReceived();
            applet.queueQuotesCacheSave();
        } catch (e) { console.log("Error parsing single: " + e); }
    }
}
