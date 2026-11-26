import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../core/Text.js" as TextUtil

// One lot row in the portfolio table. The page owns the data and formatting; this
// component lays out the values and its edit\/remove menu.
ColumnLayout {
    id: row
    // The page is called `host`, not `page`: a property named `page` would shadow the
    // `page` id of the settings page in the delegate binding (`page: page` binds the
    // property to itself and leaves it undefined).
    property var host
    property var lot
    property var market: host ? host.lotMarketData(lot) : null
    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.preferredWidth: host.tableSymbolWidth
            Layout.minimumWidth: host.tableSymbolWidth
            Layout.maximumWidth: host.tableSymbolWidth
            clip: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: lot.ticker || ""
                font.bold: true
                textFormat: Text.PlainText
                elide: Text.ElideRight
                clip: true
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: lot.details || ""
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 9
                textFormat: Text.PlainText
                elide: Text.ElideRight
                clip: true
            }
        }
        Label {
            text: String(Number(lot.shares) || 0)
            Layout.preferredWidth: 45
            Layout.minimumWidth: 45
            Layout.maximumWidth: 45
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
        Label {
            text: host.formatNumber(lot.averageCost || 0)
            Layout.preferredWidth: 65
            Layout.minimumWidth: 65
            Layout.maximumWidth: 65
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
        Label {
            text: lot.currency || "USD"
            Layout.preferredWidth: 45
            Layout.minimumWidth: 45
            Layout.maximumWidth: 45
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
        Label {
            text: host.formatLotDate(lot.addedDate)
            Layout.preferredWidth: 100
            Layout.minimumWidth: 100
            Layout.maximumWidth: 100
            elide: Text.ElideRight
        }
        Label {
            text: host.lotValueText(lot)
            Layout.preferredWidth: host.tableValueWidth
            Layout.minimumWidth: host.tableValueWidth
            Layout.maximumWidth: host.tableValueWidth
            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            elide: Text.ElideLeft
            color: market ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }
        ColumnLayout {
            Layout.preferredWidth: host.tableGainWidth
            Layout.minimumWidth: host.tableGainWidth
            Layout.maximumWidth: host.tableGainWidth
            spacing: 0

            HoverHandler { id: gainHover }
            ToolTip.visible: gainHover.hovered
            ToolTip.text: TextUtil.plainText(market
                          ? i18n("Gain per share: %1",
                                 host.moneyText(market.currency, market.perShare))
                          : i18n("Quote unavailable."))

            Label {
                Layout.fillWidth: true
                text: host.lotGainText(lot)
                color: market
                       ? (market.gain >= 0 ? Kirigami.Theme.positiveTextColor
                                           : Kirigami.Theme.negativeTextColor)
                       : Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
                font.bold: true
                elide: Text.ElideLeft
            }

            Label {
                Layout.fillWidth: true
                visible: market !== null
                text: host.lotGainPercentText(lot)
                color: market
                       ? (market.gain >= 0 ? Kirigami.Theme.positiveTextColor
                                           : Kirigami.Theme.negativeTextColor)
                       : Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
                font.pixelSize: 9
                opacity: 0.8
                elide: Text.ElideLeft
            }
        }
        ToolButton {
            id: rowActionButton
            text: "⋮"
            Layout.preferredWidth: 45
            Layout.minimumWidth: 45
            Layout.maximumWidth: 45
            onClicked: rowMenu.popup()
            ToolTip.visible: hovered
            ToolTip.text: i18n("Lot actions")

            Menu {
                id: rowMenu
                MenuItem {
                    text: i18n("Edit")
                    onTriggered: host.editLot(lot._index)
                }
                MenuItem {
                    text: i18n("Remove")
                    onTriggered: host.removeLot(lot._index)
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.09)
    }
}
