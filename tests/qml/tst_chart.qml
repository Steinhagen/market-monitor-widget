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
}
