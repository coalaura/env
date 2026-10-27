import { execFile } from "node:child_process";
import { access, mkdtemp, rm, writeFile } from "node:fs/promises";
import { release, tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { promisify } from "node:util";
import { PasteEvent } from "@opentui/core";

const WINDOWS_SCRIPT = `
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

$image = [System.Windows.Forms.Clipboard]::GetImage()
if ($null -ne $image) {
    $stream = [System.IO.MemoryStream]::new()
    try {
        $image.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        @{ kind = 'image'; data = [Convert]::ToBase64String($stream.ToArray()) } | ConvertTo-Json -Compress
    } finally {
        $stream.Dispose()
        $image.Dispose()
    }
    return
}

$files = @([System.Windows.Forms.Clipboard]::GetFileDropList())
if ($files.Count -gt 0) {
    @{ kind = 'files'; files = [string[]]$files } | ConvertTo-Json -Compress
    return
}

@{ kind = 'text'; text = [System.Windows.Forms.Clipboard]::GetText() } | ConvertTo-Json -Compress
`;

const IMAGE_TYPES = new Map([
    ["image/png", "png"],
    ["image/jpeg", "jpg"],
    ["image/webp", "webp"],
    ["image/gif", "gif"],
]);

const execute = promisify(execFile);

const tui = async (api, options = {}) => {
    let pending;

    async function paste() {
        const target = api.renderer.currentFocusedRenderable,
            route = JSON.stringify(api.route.current);

        if (!target || (!target.onPaste && !target.handlePaste)) {
            return;
        }

        let temporaryDirectory;

        function active() {
            return (
                !api.lifecycle.signal.aborted &&
                !target.isDestroyed &&
                target === api.renderer.currentFocusedRenderable &&
                route === JSON.stringify(api.route.current)
            );
        }

        try {
            const clipboard = await readClipboard(api.lifecycle.signal);

            if (!active()) {
                return;
            }

            let values;

            if (clipboard.kind === "image") {
                temporaryDirectory = await mkdtemp(join(tmpdir(), "opencode-clipboard-"));

                const filename = join(temporaryDirectory, `clipboard.${clipboard.extension || "png"}`);

                await writeFile(filename, clipboard.data);

                values = [pathToFileURL(filename).href];
            } else if (clipboard.kind === "files") {
                values = clipboard.files.map(
                    (filename) => pathToFileURL(filename).href,
                );
            } else {
                values = [clipboard.text];
            }

            for (const text of values) {
                if (!active()) {
                    return;
                }

                if (!text) {
                    continue;
                }

                const event = new PasteEvent(Buffer.from(text, "utf8"));

                // Wait for attachments to load before deleting temporary files.
                // Whitespace bypasses OpenCode's empty-paste clipboard reread.
                if (text.trim()) {
                    await target.onPaste?.call(target, event);
                }

                if (active() && !event.defaultPrevented && !event.propagationStopped) {
                    await target.handlePaste?.(event);
                }
            }
        } catch {
            // Clipboard failures are intentionally silent.
        } finally {
            if (temporaryDirectory) {
                try {
                    await rm(temporaryDirectory, {
                        recursive: true,
                        force: true,
                    });
                } catch {
                    // Cleanup failures are intentionally silent.
                }
            }
        }
    }

    function startPaste(event) {
        const target = api.renderer.currentFocusedRenderable;

        if (!target || (!target.onPaste && !target.handlePaste)) {
            return;
        }

        event.preventDefault();
        event.stopPropagation();

        if (pending) {
            return;
        }

        pending = paste().finally(() => {
            pending = undefined;
        });

        return pending;
    }

    function onNativePaste(event) {
        // Leave normal text, copied paths, and whitespace with OpenCode.
        // An empty terminal paste triggers the system clipboard reader.
        if (event.bytes.length || event.defaultPrevented || event.propagationStopped) {
            return;
        }

        return startPaste(event);
    }

    api.renderer.keyInput.on("paste", onNativePaste);

    const bindings = [
        { key: "ctrl+shift+v", cmd: "clipboard.paste" },
        { key: "ctrl+v", cmd: "clipboard.paste" },
    ];

    if (options.debug) {
        bindings.push({ key: "f6", cmd: "clipboard.paste" });
    }

    api.keymap.registerLayer({
        priority: 100,
        commands: [
            {
                name: "clipboard.paste",
                title: "Paste from system clipboard",
                run(context) {
                    return startPaste(context.event);
                },
            },
        ],
        bindings,
    });

    api.lifecycle.onDispose(async () => {
        api.renderer.keyInput.off("paste", onNativePaste);
        await pending;
    });
};

async function readClipboard(signal) {
    const isWSL = process.platform === "linux" && (
        Boolean(process.env.WSL_INTEROP) || /microsoft/i.test(release())
    );

    if (process.platform === "win32" || isWSL) {
        const output = await runCommand(
            "powershell.exe",
            [
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-STA",
                "-Command",
                WINDOWS_SCRIPT,
            ],
            signal,
        );

        const clipboard = parseClipboard(output);

        if (isWSL && clipboard.kind === "files") {
            clipboard.files = await Promise.all(clipboard.files.map((filename) => wslPath(filename, signal)));
        }

        if (isWSL && clipboard.kind === "text") {
            const candidate = clipboard.text
                .trim()
                .replace(/^(["'])(.*)\1$/, "$2");

            if (/^(?:[a-z]:[\\/]|\\\\)/i.test(candidate)) {
                const filename = await wslPath(candidate, signal);

                const exists = await access(filename).then(
                    () => true,
                    () => false,
                );

                if (exists) {
                    clipboard.text = filename;
                }
            }
        }

        return clipboard;
    }

    if (process.platform === "linux") {
        return readLinuxClipboard(signal);
    }

    throw new Error(`Clipboard paste is not supported on ${process.platform}`);
}

function parseClipboard(output) {
    const clipboard = JSON.parse(
        output.toString("utf8").replace(/^\uFEFF/, ""),
    );

    if (clipboard.kind === "image" && typeof clipboard.data === "string") {
        return {
            kind: "image",
            extension: "png",
            data: Buffer.from(clipboard.data, "base64"),
        };
    }

    if (clipboard.kind === "files" && Array.isArray(clipboard.files) && clipboard.files.every((file) => typeof file === "string")) {
        return clipboard;
    }

    if (clipboard.kind === "text" && typeof clipboard.text === "string") {
        return clipboard;
    }

    throw new Error("Unexpected clipboard response");
}

async function readLinuxClipboard(signal) {
    const wayland = Boolean(process.env.WAYLAND_DISPLAY);

    let command = "xclip";

    if (wayland) {
        command = "wl-paste";
    }

    function argumentsFor(type) {
        if (wayland) {
            if (type) {
                return ["--no-newline", "--type", type];
            }

            return ["--list-types"];
        }

        return ["-selection", "clipboard", "-out", "-target", type || "TARGETS"];
    }

    let available;

    try {
        available = await runCommand(command, argumentsFor(), signal);
    } catch (error) {
        if (/Nothing is copied|No selection|target TARGETS not available|no owner for the .*selection/i.test(error.message)) {
            return { kind: "text", text: "" };
        }

        throw error;
    }

    const types = available.toString("utf8")
        .split(/\r?\n/)
        .map((type) => type.trim());

    function findType(wanted) {
        return types.find((type) => type.toLowerCase() === wanted.toLowerCase());
    }

    function read(type) {
        return runCommand(command, argumentsFor(type), signal);
    }

    for (const [mime, extension] of IMAGE_TYPES) {
        const type = findType(mime);

        if (type) {
            return { kind: "image", extension, data: await read(type) };
        }
    }

    const fileType = findType("x-special/gnome-copied-files") ||
        findType("text/uri-list");

    if (fileType) {
        const contents = (await read(fileType)).toString("utf8"),
            files = contents.split(/\r?\n/)
                .filter((line) => line.startsWith("file://"))
                .map((uri) => fileURLToPath(uri));

        if (files.length) {
            return { kind: "files", files };
        }
    }

    for (const wanted of [
        "text/plain;charset=utf-8",
        "UTF8_STRING",
        "text/plain",
        "STRING",
    ]) {
        const type = findType(wanted);

        if (type) {
            const contents = await read(type);
            let encoding = "utf8";

            if (type === "STRING") {
                encoding = "latin1";
            }

            return {
                kind: "text",
                text: contents.toString(encoding),
            };
        }
    }

    return { kind: "text", text: "" };
}

async function wslPath(filename, signal) {
    const output = await runCommand("wslpath", ["-u", filename], signal);

    return output.toString("utf8").replace(/\r?\n$/, "");
}

async function runCommand(command, args, signal) {
    try {
        const result = await execute(command, args, {
            encoding: "buffer",
            windowsHide: true,
            timeout: 10_000,
            maxBuffer: 64 * 1024 * 1024,
            signal,
        });

        return result.stdout;
    } catch (error) {
        if (signal.aborted) {
            throw error;
        }

        if (error.code === "ENOENT") {
            let hint = "";

            if (command === "wl-paste") {
                hint = " (provided by wl-clipboard)";
            }

            throw new Error(`Clipboard helper ${command}${hint} was not found.`);
        }

        const detail = error.stderr?.toString("utf8").trim().slice(0, 500);

        if (detail) {
            throw new Error(detail);
        }

        if (error.killed) {
            throw new Error(`${command} failed: timed out`);
        }

        throw new Error(`${command} failed: ${error.code || "clipboard unavailable"}`);
    }
}

export default { id: "clipboard", tui };