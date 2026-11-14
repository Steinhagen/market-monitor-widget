import QtQuick
import org.kde.kirigami as Kirigami

// Tooltip card for the single-stock view. It uses the same title bar, column header,
// row height, fonts and colours as the multi-stock card, so both tooltips read as the
// same kind of card instead of a custom table next to Plasma's default tooltip.
Item {
    id: card
    property var applet: null

    readonly property int revision: applet && applet.tooltipRevision !== undefined
                                    ? applet.tooltipRevision : 0
    readonly property bool cached: applet ? applet.showingCachedData : false
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor

    readonly property int contentWidth: 344
    readonly property int labelWidth: 150
    readonly property int priceWidth: 90
    readonly property int changeWidth: 104
    readonly property int rightWidth: cached ? 170 : 100

    implicitWidth: 368
    width: implicitWidth
    height: implicitHeight
    implicitHeight: 44 + body.implicitHeight + 12

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    readonly property string titleText: {
        if (!applet) return "";
        var title = applet.nameAndTicker(applet.singleCompanyName,
                                         applet.displayTicker(applet.singleTicker));
        var badge = applet.exchangeBadge(applet.singleTicker, applet.singleExchange);
        return badge !== "" ? title + " · " + badge : title;
    }

    // The single quote time. The chart session start is the fallback for a range that
    // has not produced a quote yet.
    readonly property real quoteTime: {
        var rev = revision;
        if (!applet) return 0;
        if (applet.quoteTimestamp > 0) return applet.quoteTimestamp;
        return applet.chartSessionStart > 0 ? applet.chartSessionStart : 0;
    }

    readonly property string sessionText: {
        if (!applet || cached || !(quoteTime > 0)) return "";
        var quote = new Date(quoteTime * 1000);
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

    readonly property var rows: {
        var rev = revision;
        if (!applet) return [];
        var out = [];
        var price = applet.currentPrice;
        if (price === "" || price === "---") {
            out.push({ kind: "note", text: i18n("Loading…") });
            return out;
        }
        out.push({
            kind: "data",
            label: applet.chartPeriodLabel,
            price: price,
            change: applet.priceChange !== ""
                    ? applet.priceChange + " (" + applet.percentChange + ")" : "",
            isPos: applet.isPositive
        });

        var ext = applet.extendedQuote(applet.singleTicker);
        if (ext) {
            out.push({
                kind: "data",
                label: ext.label,
                price: ext.price,
                change: ext.change !== "" ? ext.change + " (" + ext.pct + ")" : "",
                isPos: ext.isPos
            });
        }

        if (applet.showExtendedHours && applet.isMarketClosedFor(applet.singleTicker)) {
            out.push({ kind: "note", label: i18n("Session"), text: i18n("Market closed") });
        }

        if (applet.showPortfolioMode && applet.hasPortfolioEntry) {
            var p = applet.portfolioSummary;
            var sym = applet.getCurrencySymbol(p.currency);
            out.push({
                kind: "note",
                label: i18n("Position"),
                text: i18np("%1 share · avg %2", "%1 shares · avg %2",
                            p.shares, applet.formatMoney(sym, p.avgCost, false))
            });
            out.push({
                kind: "data",
                label: i18n("P/L"),
                price: applet.formatMoney(sym, p.plValue, true),
                change: applet.formatNumber(p.plPercent, true) + "%",
                isPos: p.plIsPos
            });
        }
        return out;
    }

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
                width: 124
                height: parent.height
                text: card.titleText
                color: card.textColor
                font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.1)
                font.weight: Font.DemiBold
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

            Text {
                width: card.labelWidth; height: parent.height
                text: i18nc("@title:column", "Details")
                color: card.mutedColor
                font.pixelSize: Math.max(9, Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.8))
                font.letterSpacing: 0.5
                font.capitalization: Font.AllUppercase
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: card.priceWidth; height: parent.height
                text: i18nc("@title:column", "Price")
                color: card.mutedColor
                font.pixelSize: Math.max(9, Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.8))
                font.letterSpacing: 0.5
                font.capitalization: Font.AllUppercase
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: card.changeWidth; height: parent.height
                text: i18nc("@title:column", "Change")
                color: card.mutedColor
                font.pixelSize: Math.max(9, Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.8))
                font.letterSpacing: 0.5
                font.capitalization: Font.AllUppercase
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
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
                height: 20

                Row {
                    anchors.fill: parent

                    Text {
                        width: card.labelWidth; height: parent.height
                        text: modelData.label !== undefined ? modelData.label : ""
                        color: card.mutedColor
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        width: modelData.kind === "note" ? card.priceWidth + card.changeWidth : card.priceWidth
                        height: parent.height
                        text: modelData.kind === "note"
                              ? modelData.text
                              : (modelData.price !== undefined ? modelData.price : "")
                        color: modelData.kind === "note" ? card.mutedColor : card.textColor
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        horizontalAlignment: modelData.kind === "note" ? Text.AlignLeft : Text.AlignRight
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        visible: modelData.kind !== "note"
                        width: card.changeWidth; height: parent.height
                        text: modelData.change !== undefined ? modelData.change : ""
                        color: modelData.isPos ? card.applet.positiveColor : card.applet.negativeColor
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
