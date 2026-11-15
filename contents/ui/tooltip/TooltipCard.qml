import QtQuick
import org.kde.kirigami as Kirigami

// Custom tooltip for the multi-stock list. Plasma's default tooltip body is limited to
// eight lines, which cannot hold column headers, seven stocks and the update line; this
// card draws the same table in a fixed layout instead. It is only used in multi mode,
// where the list has columns; single mode keeps the default tooltip text.
Item {
    id: card
    property var applet: null
    property var stockList: null

    readonly property int revision: applet && applet.tooltipRevision !== undefined
                                    ? applet.tooltipRevision : 0
    readonly property bool cached: applet ? applet.showingCachedData : false
    readonly property int stockCount: stockList ? stockList.count : 0
    readonly property string rangeText: applet ? applet.rangeLabel(applet.chartRange) : ""
    readonly property string baseTitle: i18np("%1 stock", "%1 stocks", stockCount)
                                        + (rangeText !== "" ? " · " + rangeText : "")

    // Column widths; their sum is the fixed content width.
    readonly property int contentWidth: 344
    readonly property int markerWidth: 12
    readonly property int symbolWidth: 90
    readonly property int marketWidth: 56
    readonly property int priceWidth: 84
    readonly property int changeWidth: 102
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor

    implicitWidth: 368
    width: implicitWidth
    height: implicitHeight
    implicitHeight: 44 + body.implicitHeight + 12

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    // Measured with the same font as the exchange badge, so the ticker column can
    // reserve exactly its width plus the spacing before the market column.
    FontMetrics {
        id: badgeMetrics
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: Math.max(9, Kirigami.Theme.defaultFont.pixelSize - 2)
    }

    function statusText(ticker) {
        if (applet.isMarketClosedFor(ticker))
            return i18nc("@item:market status", "Closed");
        var status = applet.marketStatusFor(ticker);
        if (status === "open") return i18nc("@item:market status", "Open");
        if (status === "pre") return i18nc("@item:market status", "Pre");
        if (status === "post") return i18nc("@item:market status", "After");
        return "";
    }

    function tooltipWindow(count, active, maxRows) {
        var start = 0;
        if (count > maxRows) {
            var focus = active >= 0 ? active : 0;
            start = Math.max(0, Math.min(focus - Math.floor(maxRows / 2), count - maxRows));
        }
        return { start: start, end: Math.min(count, start + maxRows) };
    }

    // At most seven rows follow the selection; the hidden rows are counted in one footer
    // so the card keeps the same height while the wheel moves through the list.
    readonly property var rows: {
        var rev = revision;
        if (!applet || !stockList || stockList.count === 0) return [];
        var active = -1;
        for (var i = 0; i < stockList.count; i++) {
            if (stockList.get(i).ticker === applet.panelTicker) { active = i; break; }
        }
        var visible = tooltipWindow(stockList.count, active, 7);
        var out = [];
        for (var j = visible.start; j < visible.end; j++) {
            var row = stockList.get(j);
            var ext = applet.extendedQuote(row.ticker);
            var loading = row.price === "---" && !ext;
            out.push({
                ticker: applet.displayTicker(row.ticker),
                badge: applet.exchangeBadge(row.ticker, row.exchange),
                status: statusText(row.ticker),
                price: loading ? "…" : (ext ? ext.price : row.price),
                change: loading || !(ext ? ext.change : row.change)
                        ? "" : (ext ? ext.change : row.change)
                                + " (" + (ext ? ext.pct : row.pct) + ")",
                isPos: ext ? ext.isPos : row.isPos,
                isNeutral: ext ? ext.isNeutral === true : row.isNeutral === true,
                active: row.ticker === applet.panelTicker
            });
        }
        return out;
    }

    readonly property int hiddenCount: Math.max(0, stockCount - rows.length)

    // The quote time of the selected row, or the first loaded row as a fallback. Used to
    // tell whether the list is showing today's session or an older one.
    readonly property real activeQuoteTime: {
        var rev = revision;
        if (!applet || !stockList || stockList.count === 0) return 0;
        for (var i = 0; i < stockList.count; i++) {
            var row = stockList.get(i);
            if (row.ticker === applet.panelTicker)
                return Number(row.quoteTime) || 0;
        }
        for (var j = 0; j < stockList.count; j++) {
            var time = Number(stockList.get(j).quoteTime) || 0;
            if (time > 0) return time;
        }
        return 0;
    }

    readonly property string sessionText: {
        if (!applet || cached || !(activeQuoteTime > 0)) return "";
        var quote = new Date(activeQuoteTime * 1000);
        var now = new Date();
        if (quote.getFullYear() === now.getFullYear()
                && quote.getMonth() === now.getMonth()
                && quote.getDate() === now.getDate()) return "";
        return i18n("session of %1", quote.toLocaleDateString(Qt.locale(), "d MMM"));
    }

    readonly property string cacheText: applet && applet.showingCachedData
                                        ? i18n("cache from %1", applet.cachedQuotesLabel) : ""
    readonly property string updateText: applet && applet.lastUpdated !== ""
                                         ? i18n("Updated %1", applet.lastUpdated) : ""
    readonly property string rightText: cached ? cacheText : updateText
    readonly property int rightWidth: cached ? 170 : 120

    Item {
        width: card.width
        height: 36

        Row {
            x: 12; y: 0
            width: card.width - 24 - card.rightWidth
            height: 36
            spacing: 4

            Text {
                id: mainTitle
                width: 110
                height: parent.height
                text: card.baseTitle
                color: card.textColor
                font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.1)
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                height: parent.height
                width: Math.max(0, parent.width - mainTitle.width - parent.spacing)
                visible: text !== ""
                text: card.sessionText
                color: card.mutedColor
                font.pixelSize: Math.max(9, Kirigami.Theme.defaultFont.pixelSize - 1)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 0; height: 36
            width: card.rightWidth
            text: card.rightText
            color: card.cached ? (card.applet ? card.applet.warningTextColor : card.mutedColor)
                               : card.mutedColor
            font.pixelSize: Math.max(9, Kirigami.Theme.defaultFont.pixelSize - 1)
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    Column {
        id: body
        x: 12
        y: 44
        width: card.contentWidth
        spacing: 0

        Row {
            width: parent.width
            height: 17

            Item { width: card.markerWidth; height: parent.height }
            Text {
                width: card.symbolWidth; height: parent.height
                text: i18nc("@title:column", "Symbol")
                color: card.mutedColor
                font.pixelSize: Math.max(10, Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.9))
                font.letterSpacing: 0.5
                font.capitalization: Font.AllUppercase
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: card.marketWidth; height: parent.height
                text: i18nc("@title:column", "Market")
                color: card.mutedColor
                font.pixelSize: Math.max(10, Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.9))
                font.letterSpacing: 0.5
                font.capitalization: Font.AllUppercase
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: card.priceWidth; height: parent.height
                text: i18nc("@title:column", "Price")
                color: card.mutedColor
                font.pixelSize: Math.max(10, Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.9))
                font.letterSpacing: 0.5
                font.capitalization: Font.AllUppercase
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: card.changeWidth; height: parent.height
                text: i18nc("@title:column", "Change")
                color: card.mutedColor
                font.pixelSize: Math.max(10, Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.9))
                font.letterSpacing: 0.5
                font.capitalization: Font.AllUppercase
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            width: parent.width
            visible: card.rows.length === 0
            text: i18n("Loading…")
            color: card.mutedColor
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
        }

        Item {
            width: parent.width
            height: 5
        }

        Repeater {
            model: card.rows
            delegate: Item {
                id: rowItem
                required property var modelData
                width: card.contentWidth
                height: Math.max(20, Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.65))

                Row {
                    anchors.fill: parent

                    Text {
                        width: card.markerWidth; height: parent.height
                        text: modelData.active ? "•" : ""
                        color: card.textColor
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        verticalAlignment: Text.AlignVCenter
                    }
                    Row {
                        width: card.symbolWidth; height: parent.height
                        spacing: 3
                        Text {
                            width: Math.min(implicitWidth, Math.max(0, parent.width - (modelData.badge !== ""
                                ? Math.ceil(badgeMetrics.advanceWidth(modelData.badge)) + 5 : 0)))
                            height: parent.height
                            text: modelData.ticker
                            color: card.textColor
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                            font.bold: true
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            id: tickerBadge
                            text: modelData.badge
                            visible: text !== ""
                            height: parent.height
                            color: card.mutedColor
                            font.family: Kirigami.Theme.defaultFont.family
                            font.pixelSize: Math.max(9, Kirigami.Theme.defaultFont.pixelSize - 2)
                            textFormat: Text.PlainText
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    Text {
                        width: card.marketWidth; height: parent.height
                        text: modelData.status
                        color: card.mutedColor
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        width: card.priceWidth; height: parent.height
                        text: modelData.price
                        color: card.textColor
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        width: card.changeWidth; height: parent.height
                        text: modelData.change
                        color: modelData.isNeutral ? card.applet.neutralColor
                                                   : (modelData.isPos ? card.applet.positiveColor
                                                                      : card.applet.negativeColor)
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: card.hiddenCount > 0 ? 5 : 0
        }

        Text {
            width: parent.width
            visible: card.hiddenCount > 0
            text: i18n("… and %1 more", card.hiddenCount)
            color: card.mutedColor
            font.pixelSize: Math.max(9, Kirigami.Theme.defaultFont.pixelSize - 1)
        }
    }
}
