import QtQuick
import org.kde.kirigami as Kirigami

// Compact tooltip card for a single stock. Unlike the list card it is a quote summary:
// the name and update state in the title bar, a large price with its change, and one
// muted line with the period, market status and session date. Extended-hours and
// portfolio figures appear as extra compact lines only when they exist.
Item {
    id: card
    property var applet: null

    readonly property int revision: applet && applet.tooltipRevision !== undefined
                                    ? applet.tooltipRevision : 0
    readonly property bool cached: applet ? applet.showingCachedData : false
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property int rightWidth: cached ? 170 : 100
    readonly property int contentWidth: card.width - 24

    implicitWidth: Math.min(368, Math.max(300, Math.ceil(desiredWidth)))
    width: implicitWidth
    height: implicitHeight
    implicitHeight: 44 + body.implicitHeight + 12

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    FontMetrics {
        id: titleMetrics
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    FontMetrics {
        id: metaMetrics
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: 10
    }

    readonly property real desiredWidth: Math.max(240,
        titleMetrics.advanceWidth(titleText) + rightWidth + 8,
        metaMetrics.advanceWidth(metaText)) + 24

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

    readonly property bool loading: !applet || applet.currentPrice === ""
                                    || applet.currentPrice === "---"
    readonly property string priceText: loading ? i18n("Loading…") : applet.currentPrice
    readonly property string changeText: loading || !applet || applet.priceChange === ""
                                         ? "" : applet.priceChange + " (" + applet.percentChange + ")"
    readonly property bool isPos: applet ? applet.isPositive : true
    readonly property bool isNeutral: applet ? applet.isNeutral : false

    readonly property var ext: applet ? applet.extendedQuote(applet.singleTicker) : null
    readonly property bool hasExt: !!ext

    readonly property string metaText: {
        var rev = revision;
        if (!applet) return "";
        var parts = [];
        if (applet.chartPeriodLabel !== "") parts.push(applet.chartPeriodLabel);
        if (applet.showExtendedHours && applet.isMarketClosedFor(applet.singleTicker))
            parts.push(i18n("Market closed"));
        if (sessionText !== "") parts.push(sessionText);
        return parts.join(" · ");
    }


    readonly property string positionText: {
        if (!applet || !applet.showPortfolioMode || !applet.hasPortfolioEntry) return "";
        var p = applet.portfolioSummary;
        var sym = applet.getCurrencySymbol(p.currency);
        return i18n("Position") + ": "
               + i18np("%1 share · avg %2", "%1 shares · avg %2",
                       p.shares, applet.formatMoney(sym, p.avgCost, false));
    }

    readonly property string plText: {
        if (!applet || !applet.showPortfolioMode || !applet.hasPortfolioEntry) return "";
        var p = applet.portfolioSummary;
        var sym = applet.getCurrencySymbol(p.currency);
        return i18n("P/L") + " "
               + applet.formatMoney(sym, p.plValue, true)
               + " (" + applet.formatPercent(p.plPercent) + ")";
    }

    readonly property bool plIsPos: applet && applet.hasPortfolioEntry
                                    ? applet.portfolioSummary.plIsPos : true
    readonly property bool plIsNeutral: applet && applet.hasPortfolioEntry
                                        ? applet.portfolioSummary.plIsNeutral === true : false

    Item {
        width: card.width
        height: 36

        Text {
            x: 12; y: 0
            width: card.width - 24 - card.rightWidth
            height: 36
            text: card.titleText
            color: card.textColor
            font.pixelSize: 13
            font.weight: Font.DemiBold
            // The title carries the company name and ticker from the feed/config.
            textFormat: Text.PlainText
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 0; height: 36
            width: card.rightWidth
            text: card.rightText
            color: card.cached ? (card.applet ? card.applet.warningTextColor : card.mutedColor)
                               : card.mutedColor
            font.pixelSize: 11
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
        spacing: 4

        Row {
            width: parent.width
            height: 24

            Text {
                width: parent.width / 2
                height: parent.height
                text: card.priceText
                color: card.textColor
                font.pixelSize: card.loading ? 12 : 18
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: parent.width / 2
                height: parent.height
                text: card.changeText
                color: card.isNeutral ? card.applet.neutralColor
                                      : (card.isPos ? card.applet.positiveColor
                                                    : card.applet.negativeColor)
                font.pixelSize: 12
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Row {
            width: parent.width
            height: 18
            visible: card.hasExt

            Text {
                width: parent.width - 84 - 96; height: parent.height
                text: card.ext ? card.ext.label : ""
                color: card.mutedColor
                font.pixelSize: 11
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: 84; height: parent.height
                text: card.ext ? card.ext.price : ""
                color: card.textColor
                font.pixelSize: 12
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                width: 96; height: parent.height
                text: card.ext && card.ext.change !== ""
                      ? card.ext.change + " (" + card.ext.pct + ")" : ""
                color: card.ext
                       ? (card.ext.isNeutral ? card.applet.neutralColor
                          : (card.ext.isPos ? card.applet.positiveColor
                                            : card.applet.negativeColor))
                       : card.applet.negativeColor
                font.pixelSize: 12
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: card.positionText
            color: card.mutedColor
            font.pixelSize: 10
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: card.plText
            color: card.plIsNeutral ? card.applet.neutralColor
                                    : (card.plIsPos ? card.applet.positiveColor
                                                    : card.applet.negativeColor)
            font.pixelSize: 11
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: card.metaText
            color: card.mutedColor
            font.pixelSize: 10
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
    }
}
