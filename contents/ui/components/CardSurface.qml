import QtQuick
import org.kde.kirigami as Kirigami

// The rounded, bordered surface shared by the floating cards: the analyst hover and
// details cards and the market-status popup. The one-pixel border is what keeps a card
// readable where it overlaps the chart, and it follows the Application preset's forced
// light/dark surface as well as the Plasma background.
Rectangle {
    id: card

    property var applet

    readonly property bool lightTheme: applet ? applet.isLightTheme
                                             : Kirigami.Theme.backgroundColor.hslLightness > 0.5
    readonly property color textColor: applet && applet.appDrawnSurface
                                       ? (lightTheme ? "#171a1c" : "#f3f5f6")
                                       : Kirigami.Theme.textColor
    readonly property color mutedTextColor: applet ? applet.secondaryTextColor
                                                   : Kirigami.Theme.disabledTextColor

    radius: 8
    color: applet && applet.appDrawnSurface
           ? (lightTheme ? "#ffffff" : "#1a1a1a")
           : Kirigami.Theme.backgroundColor
    border.width: 1
    border.color: lightTheme ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.18)
}
