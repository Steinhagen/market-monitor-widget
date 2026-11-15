import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "../components/SettingsWindow.js" as ConfigWindow
import "../../providers/yahoo/news.js" as YahooNews

Item {
    id: page

    Component.onCompleted: {
        ConfigWindow.apply(page, Window.window);
        Qt.callLater(function() { ConfigWindow.apply(page, Window.window); });
        Qt.callLater(page.syncLanguageChecks);
    }
    Window.onWindowChanged: ConfigWindow.apply(page, Window.window)

    property alias cfg_chartStyle: chartStyleCombo.currentIndex
    property alias cfg_chartLineStyle: lineStyleCombo.currentIndex
    property alias cfg_showChartStyleButtons: chartStyleButtonsSwitch.checked
    property alias cfg_showChartRangeButtons: chartRangeButtonsSwitch.checked
    property alias cfg_showChartVolume: volumeSwitch.checked
    property alias cfg_showAnalystTargets: analystTargetsSwitch.checked
    property alias cfg_showChartHover: hoverSwitch.checked
    property alias cfg_showChartAxis: showAxisSwitch.checked
    property alias cfg_showTimeAxis: showTimeAxisSwitch.checked
    property alias cfg_showNews: newsSwitch.checked
    property alias cfg_newsSourceYahoo: newsYahooSwitch.checked
    property alias cfg_newsSourceBvb: newsBvbSwitch.checked
    property alias cfg_newsSourceGoogle: newsGoogleSwitch.checked
    property alias cfg_newsCount: newsCountSpin.value
    property alias cfg_newsRefreshMinutes: newsRefreshSpin.value
    property string cfg_newsLanguage
    property string cfg_newsLanguages
    property string cfg_chartRange

    onCfg_chartRangeChanged: {
        var idx = rangeCombo.indexOfValue(cfg_chartRange)
        if (idx >= 0) rangeCombo.currentIndex = idx
    }

    readonly property string localLanguageCode: Qt.locale().name.substring(0, 2).toLowerCase()

    // On an English system "local" is already English; the fallback would not add a
    // second language, so do not offer it there.
    readonly property var languageModes: {
        var modes = [
            { value: "system", text: i18n("Local language only") },
            { value: "english", text: i18n("English only") },
            { value: "multi", text: i18n("Several languages") }
        ];
        if (localLanguageCode !== "en")
            modes.splice(1, 0, { value: "systemFallback",
                                 text: i18n("Local language, English fallback") });
        return modes;
    }

    onCfg_newsLanguageChanged: {
        if (cfg_newsLanguage === "systemFallback" && localLanguageCode === "en")
            cfg_newsLanguage = "system";
        var idx = newsLanguageCombo.indexOfValue(cfg_newsLanguage)
        if (idx >= 0) newsLanguageCombo.currentIndex = idx
    }

    readonly property var languageOptions: [
        { code: "ro", name: "Română" },
        { code: "en", name: "English" },
        { code: "fr", name: "Français" },
        { code: "de", name: "Deutsch" },
        { code: "es", name: "Español" },
        { code: "it", name: "Italiano" },
        { code: "pt", name: "Português" },
        { code: "nl", name: "Nederlands" },
        { code: "pl", name: "Polski" },
        { code: "cs", name: "Čeština" },
        { code: "hu", name: "Magyar" },
        { code: "bg", name: "Български" },
        { code: "el", name: "Ελληνικά" },
        { code: "tr", name: "Türkçe" },
        { code: "sv", name: "Svenska" },
        { code: "da", name: "Dansk" },
        { code: "no", name: "Norsk" },
        { code: "fi", name: "Suomi" },
        { code: "ru", name: "Русский" },
        { code: "uk", name: "Українська" }
    ]

    function languageSelected(code) {
        return ("," + String(cfg_newsLanguages || "") + ",").indexOf("," + code + ",") >= 0;
    }

    // Yahoo serves English, German, French, Spanish and Italian news through the same
    // locale-aware search endpoint. The source switch is disabled when the current
    // language selection has none of them.
    readonly property bool yahooUsable: {
        var mode = String(cfg_newsLanguage || "systemFallback");
        if (mode === "english") return true;
        if (mode === "multi") {
            for (var i = 0; i < languageOptions.length; i++) {
                if (languageSelected(languageOptions[i].code)
                        && YahooNews.supportsLanguage(languageOptions[i].code))
                    return true;
            }
            return false;
        }
        if (YahooNews.supportsLanguage(localLanguageCode)) return true;
        return mode === "systemFallback";
    }

    function setLanguage(code, on) {
        var list = String(cfg_newsLanguages || "").split(",")
            .map(function (value) { return value.trim().toLowerCase(); })
            .filter(function (value) { return value !== ""; });
        var index = list.indexOf(code);
        if (on && index < 0) list.push(code);
        else if (!on && index >= 0) list.splice(index, 1);
        var value = list.join(",");
        if (value !== cfg_newsLanguages) cfg_newsLanguages = value;
    }

    function hasSelectedLanguage() {
        for (var i = 0; i < languageOptions.length; i++) {
            if (languageSelected(languageOptions[i].code)) return true;
        }
        return false;
    }

    function syncLanguageChecks() {
        if (!languageRepeater) return;
        for (var i = 0; i < languageRepeater.count; i++) {
            var check = languageRepeater.itemAt(i);
            var option = page.languageOptions[i];
            if (check && option) check.checked = languageSelected(option.code);
        }
    }

    onCfg_newsLanguagesChanged: Qt.callLater(syncLanguageChecks)

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            ComboBox {
                id: chartStyleCombo
                Kirigami.FormData.label: i18n("Chart style:")
                // The style is stored by index, so the labels can be translated freely.
                model: [i18n("Reference line (open)"), i18n("Candles")]
            }

            ComboBox {
                id: lineStyleCombo
                Kirigami.FormData.label: i18n("Line style:")
                // The style is stored by index, so the labels can be translated freely.
                model: [i18n("Smooth"), i18n("Straight")]
            }
            CheckBox {
                id: chartStyleButtonsSwitch
                text: i18n("Show chart style buttons")
            }

            CheckBox {
                id: chartRangeButtonsSwitch
                Kirigami.FormData.label: i18n("Range Selection:")
                text: i18n("Show the range buttons in the chart")
            }

            ComboBox {
                id: rangeCombo
                // This preset drives the multi-stock list and is also the chart's fallback
                // range while the in-chart range buttons have no selection of their own.
                Kirigami.FormData.label: i18n("Data Range:")
                // `value` is what gets stored in the config, `text` is only the label, so
                // translating the labels never changes the saved range.
                model: [
                    { value: "1D", text: i18n("1D") },
                    { value: "5D", text: i18n("5D") },
                    { value: "1M", text: i18n("1M") },
                    { value: "6M", text: i18n("6M") },
                    { value: "YTD", text: i18n("YTD") },
                    { value: "1Y", text: i18n("1Y") },
                    { value: "5Y", text: i18n("5Y") },
                    { value: "Max", text: i18n("Max") }
                ]
                textRole: "text"
                valueRole: "value"
                onActivated: page.cfg_chartRange = currentValue
                Component.onCompleted: {
                    var idx = indexOfValue(page.cfg_chartRange)
                    if (idx >= 0) currentIndex = idx
                }
            }

            CheckBox {
                id: hoverSwitch
                Kirigami.FormData.label: i18n("Hover:")
                text: i18n("Show values when hovering over the chart")
            }

            CheckBox {
                id: showAxisSwitch
                Kirigami.FormData.label: i18n("Price scale:")
                text: i18n("Show price values on the right of the chart")
            }

            CheckBox {
                id: showTimeAxisSwitch
                Kirigami.FormData.label: i18n("Time scale:")
                text: i18n("Show dates and times under the chart")
            }

            CheckBox {
                id: volumeSwitch
                Kirigami.FormData.label: i18n("Volume:")
                text: i18n("Show trading volume under the chart")
            }

            CheckBox {
                id: analystTargetsSwitch
                Kirigami.FormData.label: i18n("Analyst targets:")
                text: i18n("Show analyst price-target changes under the chart")
            }

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("News")
            }

            CheckBox {
                id: newsSwitch
                text: i18n("Show news headlines in the single-stock view")
            }

            ComboBox {
                id: newsLanguageCombo
                Kirigami.FormData.label: i18n("News language:")
                enabled: newsSwitch.checked
                model: page.languageModes
                textRole: "text"
                valueRole: "value"
                onActivated: page.cfg_newsLanguage = currentValue
                Component.onCompleted: {
                    if (page.cfg_newsLanguage === "")
                        page.cfg_newsLanguage = page.localLanguageCode === "en"
                                                ? "system" : "systemFallback";
                    else if (page.cfg_newsLanguage === "systemFallback"
                             && page.localLanguageCode === "en")
                        page.cfg_newsLanguage = "system";
                    var idx = indexOfValue(page.cfg_newsLanguage);
                    if (idx >= 0) currentIndex = idx;
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("Yahoo Finance is available in English, German, French, Spanish and Italian; it is queried in each selected language from that list. Google follows the selected languages and is queried once per language in Several languages mode. BVB uses its Romanian or English attachment.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: newsSwitch.checked && page.cfg_newsLanguage === "systemFallback"
                text: i18n("Local headlines first; English headlines from Google and Yahoo are appended as backup.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }

            GridLayout {
                Kirigami.FormData.label: i18n("Languages:")
                columns: 2
                columnSpacing: 12
                enabled: newsSwitch.checked && page.cfg_newsLanguage === "multi"

                Repeater {
                    id: languageRepeater
                    model: page.languageOptions
                    delegate: CheckBox {
                        required property var modelData
                        text: modelData.name
                        checked: page.languageSelected(modelData.code)
                        onToggled: page.setLanguage(modelData.code, checked)
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("Select the languages you want to see. When more than one language is shown, each headline gets a small language badge.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }

            ColumnLayout {
                Kirigami.FormData.label: i18n("News sources:")
                spacing: 0

                CheckBox {
                    id: newsYahooSwitch
                    text: i18n("Yahoo Finance (English and regional editions)")
                    enabled: newsSwitch.checked && page.yahooUsable
                }
                CheckBox {
                    id: newsBvbSwitch
                    text: i18n("BVB (Romanian/English, .RO symbols)")
                    enabled: newsSwitch.checked
                }
                CheckBox {
                    id: newsGoogleSwitch
                    text: i18n("Google (selected languages)")
                    enabled: newsSwitch.checked
                }
                Label {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                    visible: newsSwitch.checked && !newsYahooSwitch.checked && !newsBvbSwitch.checked
                             && !newsGoogleSwitch.checked
                    text: i18n("Select at least one news source.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 10
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: newsSwitch.checked && page.cfg_newsLanguage === "multi"
                         && !page.hasSelectedLanguage()
                text: i18n("Select at least one language.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.negativeTextColor
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: newsSwitch.checked && page.cfg_newsLanguage === "system"
                         && !newsGoogleSwitch.checked && !newsBvbSwitch.checked
                         && !(newsYahooSwitch.checked && page.yahooUsable)
                text: i18n("Local-only mode needs a source that covers this language.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.negativeTextColor
            }

            Label {
                Layout.fillWidth: true
                // A wrapping Label still asks for its whole text width; without a cap the
                // form makes the column that wide and the note runs past the page.
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("Headlines from the sources selected above. Yahoo Finance covers general news in English, German, French, Spanish and Italian; Google adds a web search by company name; BVB provides the issuer's announcements for symbols ending in .RO. Switch with the icons next to the market status. Not available in the list-only view.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }

            SpinBox {
                id: newsCountSpin
                Kirigami.FormData.label: i18n("Headlines per source (5–50):")
                from: 5
                to: 50
                enabled: newsSwitch.checked && (newsYahooSwitch.checked || newsBvbSwitch.checked || newsGoogleSwitch.checked)
            }

            SpinBox {
                id: newsRefreshSpin
                Kirigami.FormData.label: i18n("Update every (minutes):")
                from: 10
                to: 240
                enabled: newsSwitch.checked && (newsYahooSwitch.checked || newsBvbSwitch.checked || newsGoogleSwitch.checked)
            }
        }
    }
}
