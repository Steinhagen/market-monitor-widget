import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

MouseArea {
    id: compactRoot
    property var applet
    property var stockList

    implicitWidth: {
        // An explicit width from the settings wins. Otherwise reserve room for the
        // current values, with the widest configured value as a floor in fixed mode.
        if (compactRoot.oneRow)
            return panelRow.implicitWidth + (Kirigami.Units.smallSpacing * 2);
        if (compactRoot.useFixedWidth && Plasmoid.configuration.panelWidth > 0)
            return Plasmoid.configuration.panelWidth;
        var content = Math.max(compactRoot.currentContent, panelRow.implicitWidth);
        if (compactRoot.useFixedWidth)
            content = Math.max(content, compactRoot.widestContent);
        return content + (Kirigami.Units.smallSpacing * 4);
    }
    // Never paint outside the rectangle the panel gives the applet. In a vertical
    // panel that rectangle is only as wide as the panel, so the content has to fit
    // (or elide) rather than spill over the neighbouring applets.
    clip: false
    // Keep a stable compact height so the panel does not shrink the applet in a
    // feedback loop on short panels.
    // Stable vertical height: the rows keep their normal minimum heights even
    // when a long value uses a smaller font, so neighbouring applets cannot move.
    readonly property real verticalHeight: {
        var s = compactRoot.textScale;
        var rows = 2;
        var h = Math.ceil(12 * s) + Math.ceil(13 * s);
        if (!compactRoot.alternatePrice && !applet.hideChangePercentage) {
            rows += 1;
            h += Math.ceil(12 * s);
        }
        if (applet.panelShowMarketStatus) {
            rows += 1;
            h += Math.ceil(10 * s);
        }
        return h + (rows - 1) * 4;
    }
    implicitHeight: applet.isVerticalPanel
                    ? Math.max(28, Math.ceil(compactRoot.verticalHeight))
                    : Math.max(28, panelRow.implicitHeight, twoRow.implicitHeight) + 2
    // Follow the clock's responsive behaviour: two rows with type scaled to the
    // available height, and a single readable row when two rows cannot fit.
    readonly property bool oneRow: !applet.isVerticalPanel && height > 0 && height < 28
    // Alternation is only available in the horizontal two-row layout.
    readonly property bool alternatePrice: applet.panelAlternate
                                          && !compactRoot.oneRow
                                          && !applet.isVerticalPanel
    readonly property real twoRowScale: {
        if (height <= 0) return 1;
        return Math.max(0.85, (height - 1) / 29);
    }
    // A vertical panel's constraint is its thickness (width), not its length.
    readonly property real verticalScale: {
        if (width <= 0) return 1;
        return Math.max(0.5, (width - 2) / 36);
    }
    readonly property real textScale: applet.isVerticalPanel ? verticalScale : twoRowScale
    readonly property real panelHeight: {
        // The applet parent is the panel content; the panel adds 4 px above and below.
        if (parent) return parent.height + 8;
        return height;
    }
    // Single-row text stays readable even in a short panel.
    readonly property real oneRowScale: Math.max(1.0, (compactRoot.panelHeight - 1) / 29)
    onTextScaleChanged: remeasureTimer.restart()
    onOneRowChanged: remeasureTimer.restart()
    // Let the panel decide the cross-axis size: height in a horizontal panel, width
    // in a vertical one. Requesting a minimum there made the applet keep its old
    // horizontal width after an orientation change and overlap its neighbour.
    Layout.fillWidth: applet.isVerticalPanel
    Layout.fillHeight: !applet.isVerticalPanel
    Layout.minimumWidth: applet.isVerticalPanel ? 0 : implicitWidth
    Layout.preferredWidth: applet.isVerticalPanel ? 0 : implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    // Scroll wheel / touchpad scroll cycles the stock shown in the panel.
    // Scroll up = previous stock, scroll down = next stock. Deltas are
    // accumulated so smooth-scrolling touchpads advance one step per 120 units.
    property real wheelAccum: 0
    onWheel: (wheel) => {
        if (!applet.isMultiMode || stockList.count < 2) {
            wheel.accepted = false;
            return;
        }
        wheelAccum += wheel.angleDelta.y;
        var steps = 0;
        while (wheelAccum >= 120) { steps -= 1; wheelAccum -= 120; }
        while (wheelAccum <= -120) { steps += 1; wheelAccum += 120; }
        if (steps === 0) return;

        var current = 0;
        for (var i = 0; i < stockList.count; i++) {
            if (stockList.get(i).ticker === applet.panelTicker) { current = i; break; }
        }
        var n = stockList.count;
        var next = (((current + steps) % n) + n) % n;
        var row = stockList.get(next);
        applet.selectTicker(row.ticker);
    }

    onClicked: (mouse) => {
        if (mouse.button === Qt.MiddleButton) {
            if (applet.performMiddleClick(applet.panelSymbol)) {
                // Visual feedback for a refresh; open/none need no flicker.
                compactRoot.priceFlicker = 0.3;
                timerFlicker.restart();
            }
        } else {
            applet.togglePanelPopup();
        }
    }

    Timer {
        id: timerFlicker
        interval: 300
        onTriggered: compactRoot.priceFlicker = 1.0;
    }

    // While an extended-hours session is running, the ticker has a pre-market /
    // after-hours quote (see extendedQuote()). The panel then shows that quote
    // instead of the regular price and change, and a small tag next to the ticker
    // says which session it is. Without an extended quote, the tag says CLOSED
    // while the market is closed.
    readonly property var ext: applet.extendedQuote(applet.panelSymbol)
    readonly property bool marketClosed: applet.showExtendedHours
                                         && applet.isMarketClosedFor(applet.panelSymbol)
    readonly property string shownPrice: ext ? ext.price : applet.panelCurrentPrice
    readonly property string shownPercent: ext ? ext.pct : applet.panelCurrentPercent
    readonly property bool shownPositive: ext ? ext.isPos : applet.panelCurrentIsPositive

    // --- Fixed width ---
    // Cycling through the stocks, or swapping price and percentage, changes the length of the
    // text. That used to resize the indicator and push every other applet in the panel around.
    // With a fixed width the indicator reserves room for the widest value that can appear in
    // it: the longest ticker, price and change of any configured stock, in the regular and
    // in the extended-hours session. The width then stays the same while values change.
    readonly property bool useFixedWidth: Plasmoid.configuration.fixedPanelWidth
                                          && Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    // 1 normally; 0.3 for the brief refresh feedback. Kept as a property so the
    // cached-data dimming below stays bound instead of being overwritten.
    property real priceFlicker: 1.0
    property real widestContent: 0
    property real widestPrice: 0
    // Width of the values currently shown. Used as a floor so a stale layout from
    // before an orientation change cannot clip the ticker or the badge.
    property real currentContent: 0

    // Invisible texts with exactly the fonts and rendering of the visible ones. Measuring with
    // these instead of with font metrics gives the real width, hinting included.
    property real widestBadge: 0
    Text { id: probeTicker; visible: false; font.pixelSize: compactRoot.oneRow ? 11 * compactRoot.oneRowScale : 10 * compactRoot.textScale; font.weight: applet.panelBoldSymbol ? Font.Bold : Font.Normal; renderType: Text.NativeRendering }
    Text { id: probeTag; visible: false; font.pixelSize: compactRoot.oneRow ? 8 * compactRoot.oneRowScale : 8 * compactRoot.textScale; font.weight: Font.Bold; renderType: Text.NativeRendering }
    Text { id: probePrice; visible: false; font.pixelSize: compactRoot.oneRow ? 13 * compactRoot.oneRowScale : 10 * compactRoot.textScale; renderType: Text.NativeRendering }
    Text { id: probeBadge; visible: false; font.pixelSize: compactRoot.oneRow ? 11 : 9 * compactRoot.textScale; renderType: Text.NativeRendering }

    function measureWidest() {
        var tickers = [], prices = [], pcts = [];
        var collect = function(ticker, price, pct) {
            tickers.push(applet.displayTicker(ticker));
            prices.push(String(price || ""));
            pcts.push(String(pct || ""));
            var e = applet.extendedQuote(ticker);
            if (e) { prices.push(e.price); pcts.push(e.pct); }
        };
        if (applet.isMultiMode) {
            for (var i = 0; i < stockList.count; i++) {
                var row = stockList.get(i);
                collect(row.ticker, row.price, row.pct);
            }
        } else {
            collect(applet.panelSymbol, applet.panelCurrentPrice, applet.panelCurrentPercent);
        }
        // Width of the widest of `list` when drawn by `probe`.
        // Each piece is rounded up to whole pixels, as the layout does for every item;
        // adding unrounded widths would come out a pixel short.
        var widest = function(list, probe) {
            var w = 0;
            for (var j = 0; j < list.length; j++) {
                probe.text = list[j];
                w = Math.max(w, Math.ceil(probe.implicitWidth));
            }
            return w;
        };
        var widthOf = function(probe, text) { probe.text = text; return Math.ceil(probe.implicitWidth); };

        // First line: ticker, arrow and, if extended hours are shown, the session tag.
        var arrowW = Math.max(widthOf(probeTag, "▲"), widthOf(probeTag, "▼"));
        // Measured from the same (translated) tags the panel shows, so a longer
        // translation still fits in the reserved width.
        var tagW = applet.panelShowMarketStatus
                   ? Math.max(widthOf(probeTag, applet.tagAfterHours),
                              widthOf(probeTag, applet.tagPreMarket),
                              widthOf(probeTag, applet.tagClosed))
                   : 0;
        var line1 = widest(tickers, probeTicker) + 4 + arrowW
                    + (tagW > 0 ? 4 + tagW : 0);

        // Second line: price and change badge (or the wider of the two when they alternate).
        var priceW = widest(prices, probePrice);
        var showBadge = !applet.hideChangePercentage;
        var badgeW = showBadge ? widest(pcts, probeBadge) + (Kirigami.Units.smallSpacing * 2) : 0;
        var line2 = applet.isVerticalPanel
                    ? Math.max(priceW, badgeW)
                    : (compactRoot.alternatePrice && showBadge ? Math.max(priceW, badgeW)
                                                          : priceW + (showBadge ? 6 + badgeW : 0));

        // Width of the values on screen right now, so an orientation change cannot
        // leave the indicator narrower than its own content.
        var currentTicker = applet.displayTicker(applet.isMultiMode ? applet.panelTicker : applet.singleTicker);
        var showCurrentTag = applet.panelShowMarketStatus
                             && (compactRoot.marketClosed || compactRoot.ext !== undefined
                                 || applet.panelCurrentIsCached);
        var currentTagW = showCurrentTag ? tagW : 0;
        var currentLine1 = widthOf(probeTicker, currentTicker) + 4 + arrowW
                           + (currentTagW > 0 ? 4 + currentTagW : 0);
        var currentPriceW = widthOf(probePrice, compactRoot.shownPrice);
        var currentBadgeW = showBadge
                            ? widthOf(probeBadge, compactRoot.shownPercent) + (Kirigami.Units.smallSpacing * 2)
                            : 0;
        var currentLine2 = applet.isVerticalPanel
                           ? Math.max(currentPriceW, currentBadgeW)
                           : (compactRoot.alternatePrice && showBadge
                              ? Math.max(currentPriceW, currentBadgeW)
                              : currentPriceW + (showBadge ? 6 + currentBadgeW : 0));

        // The single-row layout uses larger fixed fonts, so measure its own line
        // too; otherwise the fixed width would keep the two-row dimensions.
        var oneRowValueW = (compactRoot.alternatePrice && showBadge)
                           ? Math.max(priceW, badgeW)
                           : priceW + (showBadge ? 4 + badgeW : 0);
        var oneRowW = compactRoot.oneRow
                      ? widest(tickers, probeTicker) + 4
                        + (showCurrentTag ? tagW + 4 : 0)
                        + oneRowValueW
                      : 0;
        var currentOneRowValueW = (compactRoot.alternatePrice && showBadge)
                                  ? Math.max(currentPriceW, currentBadgeW)
                                  : currentPriceW + (showBadge ? 4 + currentBadgeW : 0);
        var currentOneRowW = compactRoot.oneRow
                             ? widthOf(probeTicker, currentTicker) + 4
                               + (showCurrentTag ? currentTagW + 4 : 0)
                               + currentOneRowValueW
                             : 0;

        return { "content": Math.ceil(Math.max(line1, line2, oneRowW)),
                 "price": Math.ceil(priceW),
                 "badge": Math.ceil(badgeW),
                 "current": Math.ceil(Math.max(currentLine1, currentLine2, currentOneRowW)) };
    }

    function remeasure() {
        var m = measureWidest();
        compactRoot.widestContent = m.content;
        compactRoot.widestPrice = m.price;
        compactRoot.widestBadge = m.badge;
        compactRoot.currentContent = m.current;
    }

    // Values arrive in bursts (one reply per ticker), so measure once they settle.
    Timer { id: remeasureTimer; interval: 100; onTriggered: compactRoot.remeasure() }
    Component.onCompleted: compactRoot.remeasure()
    Connections {
        target: stockList
        function onDataChanged() { remeasureTimer.restart(); }
        function onRowsInserted() { remeasureTimer.restart(); }
        function onRowsRemoved() { remeasureTimer.restart(); }
        function onModelReset() { remeasureTimer.restart(); }
    }
    Connections {
        target: applet
        function onPanelCurrentPriceChanged() { remeasureTimer.restart(); }
        function onPanelCurrentPercentChanged() { remeasureTimer.restart(); }
        function onSingleTickerChanged() { remeasureTimer.restart(); }
        function onIsMultiModeChanged() { remeasureTimer.restart(); }
        function onShowExtendedHoursChanged() { remeasureTimer.restart(); }
        function onHideChangePercentageChanged() { remeasureTimer.restart(); }
        function onPanelAlternateChanged() { remeasureTimer.restart(); }
        function onIsVerticalPanelChanged() { remeasureTimer.restart(); }
        function onSymbolDisplayModeChanged() { remeasureTimer.restart(); }
        function onSingleExchangeChanged() { remeasureTimer.restart(); }
    }

    RowLayout {
        id: panelRow
        // Fill the rectangle the panel gives the applet, with a small side margin in
        // a horizontal panel. In a vertical panel the row fills the panel thickness
        // and the labels are centred/elided inside it. Filling also keeps the content
        // inside the applet instead of letting it spill over the neighbour.
        anchors.fill: parent
        anchors.leftMargin: applet.isVerticalPanel ? 0 : Kirigami.Units.smallSpacing * 2
        anchors.rightMargin: applet.isVerticalPanel ? 0 : Kirigami.Units.smallSpacing * 2
        anchors.bottomMargin: 0
        spacing: 8

        ColumnLayout {
            id: twoRow
            visible: !compactRoot.oneRow
            // The status tag and the percentage badge share the right edge of the
            // indicator. Negative spacing made the bottom of the tag/arrow overlap
            // the top of the badge, so keep a small positive gap between the rows.
            spacing: 4
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: applet.isVerticalPanel

            RowLayout {
                spacing: 4
                Layout.fillWidth: applet.isVerticalPanel
                Layout.minimumHeight: Math.ceil(12 * compactRoot.textScale)
                Layout.preferredHeight: Math.ceil(12 * compactRoot.textScale)
                Layout.maximumHeight: Math.ceil(12 * compactRoot.textScale)
                Text {
                    text: applet.displayTicker(applet.isMultiMode ? applet.panelTicker : applet.singleTicker)
                    color: applet.panelTextColor
                    font.pixelSize: (applet.isVerticalPanel ? 11 : 10) * compactRoot.textScale
                    font.weight: applet.panelBoldSymbol ? Font.Bold : Font.Normal
                    renderType: Text.NativeRendering
                    opacity: 0.8
                    Layout.alignment: Qt.AlignBottom
                    Layout.fillWidth: applet.isVerticalPanel
                    horizontalAlignment: applet.isVerticalPanel ? Text.AlignHCenter : Text.AlignLeft
                    elide: Text.ElideRight
                }
                // In a vertical panel only the ticker and the price fit in the panel
                // thickness; the colour already shows the direction and the tooltip
                // carries the session tag.
                Text {
                    visible: !applet.isVerticalPanel
                    text: compactRoot.shownPositive ? "▲" : "▼"
                    color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    font.pixelSize: 8 * compactRoot.textScale
                    renderType: Text.NativeRendering
                }
                // Session tag: AH = after-hours, PRE = pre-market, CLOSED = the
                // exchange is not trading and there is no extended quote to show.
                Text {
                    visible: applet.panelShowMarketStatus
                             && (compactRoot.ext !== undefined || compactRoot.marketClosed
                                 || applet.panelCurrentIsCached)
                             && !applet.isVerticalPanel
                    // While the values come from the config snapshot, mark them as
                    // stale instead of showing a session tag computed from live data.
                    text: applet.panelCurrentIsCached
                          ? i18nc("@item:panel stock data state", "OFF")
                          : (compactRoot.marketClosed
                             ? applet.tagClosed
                             : (compactRoot.ext
                                ? (compactRoot.ext.kind === "pre" ? applet.tagPreMarket : applet.tagAfterHours)
                                : ""))
                    color: applet.panelCurrentIsCached ? applet.warningTextColor : applet.panelTextColor
                    opacity: applet.panelCurrentIsCached ? 1.0 : 0.45
                    font.pixelSize: 8 * compactRoot.textScale
                    renderType: Text.NativeRendering
                }
            }

            RowLayout {
                spacing: 6
                Layout.alignment: applet.isVerticalPanel ? Qt.AlignHCenter : Qt.AlignLeft
                Layout.fillWidth: applet.isVerticalPanel
                Layout.minimumHeight: Math.ceil(13 * compactRoot.textScale)
                Layout.preferredHeight: Math.ceil(13 * compactRoot.textScale)
                Layout.maximumHeight: Math.ceil(13 * compactRoot.textScale)

                Text {
                    id: panelPrice
                    // The currency symbol does not fit in the panel thickness together
                    // with a five-digit price, and the ticker already identifies the
                    // instrument; the tooltip shows the full value.
                    text: {
                        var price = compactRoot.shownPrice;
                        return applet.isVerticalPanel && applet.currencySym !== ""
                               ? price.replace(applet.currencySym, "")
                               : price;
                    }
                    // When alternating, the price and the percentage badge share one spot:
                    // this item is hidden while the percentage is shown, and both keep the
                    // width of the wider one so the panel does not resize on every switch.
                    visible: !compactRoot.alternatePrice || !applet.panelShowPercent
                    horizontalAlignment: applet.isVerticalPanel
                                         ? Text.AlignHCenter
                                         : (compactRoot.alternatePrice ? Text.AlignHCenter : Text.AlignLeft)
                    // Fixed width: give the price the width of the widest price, so the badge
                    // next to it stays put while the price changes.
                    Layout.minimumWidth: 0
                    Layout.fillWidth: applet.isVerticalPanel
                    elide: Text.ElideRight
                    color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    font.pixelSize: (applet.isVerticalPanel
                                     ? (compactRoot.shownPrice.length > 10 ? 7
                                        : compactRoot.shownPrice.length > 7 ? 7 : 11)
                                     : 10) * compactRoot.textScale
                    renderType: Text.NativeRendering
                    // Ensure the price text is fully opaque; color is controlled by the line above
                    // Cached startup values are dimmed, so they never read as live.
                    opacity: compactRoot.priceFlicker * (applet.panelCurrentIsCached ? 0.7 : 1.0)
                }

                Rectangle {
                    radius: 4 * compactRoot.textScale
                    opacity: applet.panelCurrentIsCached ? 0.7 : 1.0
                    visible: !applet.isVerticalPanel
                             && !applet.hideChangePercentage
                             && (!compactRoot.alternatePrice || applet.panelShowPercent)
                    // Background: translucent tint of the positive/negative color for theme independence
                    color: compactRoot.shownPositive
                           ? Qt.rgba(applet.panelPositiveColor.r, applet.panelPositiveColor.g, applet.panelPositiveColor.b, 0.18)
                           : Qt.rgba(applet.panelNegativeColor.r, applet.panelNegativeColor.g, applet.panelNegativeColor.b, 0.18)
                    border.color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    border.width: 1
                    Layout.preferredWidth: pctText2.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                    // Fixed width: every value gets the same badge width (the text stays centred),
                    // so the panel has no spare room on the right of a short value.
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: pctText2.implicitHeight
                                            + (Kirigami.Units.smallSpacing / 2)

                    Text {
                        id: pctText2
                        anchors.centerIn: parent
                        text: compactRoot.shownPercent
                        color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                        font.pixelSize: 9 * compactRoot.textScale
                        renderType: Text.NativeRendering
                    }
                }

                Rectangle {
                    visible: applet.isVerticalPanel
                             && compactRoot.alternatePrice
                             && !applet.hideChangePercentage
                             && applet.panelShowPercent
                    radius: 3
                    opacity: applet.panelCurrentIsCached ? 0.7 : 1.0
                    color: compactRoot.shownPositive
                           ? Qt.rgba(applet.panelPositiveColor.r, applet.panelPositiveColor.g, applet.panelPositiveColor.b, 0.18)
                           : Qt.rgba(applet.panelNegativeColor.r, applet.panelNegativeColor.g, applet.panelNegativeColor.b, 0.18)
                    border.color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    border.width: 1
                    Layout.preferredWidth: altPct.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: altPct.implicitHeight + (Kirigami.Units.smallSpacing / 2)

                    Text {
                        id: altPct
                        anchors.centerIn: parent
                        text: compactRoot.shownPercent
                        color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                        font.pixelSize: 9 * compactRoot.textScale
                        renderType: Text.NativeRendering
                    }
                }
            }
            RowLayout {
                visible: applet.isVerticalPanel
                         && !compactRoot.alternatePrice
                         && !applet.hideChangePercentage
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumHeight: Math.ceil(12 * compactRoot.textScale)
                Layout.preferredHeight: Math.ceil(12 * compactRoot.textScale)
                Layout.maximumHeight: Math.ceil(12 * compactRoot.textScale)
                spacing: 0

                Rectangle {
                    radius: 3
                    opacity: applet.panelCurrentIsCached ? 0.7 : 1.0
                    color: compactRoot.shownPositive
                           ? Qt.rgba(applet.panelPositiveColor.r, applet.panelPositiveColor.g, applet.panelPositiveColor.b, 0.18)
                           : Qt.rgba(applet.panelNegativeColor.r, applet.panelNegativeColor.g, applet.panelNegativeColor.b, 0.18)
                    border.color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    border.width: 1
                    Layout.preferredWidth: vPct.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: vPct.implicitHeight + (Kirigami.Units.smallSpacing / 2)

                    Text {
                        id: vPct
                        anchors.centerIn: parent
                        text: compactRoot.shownPercent
                        color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                        font.pixelSize: 9 * compactRoot.textScale
                        renderType: Text.NativeRendering
                    }
                }
            }

            RowLayout {
                visible: applet.isVerticalPanel && applet.panelShowMarketStatus
                         && (compactRoot.ext !== undefined || compactRoot.marketClosed
                             || applet.panelCurrentIsCached)
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumHeight: Math.ceil(10 * compactRoot.textScale)
                spacing: 0

                Text {
                    text: applet.panelCurrentIsCached
                          ? i18nc("@item:panel stock data state", "OFF")
                          : (compactRoot.marketClosed
                             ? applet.tagClosed
                             : (compactRoot.ext
                                ? (compactRoot.ext.kind === "pre" ? applet.tagPreMarket : applet.tagAfterHours)
                                : ""))
                    color: applet.panelCurrentIsCached ? applet.warningTextColor : applet.panelTextColor
                    opacity: applet.panelCurrentIsCached ? 1.0 : 0.45
                    font.pixelSize: 8 * compactRoot.textScale
                    renderType: Text.NativeRendering
                }
            }
        }

        RowLayout {
            visible: compactRoot.oneRow
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4
            Layout.minimumHeight: Math.ceil(14 * compactRoot.oneRowScale) + 2
            Layout.preferredHeight: Math.ceil(14 * compactRoot.oneRowScale) + 2
            Layout.maximumHeight: Math.ceil(14 * compactRoot.oneRowScale) + 2

            Text {
                id: oneTicker
                text: applet.displayTicker(applet.isMultiMode ? applet.panelTicker : applet.singleTicker)
                color: applet.panelTextColor
                Layout.fillHeight: true
                font.pixelSize: 11 * compactRoot.oneRowScale
                font.weight: applet.panelBoldSymbol ? Font.Bold : Font.Normal
                renderType: Text.NativeRendering
                opacity: 0.6
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignVCenter            }

            Text {
                visible: applet.panelShowMarketStatus
                         && (compactRoot.ext !== undefined || compactRoot.marketClosed
                             || applet.panelCurrentIsCached)
                text: applet.panelCurrentIsCached
                      ? i18nc("@item:panel stock data state", "OFF")
                      : (compactRoot.marketClosed
                         ? applet.tagClosed
                         : (compactRoot.ext
                            ? (compactRoot.ext.kind === "pre" ? applet.tagPreMarket : applet.tagAfterHours)
                            : ""))
                color: applet.panelCurrentIsCached ? applet.warningTextColor : applet.panelTextColor
                opacity: applet.panelCurrentIsCached ? 1.0 : 0.45
                font.pixelSize: 8 * compactRoot.oneRowScale
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                id: onePrice
                visible: true
                text: compactRoot.shownPrice
                color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                font.pixelSize: 13 * compactRoot.oneRowScale
                renderType: Text.NativeRendering
                elide: Text.ElideRight
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                visible: !applet.hideChangePercentage
                radius: 3
                color: compactRoot.shownPositive
                       ? Qt.rgba(applet.panelPositiveColor.r, applet.panelPositiveColor.g, applet.panelPositiveColor.b, 0.18)
                       : Qt.rgba(applet.panelNegativeColor.r, applet.panelNegativeColor.g, applet.panelNegativeColor.b, 0.18)
                border.color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                border.width: 1
                Layout.preferredWidth: onePct.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                Layout.minimumWidth: 0
                Layout.preferredHeight: onePct.implicitHeight + (Kirigami.Units.smallSpacing / 2)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: onePct
                    anchors.centerIn: parent
                    text: compactRoot.shownPercent
                    color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    font.pixelSize: 9 * compactRoot.oneRowScale
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
