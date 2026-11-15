import QtQuick
import org.kde.plasma.plasma5support 2.0

// Small wrapper around the Plasma5Support "executable" data engine. It is loaded
// through a Loader so the Import / Export page still opens (with an explanation) on
// systems where that compatibility module is not installed.
//
// A write is sent in chunked shell calls: one `write-start`, one `write-chunk` per
// 64 KiB of base64, then `write-end`. The kernel rejects a single argv above
// ~128 KiB, so the whole backup in one command would fail for a large portfolio.
Item {
    id: root

    // True while a file is being read or written. The page disables its buttons so
    // two requests cannot overlap.
    property bool busy: false

    // The current step ("read", "write-start", "write-chunk", "write-end"), used to
    // report a useful error.
    property string operation: ""

    // The command that is currently running, so a stale timeout cannot clear a newer
    // request.
    property string pendingSource: ""

    // Every helper command gets a unique trailing shell comment (see shellCommand).
    property int commandSerial: 0

    // Write state. `writeTemp` is the helper's temporary file; it lives in a private
    // directory next to the target until `write-end` renames it into place.
    property string writeTarget: ""
    property string writeTemp: ""
    property string writeData: ""
    property int writeOffset: 0

    // Base64 chunks must be a multiple of 4 characters so each one decodes on its
    // own; 64 KiB also stays far below the per-argument limit.
    readonly property int writeChunkSize: 65536
    // The reader caps a file at MAX_READ in backup-io.sh. Refuse to create a backup
    // larger than that, so every export can be imported again.
    readonly property int maxBytes: 8388608

    signal readFinished(string text)
    signal writeFinished()
    signal failed(string operationName, string detail)

    DataSource {
        id: executor
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            if (!root.busy || source !== root.pendingSource) return;

            const doneOperation = root.operation;
            const exitCode = Number(data["exit code"]);
            const stdout = data["stdout"] !== undefined ? String(data["stdout"]) : "";
            const stderr = data["stderr"] !== undefined ? String(data["stderr"]) : "";

            executor.disconnectSource(source);

            if (!isFinite(exitCode) || exitCode !== 0) {
                root.abortWrite();
                root.finish();
                root.failed(doneOperation, stderr.trim());
                return;
            }

            switch (doneOperation) {
            case "read":
                root.finish();
                root.readFinished(stdout);
                break;
            case "write":
                root.finish();
                root.writeFinished();
                break;
            case "write-start":
                if (stdout === "") {
                    root.finish();
                    root.failed(doneOperation, "could not create the temporary file");
                    return;
                }
                root.writeTemp = stdout;
                root.sendWriteChunk();
                break;
            case "write-chunk":
                root.sendWriteChunk();
                break;
            case "write-end":
                root.finish();
                root.writeFinished();
                break;
            default:
                root.finish();
                root.failed(doneOperation, "");
                break;
            }
        }
    }

    Timer {
        id: timeoutTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (!root.busy) return;
            const timedOutOperation = root.operation;
            const source = root.pendingSource;
            if (source !== "") executor.disconnectSource(source);
            root.abortWrite();
            root.finish();
            root.failed(timedOutOperation, "timeout");
        }
    }

    function finish() {
        root.busy = false;
        root.operation = "";
        root.pendingSource = "";
        root.writeTarget = "";
        root.writeTemp = "";
        root.writeData = "";
        root.writeOffset = 0;
        timeoutTimer.stop();
    }

    // Removes the temporary file (and its private directory) after a failed or
    // timed-out write. The call is fire-and-forget; its reply is ignored because the
    // request state has already been reset.
    function abortWrite() {
        if (root.writeTemp === "") return;
        const temp = quoteArgument(root.writeTemp);
        root.writeTemp = "";
        executor.connectSource(shellCommand("write-abort " + temp));
    }

    // Quotes one argument for the shell-like parser used by the executable engine.
    // The quote character is built with fromCharCode so xgettext does not mistake the
    // JavaScript string for an unterminated C character constant.
    function quoteArgument(value) {
        const quote = String.fromCharCode(39);
        const escapedQuote = quote + "\\" + quote + quote;
        return quote + String(value).split(quote).join(escapedQuote) + quote;
    }

    function localPath(url) {
        var path = String(url);
        if (path.indexOf("file://") === 0) path = path.substring(7);
        try {
            return decodeURIComponent(path);
        } catch (e) {
            // A literal "%" that is not a valid escape: keep the path as it is.
            return path;
        }
    }

    function helperPath() {
        return localPath(Qt.resolvedUrl("../../../code/backup-io.sh"));
    }

    // Builds one shell command for the helper. The trailing comment makes the source
    // string unique: the executable engine keys sources by their command, so an
    // identical command (the same file read twice, two identical chunks) could be
    // ignored. The helper quotes every argument, so the comment is inert.
    function shellCommand(body) {
        root.commandSerial++;
        return "sh " + quoteArgument(helperPath()) + " " + body + " # " + root.commandSerial;
    }

    // Starts a new request. The page already blocks a second request, so this only
    // guards against a programmatic one.
    function begin(operationName, command) {
        if (root.busy) return false;
        root.busy = true;
        root.operation = operationName;
        root.pendingSource = command;
        timeoutTimer.restart();
        executor.connectSource(command);
        return true;
    }

    // Advances a multi-step write. `busy` stays set until write-end or an error.
    function step(operationName, command) {
        root.operation = operationName;
        root.pendingSource = command;
        timeoutTimer.restart();
        executor.connectSource(command);
    }

    function readFile(url) {
        const path = quoteArgument(localPath(url));
        begin("read", shellCommand("read " + path));
    }

    function writeFile(url, text) {
        if (root.busy) return;
        // Qt.btoa() encodes the string as UTF-8, which is exactly what the JSON file
        // needs. (The usual JavaScript btoa(unescape(encodeURIComponent(...))) dance
        // would encode it twice here.)
        const encoded = Qt.btoa(text);
        // Base64 is 4 characters per 3 bytes; subtract the padding to get the exact
        // UTF-8 size the reader will see.
        var padding = 0;
        if (encoded.charAt(encoded.length - 1) === "=") padding++;
        if (encoded.charAt(encoded.length - 2) === "=") padding++;
        if (encoded.length * 3 / 4 - padding > root.maxBytes) {
            root.failed("write", "backup is too large (limit " + root.maxBytes + " bytes)");
            return;
        }
        root.writeData = encoded;
        root.writeTarget = localPath(url);
        root.writeOffset = 0;
        root.writeTemp = "";
        begin("write-start", shellCommand("write-start " + quoteArgument(root.writeTarget)));
    }

    // Sends the next 64 KiB chunk, or finishes the write when the payload is used up.
    function sendWriteChunk() {
        const data = root.writeData;
        if (root.writeOffset >= data.length) {
            step("write-end", shellCommand("write-end "
                 + quoteArgument(root.writeTemp) + " " + quoteArgument(root.writeTarget)));
            return;
        }
        const end = Math.min(data.length, root.writeOffset + root.writeChunkSize);
        const chunk = data.substring(root.writeOffset, end);
        root.writeOffset = end;
        step("write-chunk", shellCommand("write-chunk "
             + quoteArgument(root.writeTemp) + " " + quoteArgument(chunk)));
    }
}
