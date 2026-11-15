import QtQuick
import QtTest

TestCase {
    name: "NewsController"
    width: 400
    height: 300

    Component {
        id: fakeApplet
        QtObject {
            property string singleTicker: "SAP.DE"
            property string singleDataTicker: "SAP.DE"
            property bool isMultiMode: false
            property string singleCompanyName: "SAP SE"
            property string loadingText: "Loading…"
            property bool newsAvailable: true
            property bool newsSourceYahoo: true
            property bool newsSourceBvb: false
            property bool newsSourceGoogle: true
            property string newsLanguage: "systemFallback"
            property string newsLanguages: "ro,en,fr"
            property int newsCount: 5
            property int newsRefreshMinutes: 30
            property bool newsPaneShown: false
            property string singleViewPane: "chart"
        }
    }

    function makeController() {
        var applet = createTemporaryObject(fakeApplet, this);
        verify(applet !== null);
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/NewsController.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var controller = component.createObject(this, { "applet": applet });
        verify(controller !== null);
        return controller;
    }

    function test_mergeDedupesAndSorts() {
        var controller = makeController();
        var yahoo = [
            { title: "Same story", link: "https://a", source: "Yahoo", time: 10 },
            { title: "Older", link: "https://b", source: "Yahoo", time: 5 }
        ];
        var bvb = [
            { title: "Same story", link: "https://c", source: "BVB", time: 20 }
        ];
        var google = [
            { title: "Newest", link: "https://d", source: "Google", time: 30 },
            { title: "Older", link: "https://e", source: "Google", time: 1 }
        ];
        var merged = controller.mergeSourceItems({ yahoo: yahoo, bvb: bvb, google: google });
        compare(merged.length, 3);
        compare(merged[0].title, "Newest");
        compare(merged[0].source, "Google");
        compare(merged[1].title, "Same story");
        compare(merged[1].source, "Yahoo");
        compare(merged[2].title, "Older");
    }

    function test_newsKey() {
        var controller = makeController();
        compare(controller.newsKey(" tlv.ro "), "TLV.RO");
        compare(controller.newsKey(""), "");
        compare(controller.newsKey(undefined), "");
    }

    function test_newsDateIncludesYearForOlderArticles() {
        var controller = makeController();
        var now = new Date(2026, 10, 15).getTime();
        var lastYear = new Date(2025, 10, 4).getTime() / 1000;
        var thisYear = new Date(2026, 10, 4).getTime() / 1000;
        verify(controller.newsDate(lastYear, now).indexOf("2025") >= 0);
        compare(controller.newsDate(thisYear, now).indexOf("2026"), -1);
    }

    function test_visibleItemsRespectsLanguage() {
        var controller = makeController();
        controller.localeName = "ro_RO";
        var items = {
            yahoo: [{ id: "y", title: "Yahoo EN", source: "Yahoo", time: 30, lang: "en" }],
            bvb: [{ id: "b", title: "BVB RO", source: "BVB", time: 20, lang: "ro" }],
            google: [{ id: "g", title: "Google local", source: "Google", time: 10, lang: "ro" }]
        };

        controller.applet.newsLanguage = "system";
        var shown = controller.visibleItems(items, true);
        compare(shown.length, 2);
        compare(shown[0].title, "BVB RO");
        compare(shown[1].title, "Google local");

        controller.applet.newsLanguage = "systemFallback";
        shown = controller.visibleItems(items, true);
        compare(shown.length, 3);
        compare(shown[0].title, "BVB RO");
        compare(shown[1].title, "Google local");
        compare(shown[2].title, "Yahoo EN");

        controller.applet.newsLanguage = "english";
        shown = controller.visibleItems(items, true);
        compare(shown.length, 3);
        compare(shown[0].title, "Yahoo EN");
        compare(shown[1].title, "BVB RO");
        compare(shown[2].title, "Google local");

        controller.applet.newsLanguage = "multi";
        shown = controller.visibleItems(items, true);
        compare(shown.length, 3);
    }

    function test_activeLanguages() {
        var controller = makeController();
        controller.localeName = "ro_RO";
        var localCode = "ro";

        controller.applet.newsLanguage = "systemFallback";
        var languages = controller.activeLanguages();
        compare(languages.length, localCode === "en" ? 1 : 2);
        compare(languages[0].code, localCode);
        if (localCode !== "en") {
            compare(languages[1].code, "en");
            compare(languages[1].locale, "en_US");
        }

        controller.applet.newsLanguage = "english";
        languages = controller.activeLanguages();
        compare(languages.length, 1);
        compare(languages[0].code, "en");
        compare(languages[0].locale, "en_US");

        controller.applet.newsLanguage = "multi";
        controller.applet.newsLanguages = "ro,en,fr";
        languages = controller.activeLanguages();
        var codes = [];
        for (var i = 0; i < languages.length; i++) codes.push(languages[i].code);
        verify(codes.indexOf(localCode) >= 0);
        if (localCode !== "en") verify(codes.indexOf("en") >= 0);
        if (localCode !== "fr") verify(codes.indexOf("fr") >= 0);
    }

    function test_bvbLanguage() {
        var controller = makeController();
        controller.localeName = "ro_RO";

        controller.applet.newsLanguage = "system";
        compare(controller.bvbLanguage(), "ro");
        controller.applet.newsLanguage = "systemFallback";
        compare(controller.bvbLanguage(), "ro");
        controller.applet.newsLanguage = "english";
        compare(controller.bvbLanguage(), "en");

        controller.applet.newsLanguage = "multi";
        controller.applet.newsLanguages = "ro,en";
        compare(controller.bvbLanguage(), "ro");
        controller.applet.newsLanguages = "en";
        compare(controller.bvbLanguage(), "en");
        controller.applet.newsLanguages = "fr";
        compare(controller.bvbLanguage(), "");
        controller.applet.newsLanguages = "fr,en";
        compare(controller.bvbLanguage(), "en");

        controller.localeName = "en_US";
        controller.applet.newsLanguage = "system";
        compare(controller.bvbLanguage(), "en");
        controller.applet.newsLanguage = "systemFallback";
        compare(controller.bvbLanguage(), "en");
        controller.applet.newsLanguage = "multi";
        controller.applet.newsLanguages = "ro";
        compare(controller.bvbLanguage(), "ro");
    }

    function test_bvbLanguages() {
        var controller = makeController();
        controller.localeName = "ro_RO";

        controller.applet.newsLanguage = "multi";
        controller.applet.newsLanguages = "ro,en";
        compare(controller.bvbLanguages().join(","), "ro,en");
        controller.applet.newsLanguages = "ro";
        compare(controller.bvbLanguages().join(","), "ro");
        controller.applet.newsLanguages = "en";
        compare(controller.bvbLanguages().join(","), "en");
        controller.applet.newsLanguages = "fr";
        compare(controller.bvbLanguages().length, 0);
        controller.applet.newsLanguages = "fr,en";
        compare(controller.bvbLanguages().join(","), "en");

        controller.applet.newsLanguage = "systemFallback";
        compare(controller.bvbLanguages().join(","), "ro");
        controller.applet.newsLanguage = "english";
        compare(controller.bvbLanguages().join(","), "en");

        controller.localeName = "en_US";
        controller.applet.newsLanguage = "system";
        compare(controller.bvbLanguages().join(","), "en");
        controller.applet.newsLanguage = "systemFallback";
        compare(controller.bvbLanguages().join(","), "en");
        controller.applet.newsLanguage = "multi";
        controller.applet.newsLanguages = "ro,en";
        compare(controller.bvbLanguages().join(","), "ro,en");
    }

    function test_englishFallbackAppendsGoogleAndYahoo() {
        var controller = makeController();
        controller.localeName = "ro_RO";
        var sourceItems = {
            yahoo: [{ id: "y", title: "Yahoo EN", source: "Yahoo", time: 30, lang: "en" }],
            bvb: [{ id: "b", title: "BVB RO", source: "BVB", time: 20, lang: "ro" }],
            google: [
                { id: "g", title: "Google local", source: "Google", time: 10, lang: "ro" },
                { id: "g2", title: "Google EN", source: "Google", time: 40, lang: "en" }
            ]
        };

        controller.applet.newsLanguage = "systemFallback";
        var shown = controller.visibleItems(sourceItems, true);
        compare(shown.length, 4);
        compare(shown[0].title, "BVB RO");
        compare(shown[1].title, "Google local");
        compare(shown[2].title, "Google EN");
        compare(shown[3].title, "Yahoo EN");

        controller.applet.newsLanguage = "system";
        shown = controller.visibleItems(sourceItems, true);
        compare(shown.length, 2);
        compare(shown[0].title, "BVB RO");
        compare(shown[1].title, "Google local");

        controller.applet.newsLanguage = "systemFallback";
        shown = controller.visibleItems({ yahoo: sourceItems.yahoo, bvb: [], google: [] }, true);
        compare(shown.length, 1);
        compare(shown[0].title, "Yahoo EN");
    }

    function test_availableRespectsLanguage() {
        var controller = makeController();
        controller.localeName = "ro_RO";
        controller.applet.newsSourceYahoo = true;
        controller.applet.newsSourceGoogle = false;
        controller.applet.newsSourceBvb = false;
        controller.applet.singleTicker = "SAP.DE";

        controller.applet.newsLanguage = "system";
        compare(controller.available, false);
        controller.applet.newsLanguage = "systemFallback";
        compare(controller.available, true);
        controller.applet.newsLanguage = "english";
        compare(controller.available, true);
    }

    function test_yahooLanguages() {
        var controller = makeController();
        controller.localeName = "de_DE";

        controller.applet.newsLanguage = "system";
        compare(controller.yahooLanguages().join(","), "de");
        controller.applet.newsLanguage = "systemFallback";
        compare(controller.yahooLanguages().join(","), "de,en");
        controller.applet.newsLanguage = "english";
        compare(controller.yahooLanguages().join(","), "en");

        controller.applet.newsLanguage = "multi";
        controller.applet.newsLanguages = "fr,it,ro";
        compare(controller.yahooLanguages().join(","), "fr,it");
        controller.applet.newsLanguages = "ro,pl";
        compare(controller.yahooLanguages().length, 0);

        controller.localeName = "ro_RO";
        controller.applet.newsLanguage = "system";
        compare(controller.yahooLanguages().length, 0);
    }

    function test_yahooPageLanguage() {
        var controller = makeController();
        controller.localeName = "ro_RO";

        controller.applet.newsLanguage = "multi";
        controller.applet.newsLanguages = "fr";
        compare(controller.yahooPageLanguage(), "fr");
        // With two editions, the non-English one wins over the default English entry.
        controller.applet.newsLanguages = "en,fr";
        compare(controller.yahooPageLanguage(), "fr");
        controller.applet.newsLanguages = "en,de";
        compare(controller.yahooPageLanguage(), "de");
        controller.applet.newsLanguages = "fr,de";
        compare(controller.yahooPageLanguage(), "fr");
        controller.applet.newsLanguages = "ro,en";
        compare(controller.yahooPageLanguage(), "en");

        controller.localeName = "de_DE";
        controller.applet.newsLanguage = "systemFallback";
        compare(controller.yahooPageLanguage(), "de");
        controller.applet.newsLanguage = "system";
        compare(controller.yahooPageLanguage(), "de");

        controller.localeName = "en_US";
        controller.applet.newsLanguage = "system";
        compare(controller.yahooPageLanguage(), "en");
    }

    function test_yahooItemLanguages() {
        var controller = makeController();
        var items = [
            { source: "Yahoo", lang: "en" },
            { source: "Yahoo", lang: "fr" },
            { source: "Yahoo", lang: "en" },
            { source: "Google", lang: "fr" },
            { source: "Yahoo", lang: "ro" }
        ];

        controller.localeName = "ro_RO";
        compare(controller.yahooItemLanguages(items).join(","), "fr,en");
        controller.localeName = "fr_FR";
        compare(controller.yahooItemLanguages(items).join(","), "fr,en");
        controller.localeName = "en_US";
        compare(controller.yahooItemLanguages(items).join(","), "en,fr");

        compare(controller.yahooItemLanguages([{ source: "Google", lang: "fr" }]).length, 0);
        compare(controller.yahooItemLanguages([]).length, 0);
        compare(controller.yahooItemLanguages(undefined).length, 0);
    }

    function test_newsMoreTargets() {
        var controller = makeController();
        controller.localeName = "ro_RO";
        var items = [
            { source: "Google", lang: "en" },
            { source: "Yahoo", lang: "fr" },
            { source: "Yahoo", lang: "en" },
            { source: "BVB", lang: "ro" },
            { source: "Yahoo", lang: "ro" }
        ];
        var targets = controller.newsMoreTargets(items);
        var labels = [];
        for (var i = 0; i < targets.length; i++)
            labels.push(targets[i].source + ":" + targets[i].lang);
        // The All tab lists every source present, Yahoo once per language.
        compare(labels.join(","), "Yahoo:fr,Yahoo:en,BVB:,Google:");
        // A source filter shows only that source.
        compare(controller.newsMoreTargets([{ source: "Google", lang: "en" }]).length, 1);
        compare(controller.newsMoreTargets([]).length, 0);
        compare(controller.newsMoreTargets(undefined).length, 0);
    }

    function test_availableUsesRegionalYahoo() {
        var controller = makeController();
        controller.applet.newsSourceYahoo = true;
        controller.applet.newsSourceGoogle = false;
        controller.applet.newsSourceBvb = false;
        controller.applet.singleTicker = "SAP.DE";

        // A German Reader gets German Yahoo headlines for SAP.DE.
        controller.localeName = "de_DE";
        controller.applet.newsLanguage = "system";
        compare(controller.available, true);
        // Romanian has no Yahoo edition, so local-only mode has no source left.
        controller.localeName = "ro_RO";
        compare(controller.available, false);
        // In multilingual mode Yahoo only counts for a language it can serve.
        controller.applet.newsLanguage = "multi";
        controller.applet.newsLanguages = "fr";
        compare(controller.available, true);
        controller.applet.newsLanguages = "ro";
        compare(controller.available, false);
    }

    function test_visibleItemsShowsRegionalYahoo() {
        var controller = makeController();
        controller.localeName = "de_DE";
        var sourceItems = {
            yahoo: [
                { id: "y1", title: "SAP steigt", source: "Yahoo", time: 20, lang: "de" },
                { id: "y2", title: "SAP rises", source: "Yahoo", time: 10, lang: "en" }
            ],
            bvb: [],
            google: []
        };

        controller.applet.newsLanguage = "system";
        var shown = controller.visibleItems(sourceItems, true);
        compare(shown.length, 1);
        compare(shown[0].title, "SAP steigt");

        controller.applet.newsLanguage = "systemFallback";
        shown = controller.visibleItems(sourceItems, true);
        compare(shown.length, 2);
        compare(shown[0].title, "SAP steigt");
        compare(shown[1].title, "SAP rises");
    }
}
