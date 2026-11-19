import QtQuick
import QtTest
import "../../contents/ui/domain/chart.js" as Chart

TestCase {
    name: "Chart"

    function test_inExtendedSession() {
        var period = { start: 100, end: 200 };
        verify(Chart.inExtendedSession(period, 100, "pre"));
        verify(!Chart.inExtendedSession(period, 200, "pre"));
        verify(Chart.inExtendedSession(period, 200, "post"));
        verify(!Chart.inExtendedSession(null, 150, "pre"));
    }

    function test_tradingDays() {
        var meta = { tradingPeriods: { regular: [[{ start: 10, end: 20 }]] },
                     currentTradingPeriod: { regular: { start: 10, end: 20 } } };
        var days = Chart.tradingDays(meta);
        compare(days.length, 1);
        compare(days[0].regular.start, 10);
        compare(days[0].pre, null);
        compare(Chart.tradingDays(null).length, 0);
    }

    function test_dailyPreviousClose() {
        compare(Chart.dailyPreviousClose({ regularMarketPreviousClose: 10 }, 0), 10);
        compare(Chart.dailyPreviousClose({ regularMarketPrice: 10, fulldayChange: 2 }, 0), 8);
        compare(Chart.dailyPreviousClose({ regularMarketPrice: 11, regularMarketChangePercent: 10 }, 0), 10);
        compare(Chart.dailyPreviousClose(null, 7), 7);
        compare(Chart.dailyPreviousClose(null, 0), 0);
    }

    function test_previousCloseForCurrency() {
        // Yahoo's FX previousClose can be stale; the 2-day chartPreviousClose is the
        // last completed daily close and must win for the 1D change.
        var fx = { instrumentType: "CURRENCY", regularMarketPreviousClose: null,
                   previousClose: 5.3013, chartPreviousClose: 5.3418 };
        compare(Chart.previousCloseFor(fx, "1D"), 5.3418);
        compare(Chart.dailyPreviousClose(fx, 0, "1D"), 5.3418);
        // Longer ranges keep Yahoo's existing previous/range close handling.
        compare(Chart.previousCloseFor(fx, "5D"), 5.3013);
    }

    function test_previousCloseForEquity() {
        var stock = { instrumentType: "EQUITY", previousClose: 100, chartPreviousClose: 90 };
        compare(Chart.previousCloseFor(stock, "1D"), 100);
        compare(Chart.dailyPreviousClose(stock, 0, "1D"), 100);
    }

    function test_lastCompletedDailyClose() {
        // The current day's bar starts at currentTradingPeriod.regular.start; the bar
        // before it is the last completed daily close.
        var daily = { chart: { result: [{
            meta: { currentTradingPeriod: { regular: { start: 300 } } },
            timestamp: [100, 200, 300],
            indicators: { quote: [{ close: [5.3376, 5.3418, 5.3454] }] }
        }] } };
        compare(Chart.lastCompletedDailyClose(daily), 5.3418);

        // A closed market may omit the current day's bar: the last bar is the close.
        var closed = { chart: { result: [{
            meta: { currentTradingPeriod: { regular: { start: 300 } } },
            timestamp: [100, 200],
            indicators: { quote: [{ close: [5.3376, 5.3418] }] }
        }] } };
        compare(Chart.lastCompletedDailyClose(closed), 5.3418);

        compare(Chart.lastCompletedDailyClose(null), 0);
    }

    function test_rangeStartTime() {
        var now = 1794556800;
        compare(Chart.rangeStartTime("1D", now), 0);
        compare(Chart.rangeStartTime("Max", now), 0);
        compare(Chart.rangeStartTime("6M", now), now - 182 * 86400);
        compare(Chart.rangeStartTime("1Y", now), now - 365 * 86400);
        compare(Chart.rangeStartTime("5Y", now), now - 5 * 365 * 86400);
        // YTD starts at local midnight on 1 January, whichever side of UTC the machine is.
        var date = new Date(now * 1000);
        compare(Chart.rangeStartTime("YTD", now),
                new Date(date.getFullYear(), 0, 1).getTime() / 1000);
    }

    function test_seedSinglePointSeries() {
        // A symbol listed today has a single daily bar; the previous close seeds it so
        // the chart has a segment to draw.
        var chart = { values: [97.77], times: [1794556800],
                      opens: [97.77], highs: [97.77], lows: [97.77], volumes: [1200000] };
        var meta = { regularMarketPreviousClose: 83, firstTradeDate: 1794556800 };
        verify(Chart.seedSinglePointSeries(chart, meta, "6M"));
        compare(chart.values.length, 2);
        compare(chart.values[0], 83);
        compare(chart.values[1], 97.77);
        // The listing day is the only bar, so the seed sits the day before it.
        compare(chart.times[0], 1794556800 - 86400);
        compare(chart.times[1], 1794556800);
        compare(chart.volumes[0], 0);
        compare(chart.opens.length, chart.values.length);

        // A listing older than the single bar seeds on the first trading day itself.
        var older = { values: [50], times: [1794556800],
                      opens: [50], highs: [50], lows: [50], volumes: [0] };
        verify(Chart.seedSinglePointSeries(older, { regularMarketPreviousClose: 40,
                                                    firstTradeDate: 1794300000 }, "5Y"));
        compare(older.times[0], 1794300000);

        // Without a previous close the only known price is used, so the plot is flat
        // instead of empty.
        var bare = { values: [12], times: [1794556800],
                     opens: [12], highs: [12], lows: [12], volumes: [0] };
        verify(Chart.seedSinglePointSeries(bare, { firstTradeDate: 1794556800 }, "Max"));
        compare(bare.values[0], 12);

        // A real series is left alone, and 1D keeps its own seeding.
        var full = { values: [1, 2], times: [100, 200],
                     opens: [1, 2], highs: [1, 2], lows: [1, 2], volumes: [0, 0] };
        verify(!Chart.seedSinglePointSeries(full, meta, "6M"));
        compare(full.values.length, 2);
        var oneDay = { values: [1], times: [100], opens: [1], highs: [1], lows: [1], volumes: [0] };
        verify(!Chart.seedSinglePointSeries(oneDay, meta, "1D"));
        compare(oneDay.values.length, 1);
    }
}
