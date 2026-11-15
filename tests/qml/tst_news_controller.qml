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
        var items = {
            yahoo: [{ id: "y", title: "Yahoo EN", source: "Yahoo", time: 30 }],
            bvb: [{ id: "b", title: "BVB RO", source: "BVB", time: 20 }],
            google: [{ id: "g", title: "Google local", source: "Google", time: 10 }]
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
        var localCode = Qt.locale().name.substring(0, 2).toLowerCase();

        controller.applet.newsLanguage = "systemFallback";
        var languages = controller.activeLanguages();
        compare(languages.length, 1);
        compare(languages[0].code, localCode);

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

    function test_englishFallbackAppendsYahoo() {
        var controller = makeController();
        var sourceItems = {
            yahoo: [{ id: "y", title: "Yahoo EN", source: "Yahoo", time: 30, lang: "en" }],
            bvb: [{ id: "b", title: "BVB RO", source: "BVB", time: 20, lang: "ro" }],
            google: [{ id: "g", title: "Google local", source: "Google", time: 10, lang: "ro" }]
        };

        controller.applet.newsLanguage = "systemFallback";
        var shown = controller.visibleItems(sourceItems, true);
        compare(shown.length, 3);
        compare(shown[0].title, "BVB RO");
        compare(shown[1].title, "Google local");
        compare(shown[2].title, "Yahoo EN");

        controller.applet.newsLanguage = "system";
        shown = controller.visibleItems(sourceItems, true);
        compare(shown.length, 2);

        controller.applet.newsLanguage = "systemFallback";
        shown = controller.visibleItems({ yahoo: sourceItems.yahoo, bvb: [], google: [] }, true);
        compare(shown.length, 1);
        compare(shown[0].title, "Yahoo EN");
    }

    function test_availableRespectsLanguage() {
        var controller = makeController();
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
}
