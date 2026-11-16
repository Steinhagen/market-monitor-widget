import QtQuick
import QtTest
import "Fixture.js" as Fixture
import "../../contents/ui/providers/yahoo/news.js" as News
import "../../contents/ui/domain/news.js" as NewsDomain

TestCase {
    name: "YahooNews"

    function test_languageModeValues() {
        // On an English system the local-only mode would duplicate English only.
        compare(NewsDomain.languageModeValues("en").join(","), "english,multi");
        compare(NewsDomain.languageModeValues("EN").join(","), "english,multi");
        // Other locales keep all four distinct choices.
        compare(NewsDomain.languageModeValues("ro").join(","),
                "system,systemFallback,english,multi");
        compare(NewsDomain.languageModeValues("").join(","),
                "system,systemFallback,english,multi");
    }

    function test_searchUrl() {
        var url = News.searchUrl("SAP SE", 24, "en");
        compare(url, "https://query2.finance.yahoo.com/v1/finance/search?q=SAP%20SE&quotesCount=0&newsCount=28&lang=en-US&region=US");
        compare(News.searchUrl("SAP", 6, "de"),
                "https://query2.finance.yahoo.com/v1/finance/search?q=SAP&quotesCount=0&newsCount=10&lang=de-DE&region=DE");
        compare(News.searchUrl("SAP", 6, "fr"),
                "https://query2.finance.yahoo.com/v1/finance/search?q=SAP&quotesCount=0&newsCount=10&lang=fr-FR&region=FR");
        // An edition Yahoo does not localise falls back to the English parameters.
        compare(News.searchUrl("SAP", 6, "ro"),
                "https://query2.finance.yahoo.com/v1/finance/search?q=SAP&quotesCount=0&newsCount=10&lang=en-US&region=US");
    }

    function test_safeLink() {
        compare(News.safeLink("https://example.com/a", "SAP.DE"), "https://example.com/a");
        compare(News.safeLink("javascript:alert(1)", "SAP.DE"),
                "https://finance.yahoo.com/quote/SAP.DE/news/");
        compare(News.safeLink("http://example.com/a", "SAP.DE"),
                "https://finance.yahoo.com/quote/SAP.DE/news/");
        compare(News.safeLink("file:///etc/passwd", "SAP.DE"),
                "https://finance.yahoo.com/quote/SAP.DE/news/");
        compare(News.safeLink("", "SAP.DE"), "https://finance.yahoo.com/quote/SAP.DE/news/");
        compare(News.safeLink("", "SAP.DE", "fr"),
                "https://fr.finance.yahoo.com/quote/SAP.DE/actualites/");
    }

    function test_newsPageUrlFollowsEdition() {
        compare(News.newsPageUrl("SAP.DE", "en"),
                "https://finance.yahoo.com/quote/SAP.DE/news/");
        compare(News.newsPageUrl("SAP.DE", "de"),
                "https://de.finance.yahoo.com/quote/SAP.DE/nachrichten/");
        compare(News.newsPageUrl("SAP.DE", "fr"),
                "https://fr.finance.yahoo.com/quote/SAP.DE/actualites/");
        compare(News.newsPageUrl("SAP.DE", "es"),
                "https://es.finance.yahoo.com/quote/SAP.DE/noticias/");
        compare(News.newsPageUrl("SAP.DE", "it"),
                "https://it.finance.yahoo.com/quote/SAP.DE/notizie/");
        // A language without an edition falls back to the global English page.
        compare(News.newsPageUrl("SAP.DE", "ro"),
                "https://finance.yahoo.com/quote/SAP.DE/news/");
        compare(News.newsPageUrl("SAP.DE"),
                "https://finance.yahoo.com/quote/SAP.DE/news/");
    }

    function test_decodeEntities() {
        compare(News.decodeEntities("A &amp; B &lt; C &#233; &#x27;"), "A & B < C é '");
        compare(News.decodeEntities("no entities"), "no entities");
        compare(News.decodeEntities("&#x110000;"), "&#x110000;");
    }

    function test_parseFixture() {
        var data = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-search-sap.json")));
        // The ticker query accepts only the exact tag, which Yahoo does not use for SAP.DE.
        compare(News.parse(data, "SAP.DE", false, 10, "en").length, 0);
        // The name query accepts the base symbol; every kept item is tagged SAP.
        var items = News.parse(data, "SAP.DE", true, 10, "en");
        verify(items.length > 0);
        for (var i = 0; i < items.length; i++) {
            compare(items[i].source, "Yahoo");
            compare(items[i].lang, "en");
            verify(items[i].title !== "");
            verify(items[i].link.indexOf("http") === 0);
        }
        // Newest first.
        for (var j = 1; j < items.length; j++)
            verify(items[j - 1].time >= items[j].time);
        // The limit is applied after filtering.
        compare(News.parse(data, "SAP.DE", true, 2, "en").length, 2);
    }

    function test_parseGermanFixture() {
        var data = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-search-sap-de.json")));
        var items = News.parse(data, "SAP.DE", true, 10, "de");
        verify(items.length > 0);
        compare(items[0].title, "ANALYSE-FLASH: JPMorgan hebt SAP auf 'Overweight' - Ziel auf 275 Euro");
        compare(items[0].publisher, "dpa-AFX");
        compare(items[0].lang, "de");
        for (var i = 0; i < items.length; i++) {
            compare(items[i].source, "Yahoo");
            compare(items[i].lang, "de");
        }
    }

    function test_parseFiltersAndDedupes() {
        var data = { news: [
            { uuid: "u1", title: "One", publisher: "P", link: "https://a", providerPublishTime: 3, relatedTickers: ["SAP"] },
            { uuid: "u1", title: "One again", publisher: "P", link: "https://b", providerPublishTime: 2, relatedTickers: ["SAP"] },
            { uuid: "u2", title: "Other", publisher: "P", link: "https://c", providerPublishTime: 1, relatedTickers: ["MSFT"] },
            { uuid: "u3", title: "", publisher: "P", link: "https://d", providerPublishTime: 0, relatedTickers: ["SAP"] }
        ] };
        var items = News.parse(data, "SAP.DE", true, 10, "en");
        compare(items.length, 1);
        compare(items[0].title, "One");
        compare(items[0].id, "u1");
    }

    function test_supportsLanguage() {
        verify(News.supportsLanguage("en"));
        verify(News.supportsLanguage("de"));
        verify(News.supportsLanguage("fr"));
        verify(News.supportsLanguage("es"));
        verify(News.supportsLanguage("it"));
        // Languages Yahoo does not localise must not be fetched from the US edition.
        verify(!News.supportsLanguage("ro"));
        verify(!News.supportsLanguage("pt"));
        verify(!News.supportsLanguage("pl"));
        verify(!News.supportsLanguage(""));
    }

    function test_rssUrlAndEligibility() {
        compare(News.rssUrl("WINE.RO"),
                "https://finance.yahoo.com/rss/headline?s=WINE.RO");
        // The RSS fallback is only for BVB symbols on the English leg: the feed
        // follows the listing's market language and is noisy for other markets.
        verify(News.canUseRss("WINE.RO", "en"));
        verify(News.canUseRss("TLV.RO", "EN"));
        verify(!News.canUseRss("WINE.RO", "de"));
        verify(!News.canUseRss("SAP.DE", "en"));
        verify(!News.canUseRss("WINE.RO", "ro"));
    }

    function test_parseRss() {
        var body = Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-rss-wine.xml"));
        var items = News.parseRss(body, "WINE.RO",
                                  "Purcari Wineries Public Company Limited", 10, "en");
        compare(items.length, 5);
        compare(items[0].source, "Yahoo");
        compare(items[0].lang, "en");
        verify(items[0].title.indexOf("Purcari") >= 0);
        verify(items[0].time > 0);
        verify(items[0].link.indexOf("https://") === 0);
        compare(items[0].publisher, "Yahoo Finance");
        // A just-drinks.com story is attributed to its publisher's domain.
        compare(items[3].publisher, "Just Drinks");

        // The feed occasionally mixes unrelated market articles; the relevance
        // filter must drop them.
        compare(News.parseRss(body, "TLV.RO", "Banca Transilvania", 10, "en").length, 0);
        // Without a company name only the base-symbol titles can be kept.
        compare(News.parseRss(body, "WINE.RO", "", 10, "en").length, 3);
    }

}
