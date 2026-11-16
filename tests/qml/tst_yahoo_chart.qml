import QtQuick
import QtTest
import "../../contents/ui/providers/yahoo/chart.js" as YahooChart

TestCase {
    name: "YahooChart"

    function test_chartUrl() {
        compare(YahooChart.chartUrl("SAP.DE", "5D", false),
                "https://query1.finance.yahoo.com/v8/finance/chart/SAP.DE?range=5d&interval=15m");
        compare(YahooChart.chartUrl("SAP.DE", "1D", true),
                "https://query1.finance.yahoo.com/v8/finance/chart/SAP.DE?range=2d&interval=2m&includePrePost=true");
        compare(YahooChart.chartUrl("SAP.DE", "1D", false),
                "https://query1.finance.yahoo.com/v8/finance/chart/SAP.DE?range=2d&interval=2m");
    }

    function test_extendedUrl() {
        compare(YahooChart.extendedUrl("TLV.RO"),
                "https://query1.finance.yahoo.com/v8/finance/chart/TLV.RO?range=1d&interval=5m&includePrePost=true");
    }

    function test_dailyUrl() {
        compare(YahooChart.dailyUrl("EURRON=X"),
                "https://query1.finance.yahoo.com/v8/finance/chart/EURRON%3DX?range=5d&interval=1d");
    }

    function test_urlEncodesTheSymbol() {
        // Separators such as ^, & and = have to survive as data, not as URL syntax.
        compare(YahooChart.chartUrl("^GSPC", "1D", false),
                "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=2d&interval=2m");
        compare(YahooChart.chartUrl("M&M.NS", "5D", false),
                "https://query1.finance.yahoo.com/v8/finance/chart/M%26M.NS?range=5d&interval=15m");
        compare(YahooChart.extendedUrl("EURUSD=X"),
                "https://query1.finance.yahoo.com/v8/finance/chart/EURUSD%3DX?range=1d&interval=5m&includePrePost=true");
    }
}
