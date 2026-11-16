import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "../components/SettingsWindow.js" as ConfigWindow

Item {
    id: page

    Component.onCompleted: {
        ConfigWindow.apply(page, Window.window);
        Qt.callLater(function() { ConfigWindow.apply(page, Window.window); });
        priceDecimalsCombo.currentIndex =
            Math.max(0, priceDecimalsCombo.decimalValues.indexOf(page.cfg_priceDecimals));
    }
    Window.onWindowChanged: ConfigWindow.apply(page, Window.window)

    property alias cfg_refreshInterval: intervalSpin.value
    
    property alias cfg_limitHours: limitHoursSwitch.checked
    property alias cfg_skipWeekendRefresh: skipWeekendRefreshSwitch.checked
    property alias cfg_hideTimestamps: hideTimestampsSwitch.checked
    property alias cfg_formatPrices: formatPricesSwitch.checked
    // -1 = automatic (Yahoo Finance), 0-6 = fixed number of decimals.
    property int cfg_priceDecimals: -1

    // The configuration dialog listens for this signal to enable Apply when a control
    // changes more than one alias at once (the precision combo writes one value).
    signal configurationChanged()
    property alias cfg_showExtendedHours: extendedHoursSwitch.checked
    property alias cfg_keepExtendedAfterClose: keepExtendedAfterCloseSwitch.checked
    property alias cfg_startHour: startHourSpin.value
    property alias cfg_startMinute: startMinuteSpin.value
    property alias cfg_endHour: endHourSpin.value
    property alias cfg_endMinute: endMinuteSpin.value

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            SpinBox {
                id: intervalSpin
                Kirigami.FormData.label: i18n("Refresh Interval (minutes):")
                from: 1
                to: 360
            }

            CheckBox {
                id: limitHoursSwitch
                Kirigami.FormData.label: i18n("Active Hours:")
                text: i18n("Only refresh data during market hours")
            }

            CheckBox {
                id: skipWeekendRefreshSwitch
                Kirigami.FormData.label: i18n("Weekend Refresh:")
                text: i18n("Do not refresh data on weekends (Sat,Sun)")
            }

            RowLayout {
                visible: limitHoursSwitch.checked
                Kirigami.FormData.label: i18n("Market Open:")
                SpinBox { id: startHourSpin; from: 0; to: 23; }
                Label { text: ":" }
                SpinBox { id: startMinuteSpin; from: 0; to: 59; }
            }

            RowLayout {
                visible: limitHoursSwitch.checked
                Kirigami.FormData.label: i18n("Market Close:")
                SpinBox { id: endHourSpin; from: 0; to: 23; }
                Label { text: ":" }
                SpinBox { id: endMinuteSpin; from: 0; to: 59; }
            }

            CheckBox {
                id: hideTimestampsSwitch
                Kirigami.FormData.label: i18n("Update Timestamps:")
                text: i18n("Hide update timestamps")
            }
            
            CheckBox {
                id: formatPricesSwitch
                Kirigami.FormData.label: i18n("Value Formatting:")
                text: i18n("Format prices with commas (e.g. 1,000.00)")
            }

            ComboBox {
                id: priceDecimalsCombo
                Kirigami.FormData.label: i18n("Price Decimals:")
                // The first entry is automatic; the rest map to a fixed 0-6.
                readonly property var decimalValues: [-1, 0, 1, 2, 3, 4, 5, 6]
                model: [
                    i18n("Automatic (Yahoo Finance)"),
                    i18n("0 (whole numbers)"),
                    "1", "2", "3", "4", "5", "6"
                ]
                onActivated: {
                    page.cfg_priceDecimals = decimalValues[currentIndex];
                    page.configurationChanged();
                }
            }

            Label {
                Layout.fillWidth: true
                text: i18n("Automatic follows Yahoo Finance: usually 2 decimals for shares and 4 for exchange rates.")
                font.pixelSize: 10
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            CheckBox {
                id: extendedHoursSwitch
                Kirigami.FormData.label: i18n("Extended Hours:")
                text: i18n("Show pre-market and after-hours values and market-closed status")
            }

            CheckBox {
                id: keepExtendedAfterCloseSwitch
                Kirigami.FormData.label: i18n("When Closed:")
                text: i18n("Keep showing the last pre-market/after-hours quote")
                enabled: extendedHoursSwitch.checked
            }
            
        }
    }
}
