import QtQuick
import QtTest
import "Fixture.js" as Fixture
import "../../contents/ui/providers/bvb/issuer.js" as BvbNews

TestCase {
    name: "BvbNews"

    function test_symbols() {
        compare(BvbNews.baseSymbol("TLV.RO"), "TLV");
        compare(BvbNews.baseSymbol("tlv.ro"), "TLV");
        compare(BvbNews.baseSymbol("SAP.DE"), "");
        compare(BvbNews.baseSymbol("TLV.RO "), "TLV");
        compare(BvbNews.detailUrl("TLV.RO"),
                "https://www.bvb.ro/FinancialInstruments/Details/FinancialInstrumentsDetails.aspx?s=TLV");
        compare(BvbNews.detailUrl("SAP.DE"), "");
    }

    function test_parseTop() {
        var html = Fixture.read(Qt.resolvedUrl("../fixtures/bvb-issuer-tlv.html"));
        var items = BvbNews.parseTop(html, "TLV.RO", 10);
        compare(items.length, 5);
        // A headline containing ">" inside the attribute must not be dropped.
        compare(items[0].title, "Notificare prag detineri > 5%");
        for (var i = 0; i < items.length; i++) {
            compare(items[i].source, "BVB");
            compare(items[i].lang, "ro");
            compare(items[i].publisher, "BVB");
            verify(items[i].link.indexOf("https://bvb.ro/") === 0);
            verify(items[i].time > 0);
        }
        for (var j = 1; j < items.length; j++)
            verify(items[j - 1].time >= items[j].time);
        compare(BvbNews.parseTop(html, "TLV.RO", 2).length, 2);
    }

    function test_languageOf() {
        compare(BvbNews.languageOf("https://bvb.ro/infocont/infocont26/WINE_20261111183255_Purcari-Wineries-Reprogramare-conferinta-telefonica-T3-2026.pdf"), "ro");
        compare(BvbNews.languageOf("https://bvb.ro/infocont/infocont26/WINE_20261111183255_Purcari-Wineries-Rescheduling-of-the-Q3-2026-Conference-Call.pdf"), "en");
        compare(BvbNews.languageOf("https://bvb.ro/infocont/infocont26/WINE_20260825062449_Purcari-Wineries-HALF-YEARLY-FINANCIAL-REPORT-2026-eng-FINAL.pdf"), "en");
        compare(BvbNews.languageOf("https://bvb.ro/infocont/infocont26/WINE_20260825062501_Purcari-Wineries-HALF-YEARLY-FINANCIAL-REPORT-2026-ro-FINAL.pdf"), "ro");
        compare(BvbNews.languageOf("https://bvb.ro/infocont/infocont26/WINE_20260825062436_Purcari-Wineries-PCL-Corporate-presentation-Q2-2026.pdf"), "en");
    }

    function test_parseTopEnglishMultiFile() {
        var html = '<table id="gv5News"><tr>'
            + '<td><input class="mLnkbttS" value="Raport semestrial S1 2026" /></td>'
            + '<td><p class="date">25.08.2026 09:24:26</p></td>'
            + "<td>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062417_Purcari-Wineries-PLC-Comunicat-presa-S1-2026-rezult.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062426_Purcari-Wineries-PLC-Press-Release-1H2026-results.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062436_Purcari-Wineries-PCL-Corporate-presentation-Q2-2026.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062449_Purcari-Wineries-HALF-YEARLY-FINANCIAL-REPORT-2026-eng-FINAL.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062501_Purcari-Wineries-HALF-YEARLY-FINANCIAL-REPORT-2026-ro-FINAL.pdf'></a>"
            + "</td></tr></table>";
        var items = BvbNews.parseTop(html, "WINE.RO", 10, "english");
        compare(items.length, 1);
        compare(items[0].title, "Purcari Wineries Half Yearly Financial Report 2026");
        compare(items[0].lang, "en");
        verify(items[0].link.indexOf("HALF-YEARLY-FINANCIAL-REPORT-2026-eng-FINAL.pdf") >= 0);
    }

    function test_parseTopEnglishRescheduling() {
        var html = '<table id="gv5News"><tr>'
            + '<td><input class="mLnkbttS" value="Reprogramarea Conferintei Telefonice T3 2026" /></td>'
            + '<td><p class="date">11.11.2026 18:35:39</p></td>'
            + "<td>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20261111183255_Purcari-Wineries-Reprogramare-conferinta-telefonica-T3-2026.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20261111183255_Purcari-Wineries-Rescheduling-of-the-Q3-2026-Conference-Call.pdf'></a>"
            + "</td></tr></table>";
        var items = BvbNews.parseTop(html, "WINE.RO", 10, "english");
        compare(items.length, 1);
        compare(items[0].title, "Purcari Wineries Rescheduling of the Q3 2026 Conference Call");
        verify(items[0].link.indexOf("Rescheduling-of-the-Q3-2026-Conference-Call.pdf") >= 0);
    }

    function test_parseTopLocalMultiFile() {
        var html = '<table id="gv5News"><tr>'
            + '<td><input class="mLnkbttS" value="Raport semestrial S1 2026" /></td>'
            + '<td><p class="date">25.08.2026 09:24:26</p></td>'
            + "<td>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062417_Purcari-Wineries-PLC-Comunicat-presa-S1-2026-rezult.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062426_Purcari-Wineries-PLC-Press-Release-1H2026-results.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062436_Purcari-Wineries-PCL-Corporate-presentation-Q2-2026.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062449_Purcari-Wineries-HALF-YEARLY-FINANCIAL-REPORT-2026-eng-FINAL.pdf'></a>"
            + "<a href='https://bvb.ro/infocont/infocont26/WINE_20260825062501_Purcari-Wineries-HALF-YEARLY-FINANCIAL-REPORT-2026-ro-FINAL.pdf'></a>"
            + "</td></tr></table>";
        var items = BvbNews.parseTop(html, "WINE.RO", 10);
        compare(items.length, 1);
        compare(items[0].title, "Raport semestrial S1 2026");
        verify(items[0].link.indexOf("HALF-YEARLY-FINANCIAL-REPORT-2026-ro-FINAL.pdf") >= 0);
    }

    function test_parseTimeEnglish() {
        verify(BvbNews.parseTime("11/11/2026 6:35:39 PM") > 0);
        verify(BvbNews.parseTime("25.08.2026 09:24:26") > 0);
    }

    function test_postBody() {
        var html = Fixture.read(Qt.resolvedUrl("../fixtures/bvb-issuer-tlv.html"));
        var body = BvbNews.postBody(html);
        verify(body.length > 0);
        verify(body.indexOf("__VIEWSTATE=") === 0);
        verify(body.indexOf("__EVENTVALIDATION=") > 0);
        verify(body.indexOf("IFTC") > 0);
        verify(body.indexOf("=Stiri") > 0);
        // Without the ASP.NET state the caller keeps the five embedded entries.
        compare(BvbNews.postBody("<html><body>no form</body></html>"), "");
    }

    function test_parseTopMissingTable() {
        compare(BvbNews.parseTop("<html></html>", "TLV.RO", 10).length, 0);
    }
}
