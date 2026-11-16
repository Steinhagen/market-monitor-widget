import QtQuick
import QtTest
import "../../contents/ui/settings/importExport/backupFormat.js" as Backup

TestCase {
    name: "Backup"

    function makeConfig() {
        return {
            ticker: " brd.ro ",
            isMultiMode: false,
            showTwoList: true,
            multiTickers: "BRD.RO, TLV.RO",
            portfolioData: JSON.stringify([
                { ticker: "tlv.ro", shares: 10, averageCost: 20.5, currency: "ron",
                  addedDate: "2026-01-02" }
            ]),
            refreshInterval: 5,
            showNews: true,
            newsSourceYahoo: true,
            newsSourceBvb: true,
            newsSourceGoogle: true,
            newsLanguage: "english",
            newsLanguages: "ro,en,fr",
            formatPrices: true,
            priceDecimals: 4,
            themePreset: 0,
            themeColors: 0
        };
    }

    function test_roundTrip() {
        var backup = Backup.buildBackup(makeConfig(), "all", "2026-11-14T00:00:00Z");
        compare(backup.application, Backup.APPLICATION_ID);
        compare(backup.scope, "all");

        var parsed = Backup.parseBackup(Backup.toJson(backup));
        verify(parsed.ok);
        compare(parsed.data.ticker, "BRD.RO");
        compare(parsed.data.multiTickers, "BRD.RO, TLV.RO");
        var lots = JSON.parse(parsed.data.portfolioData);
        compare(lots.length, 1);
        compare(lots[0].ticker, "TLV.RO");
        compare(lots[0].currency, "RON");
        compare(parsed.settings.newsSourceGoogle, true);
        compare(parsed.settings.newsLanguage, "english");
        compare(parsed.settings.newsLanguages, "ro,en,fr");
        compare(parsed.settings.showNews, true);
        compare(parsed.settings.refreshInterval, 5);
        compare(parsed.settings.priceDecimals, 4);
    }

    function test_scope() {
        var settings = Backup.buildBackup(makeConfig(), "settings", "2026-11-14T00:00:00Z");
        compare(settings.data, undefined);
        verify(settings.settings !== undefined);

        var data = Backup.buildBackup(makeConfig(), "data", "2026-11-14T00:00:00Z");
        compare(data.settings, undefined);
        verify(data.data !== undefined);
    }

    function test_acceptsLegacyApplicationId() {
        var legacy = {
            application: Backup.LEGACY_APPLICATION_ID,
            format: 1,
            data: { ticker: "TLV.RO" }
        };
        var parsed = Backup.parseBackup(JSON.stringify(legacy));
        verify(parsed.ok);
        compare(parsed.data.ticker, "TLV.RO");
    }

    function test_importsLegacyAppBackup() {
        // A full backup from Plasma Stock Monitor: old application id, same format,
        // and the single selectedTheme key instead of themePreset/themeColors.
        var legacy = {
            application: "io.github.steinhagen.plasmastockmonitor",
            format: 1,
            exportedAt: "2025-01-01T00:00:00Z",
            scope: "all",
            data: {
                ticker: "tlv.ro",
                isMultiMode: false,
                showTwoList: true,
                multiTickers: "TLV.RO, BRD.RO",
                portfolio: [
                    { ticker: "tlv.ro", shares: 10, averageCost: 20.5, currency: "ron" }
                ],
                showPortfolioMode: true,
                portfolioCurrency: "RON"
            },
            settings: {
                selectedTheme: 0,
                refreshInterval: 5,
                showNews: true,
                newsSourceYahoo: true
            }
        };
        var parsed = Backup.parseBackup(JSON.stringify(legacy));
        verify(parsed.ok);
        compare(parsed.data.ticker, "TLV.RO");
        var lots = JSON.parse(parsed.data.portfolioData);
        compare(lots.length, 1);
        compare(lots[0].ticker, "TLV.RO");
        compare(parsed.settings.themePreset, 0);
        compare(parsed.settings.themeColors, 0);
        compare(parsed.settings.refreshInterval, 5);
        compare(parsed.settings.showNews, true);
    }

    function test_importsLegacyHideDecimals() {
        // 1.2 and older exported a boolean instead of the priceDecimals choice.
        var legacy = {
            application: Backup.APPLICATION_ID,
            format: 1,
            settings: { hideDecimals: true, formatPrices: true }
        };
        var parsed = Backup.parseBackup(JSON.stringify(legacy));
        verify(parsed.ok);
        compare(parsed.settings.priceDecimals, 0);
        compare(parsed.settings.hideDecimals, undefined);

        var automatic = Backup.parseBackup('{"settings":{"hideDecimals":false}}');
        verify(automatic.ok);
        compare(automatic.settings.priceDecimals, -1);
        compare(automatic.settings.hideDecimals, undefined);

        var tooMany = Backup.parseBackup('{"settings":{"priceDecimals":9}}');
        compare(tooMany.code, "outOfRange");
    }

    function test_rejectsBadFiles() {
        compare(Backup.parseBackup("").code, "emptyFile");
        compare(Backup.parseBackup("not json").code, "invalidJson");
        compare(Backup.parseBackup('[{"ticker":""}]').code, "invalidLot");
        compare(Backup.parseBackup('{"application":"someone.else"}').code, "notBackup");
        compare(Backup.parseBackup('{"format":99}').code, "newerFormat");
    }

    function test_validatesValues() {
        var tooBig = Backup.parseBackup('{"settings":{"refreshInterval":9999}}');
        compare(tooBig.code, "outOfRange");

        var wrongType = Backup.parseBackup('{"settings":{"showNews":"yes"}}');
        compare(wrongType.code, "invalidValue");

        var ticker = Backup.parseBackup('{"data":{"ticker":"  tlv.ro "}}');
        verify(ticker.ok);
        compare(ticker.data.ticker, "TLV.RO");

        var chartRange = Backup.parseBackup('{"settings":{"chartRange":"2D"}}');
        compare(chartRange.code, "invalidValue");

        var language = Backup.parseBackup('{"settings":{"newsLanguage":"bogus"}}');
        compare(language.code, "invalidValue");
        var multi = Backup.parseBackup('{"settings":{"newsLanguage":"multi"}}');
        verify(multi.ok);
        compare(multi.settings.newsLanguage, "multi");
    }

    function test_invalidPortfolio() {
        var parsed = Backup.parseBackup('{"data":{"portfolio":[{"ticker":"TLV.RO","shares":0,"averageCost":1}]}}');
        compare(parsed.code, "invalidLot");
    }

    function test_rejectsInvalidSymbols() {
        // A feed/backup value must not become markup or URL syntax in the widget.
        compare(Backup.parseBackup('{"data":{"ticker":"<img src=x>"}}').code, "invalidValue");
        compare(Backup.parseBackup('{"data":{"ticker":"AAPL;rm -rf /"}}').code, "invalidValue");
        compare(Backup.parseBackup('{"data":{"multiTickers":"AAPL, <img src=x>"}}').code, "invalidValue");
        compare(Backup.parseBackup('{"data":{"portfolio":[{"ticker":"AAPL;rm","shares":1,"averageCost":1}]}}').code,
                "invalidLot");

        // Empty tickers are allowed (the widget shows its placeholder).
        var empty = Backup.parseBackup('{"data":{"ticker":"   "}}');
        verify(empty.ok);
        compare(empty.data.ticker, "");

        // The separators real Yahoo symbols use survive validation.
        var valid = Backup.parseBackup('{"data":{"multiTickers":"^GSPC, EURUSD=X, M&M.NS, brk-b"}}');
        verify(valid.ok);
        compare(valid.data.multiTickers, "^GSPC, EURUSD=X, M&M.NS, BRK-B");
    }
}
