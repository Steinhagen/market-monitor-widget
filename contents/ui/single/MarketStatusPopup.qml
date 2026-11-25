import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

// The market-data card shown when the status in the header is hovered. Plasma's
// ToolTipArea always draws the system tooltip frame, which an applet cannot style, so
// this popup draws the same card surface as the analyst hover and details cards: the
// rounded corners and the one-pixel border that make the card stand out over the chart.
Popup {
    id: marketStatusPopup

    property var applet
    property var host
    property Item anchorItem
    // The header ends below the status, so the card must clear the whole header
    // rather than just the status row's height.
    property Item belowItem

    readonly property bool dataAvailable: host !== null && host !== undefined
                                         && host.marketDataAvailable

    // Follow the content instead of a fixed width: the old 240-360 range left a gap
    // between the text and the right-aligned tags. The card still has to fit the parent
    // card, so a narrow widget caps it.
    readonly property real maxCardWidth: parent
                                         ? Math.max(160, Math.min(360, parent.width - 8))
                                         : 340
    width: Math.min(maxCardWidth, Math.max(200, implicitWidth))
    padding: 10
    modal: false
    focus: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onDataAvailableChanged: if (!dataAvailable) close()
    onOpened: positionCard()
    onWidthChanged: if (opened) positionCard()
    onHeightChanged: if (opened) positionCard()
    onClosed: {
        showTimer.stop();
        hideTimer.stop();
    }

    // Close the card when its anchor disappears, for example when the session label
    // is hidden because the market data is not available.
    Connections {
        target: marketStatusPopup.anchorItem
        function onVisibleChanged() {
            if (!marketStatusPopup.anchorItem || !marketStatusPopup.anchorItem.visible)
                marketStatusPopup.close();
        }
    }

    // Keep the tooltip's timing: show after a short hover, hide as soon as the pointer
    // leaves the status. The short hide delay avoids flicker at the row's edge.
    Timer {
        id: showTimer
        interval: 500
        onTriggered: marketStatusPopup.openCard()
    }
    Timer {
        id: hideTimer
        interval: 120
        onTriggered: marketStatusPopup.close()
    }

    function scheduleShow() {
        if (!dataAvailable || !anchorItem) return;
        hideTimer.stop();
        showTimer.restart();
    }

    function scheduleHide() {
        showTimer.stop();
        hideTimer.restart();
    }

    function openCard() {
        if (!dataAvailable || !anchorItem || !parent) return;
        positionCard();
        open();
        Qt.callLater(positionCard);
    }

    // Right-align the card with the status and drop it below the header. The status sits
    // on the header's first line, so above it there is no room inside the applet.
    function positionCard() {
        if (!parent || !anchorItem) return;
        var p = anchorItem.mapToItem(parent, 0, 0);
        var below = belowItem || anchorItem;
        var b = below.mapToItem(parent, 0, 0);
        x = Math.max(4, Math.min(parent.width - width - 4, p.x + anchorItem.width - width));
        y = Math.max(4, Math.min(parent.height - height - 4,
                                 b.y + below.height + 6));
    }

    background: CardSurface {
        id: card
        applet: marketStatusPopup.applet
    }

    contentItem: ColumnLayout {
        width: marketStatusPopup.availableWidth
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: host.marketSessionColor
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: i18n("Market data")
                color: card.textColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: marketTipRefreshLabel.implicitWidth + 12
                implicitHeight: marketTipRefreshLabel.implicitHeight + 4
                radius: height / 2
                color: Qt.rgba(card.textColor.r, card.textColor.g, card.textColor.b, 0.06)
                border.width: 1
                border.color: Qt.rgba(card.textColor.r, card.textColor.g, card.textColor.b, 0.12)

                Text {
                    id: marketTipRefreshLabel
                    anchors.centerIn: parent
                    text: host.marketDataRefreshLabel
                    color: card.mutedTextColor
                    font.pixelSize: 9
                }
            }
        }

        // When the regular session opens (while the market is closed) or closes
        // (while it is open). Hidden when the exchange has no session metadata or
        // trades around the clock.
        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: host.marketSessionHint
            color: card.textColor
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: host.marketDataUpdatedLine
            color: card.textColor
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: host.marketDataQuoteTime !== ""

            Text {
                text: i18n("Yahoo quote %1", host.marketDataQuoteTime)
                color: card.mutedTextColor
                font.pixelSize: 10
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: marketTipDelayLabel.implicitWidth + 12
                implicitHeight: marketTipDelayLabel.implicitHeight + 4
                radius: height / 2
                color: host.marketDataWarnBackground
                border.width: 1
                border.color: Qt.rgba(host.marketDataWarnColor.r,
                                      host.marketDataWarnColor.g,
                                      host.marketDataWarnColor.b, 0.28)

                Text {
                    id: marketTipDelayLabel
                    anchors.centerIn: parent
                    text: i18n("may be delayed")
                    color: host.marketDataWarnColor
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: host.waitingForFirstQuote
            text: i18n("The market is open; waiting for its first regular quote.")
            color: card.mutedTextColor
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }
}
