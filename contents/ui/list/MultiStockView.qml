import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"
import "../domain/format.js" as Format

Rectangle {
    id: multiStockRoot

    property var applet
    property var listModel

    // A single pending "open" action for the whole list. Delaying it briefly lets a double
    // click cancel the single-click action, and clicking another row cancels the old one.
    property string pendingRowOpen: ""
    Timer {
        id: pendingRowOpenTimer
        interval: 350
        onTriggered: {
            var ticker = multiStockRoot.pendingRowOpen;
            multiStockRoot.pendingRowOpen = "";
            if (ticker !== "") applet.openYahooQuote(ticker);
        }
    }

    // Smallest list column that keeps the price, the change badge and a few characters of the
    // name on each row; the name, the second line and the position line elide or shorten by design.
    readonly property real minimumContentWidth: 250
    readonly property real minimumContentHeight: 200

    // The Application preset paints its own rounded card; with Plasma the system
    // background shows through and this view stays transparent.
    color: applet.bgColor
    radius: applet.appDrawnSurface ? 22 : 0
    clip: true

    // --- Portfolio total ---
    // The value, total gain and period gain of all the positions together, shown as the last
    // line of the list. Positions can be held in different currencies: each one is converted
    // to the portfolio currency (daily exchange rates) before they are added up. null when
    // the feature is off or fewer than two tickers have lots.
    property var totals: null
    property string totalsSym: ""
    property string totalsLabel: ""
    // The timestamp line sits in the list's bottom margin; when it is hidden, do not
    // leave that empty strip below the portfolio total. Cached values always show it,
    // even when the normal timestamps are hidden, so stale prices are never unmarked.
    readonly property bool showUpdateTimestamps: applet !== null && applet !== undefined
                                                 && (applet.showingCachedData
                                                     || (applet.lastUpdated !== ""
                                                         && applet.isMultiMode
                                                         && !applet.hideTimestamps))

    function recomputeTotals() {
        multiStockRoot.totals = null;
        if (!applet || !listModel || !applet.showPortfolioMode) return;
        var held = applet.getPortfolioTickers(applet.portfolioData);
        if (held.length < 2) return;
        var base = applet.portfolioCurrency || "USD";
        var value = 0, cost = 0, day = 0, dayKnown = true, priced = 0, noRate = 0;
        for (var i = 0; i < listModel.count; i++) {
            var row = listModel.get(i);
            if (!(row.currentRaw > 0)) continue;
            var s = applet.getPortfolioSummary(row.ticker, applet.portfolioData, row.currentRaw, row.prevClose, row.currency);
            if (!s) continue;
            var positionValue = applet.convertMoney(s.value, s.currency, base);
            var positionCost = applet.convertMoney(s.cost, s.currency, base);
            if (positionValue === null || positionCost === null) {
                noRate++;
                continue;
            }
            priced++;
            value += positionValue;
            cost += positionCost;
            if (s.dayValue === null) {
                dayKnown = false;
            } else {
                var positionDay = applet.convertMoney(s.dayValue, s.currency, base);
                if (positionDay === null) dayKnown = false;
                else day += positionDay;
            }
        }
        if (priced === 0) return;
        var pl = value - cost;
        multiStockRoot.totalsSym = applet.getCurrencySymbol(base);
        // Say so when some positions have no price yet (still loading, or not in the list)
        // or no exchange rate for their currency.
        var positions = priced === held.length
                        ? i18np("%1 position", "%1 positions", held.length)
                        : i18nc("@info:portfolio", "%1 of %2 positions", priced, held.length);
        multiStockRoot.totalsLabel = noRate > 0
                                     ? i18nc("@info:portfolio", "%1 · no rate for %2", positions, noRate)
                                     : positions;
        multiStockRoot.totals = {
            value: value, cost: cost, plValue: pl, plPercent: cost > 0 ? (pl / cost) * 100 : 0, plIsPos: pl >= 0,
            plIsNeutral: Format.isFlatChange(pl),
            dayValue: dayKnown ? day : null, dayIsPos: !dayKnown || day >= 0,
            dayIsNeutral: dayKnown && Format.isFlatChange(day), currency: base
        };
    }

    // Prices arrive one ticker at a time, so recompute once they settle. The total also
    // changes when a fresh daily exchange-rate table arrives or the portfolio currency is
    // changed in the settings.
    Timer { id: totalsTimer; interval: 100; onTriggered: multiStockRoot.recomputeTotals() }
    Component.onCompleted: multiStockRoot.recomputeTotals()
    Connections {
        target: multiStockRoot.listModel
        function onDataChanged() { totalsTimer.restart(); }
        function onRowsInserted() { totalsTimer.restart(); }
        function onRowsRemoved() { totalsTimer.restart(); }
        function onModelReset() { totalsTimer.restart(); }
    }
    Connections {
        target: multiStockRoot.applet
        function onPortfolioDataChanged() { totalsTimer.restart(); }
        function onShowPortfolioModeChanged() { totalsTimer.restart(); }
        function onExchangeRatesChanged() { totalsTimer.restart(); }
        function onPortfolioCurrencyChanged() { totalsTimer.restart(); }
    }

    Text {
        anchors.centerIn: parent
        text: i18n("Loading...")
        color: applet.secondaryTextColor
        font.pixelSize: 14
        visible: applet.isMultiMode && listModel.count === 0
    }
    ListView {
        id: multiView
        anchors.fill: parent
        anchors.leftMargin: 16
        // Room for the optional scrollbar: without it the rows keep their old width,
        // with it the price column moves left instead of sitting under the thumb.
        anchors.rightMargin: 16 + (listScrollBar.visible ? 12 : 0)
        anchors.bottomMargin: multiStockRoot.showUpdateTimestamps ? 16 : 4
        anchors.topMargin: 0

        clip: true
        model: listModel
        spacing: 0

        // The portfolio total, after the last row.
        footer: Component {
            Item {
                width: multiView.width
                height: multiStockRoot.totals !== null ? 40 : 0
                visible: multiStockRoot.totals !== null

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: multiStockRoot.applet.chartBaseColor
                }
                PositionLine {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    applet: multiStockRoot.applet
                    summary: multiStockRoot.totals
                    sym: multiStockRoot.totalsSym
                    heldOverride: multiStockRoot.totalsLabel
                }
            }
        }

        delegate: WatchRow {
            applet: multiStockRoot.applet
            row: model
            rowIndex: index
            rowCount: multiView.count
            rowWidth: multiView.width
            // The delayed "open" action is list-wide: a second click on another row
            // replaces the pending one.
            requestPendingOpen: function(ticker) {
                multiStockRoot.pendingRowOpen = ticker;
                pendingRowOpenTimer.restart();
            }
            cancelPendingOpen: function() {
                multiStockRoot.pendingRowOpen = "";
                pendingRowOpenTimer.stop();
            }
        }
    }

    // Optional scrollbar, drawn like the one in the analyst details popup: a slim handle
    // on an invisible track, only while the rows do not fit the visible height. It sits
    // in the card margin, clear of the row content.
    Item {
        id: listScrollBar
        visible: applet.showListScrollBar && multiView.contentHeight > multiView.height + 1
        anchors.top: multiView.top
        anchors.bottom: multiView.bottom
        // Inset from the list edges so the thumb does not touch the first row or the
        // status line; the mapping below uses the resulting height, so travel adapts.
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.right: parent.right
        // In the gutter the list reserves when the bar is visible: 12 px to the prices on
        // the left and 8 px to the card edge on the right.
        anchors.rightMargin: 8
        width: 8

        Rectangle {
            id: listScrollHandle
            // The thumb spans the full visible range: at the end of the list it must
            // reach the bottom of the track.
            readonly property real maxScroll: Math.max(0, multiView.contentHeight - multiView.height)
            readonly property real travel: Math.max(0, listScrollBar.height - height)
            readonly property real progress: maxScroll > 0
                                             ? Math.max(0, Math.min(1, multiView.contentY / maxScroll))
                                             : 0
            x: 1
            width: 6
            radius: 3
            color: applet.secondaryTextColor
            opacity: 0.35
            height: Math.max(20, Math.min(listScrollBar.height,
                                          multiView.visibleArea.heightRatio * listScrollBar.height))
            y: progress * travel
        }

        // The drawn thumb is 6 px wide, which is hard to grab. This invisible strip is
        // twice as wide and covers the whole track: pressing it drags the thumb, pressing
        // beside the thumb jumps there first. Nothing about the drawing changes.
        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: -8
            cursorShape: Qt.PointingHandCursor
            property real grabY: 0
            property bool onThumb: false

            function scrollTo(pointerY) {
                if (listScrollHandle.travel <= 0 || listScrollHandle.maxScroll <= 0) return;
                var top = Math.max(0, Math.min(listScrollHandle.travel, pointerY - grabY));
                multiView.contentY = top / listScrollHandle.travel * listScrollHandle.maxScroll;
            }

            onPressed: (mouse) => {
                var localY = mapToItem(listScrollHandle, mouse.x, mouse.y).y;
                onThumb = localY >= 0 && localY <= listScrollHandle.height;
                grabY = onThumb ? localY : listScrollHandle.height / 2;
                if (!onThumb) scrollTo(mouse.y);
            }
            onPositionChanged: (mouse) => {
                if (pressed) scrollTo(mouse.y);
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        // The cached line carries a date and can be longer than the usual time.
        width: Math.max(0, parent.width - 16)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: applet.updateStatusText
        color: applet.showingCachedData ? applet.warningTextColor : applet.secondaryTextColor
        font.pixelSize: 10
        textFormat: Text.PlainText
        visible: multiStockRoot.showUpdateTimestamps
    }
}
