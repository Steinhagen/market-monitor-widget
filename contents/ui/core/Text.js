.pragma library
// Text helpers shared by the views. The tooltip and the watchlist build rich-text
// labels, so values coming from a feed (and translated captions) are escaped before
// they are embedded in HTML.

function escapeHtml(value) {
    return String(value === undefined || value === null ? "" : value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}

// A plain-text copy for controls that always parse rich text and expose no
// textFormat (Qt Quick Controls' ToolTip.text). Removing the angle brackets keeps a
// feed value from opening a tag; entities such as "&lt;" stay inert text.
function plainText(value) {
    return String(value === undefined || value === null ? "" : value)
        .replace(/[<>]/g, "");
}
