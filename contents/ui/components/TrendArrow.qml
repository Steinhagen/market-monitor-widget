import QtQuick

// A small filled triangle for analyst target directions. The triangle's centroid, not
// its bounding box, is placed at the item's centre: a triangle's visual centre of mass
// sits one sixth of its height below/above the bounding-box centre, which made the up
// arrow look low and the down arrow look high inside the circular icon.
Item {
    id: arrow

    property bool up: true
    property color color: "white"
    property real arrowWidth: 7
    property real arrowHeight: 8

    implicitWidth: arrowWidth
    // The triangle takes three quarters of the item; the centroid is then exactly at
    // half the item height for both directions.
    implicitHeight: arrowHeight * 4 / 3

    onColorChanged: canvas.requestPaint()
    onUpChanged: canvas.requestPaint()
    onArrowWidthChanged: canvas.requestPaint()
    onArrowHeightChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = arrow.color;
            ctx.beginPath();
            var w = arrow.arrowWidth;
            var h = arrow.arrowHeight;
            // Up: bbox at the top (0..h), centroid at 2h/3 = item centre.
            // Down: bbox at the bottom (H-h..H), centroid at H-h + h/3 = item centre.
            var top = arrow.up ? 0 : arrow.height - h;
            if (arrow.up) {
                ctx.moveTo(w / 2, top);
                ctx.lineTo(w, top + h);
                ctx.lineTo(0, top + h);
            } else {
                ctx.moveTo(0, top);
                ctx.lineTo(w, top);
                ctx.lineTo(w / 2, top + h);
            }
            ctx.closePath();
            ctx.fill();
        }
    }
}
