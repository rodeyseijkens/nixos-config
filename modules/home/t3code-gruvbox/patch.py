#!/usr/bin/env python3
"""Give T3 Code Gruvbox syntax and diff accents.

T3 Code hardcodes syntax highlighting to the Pierre palettes
(`pierre-dark` / `pierre-light` -> `t3-light`) instead of following the
selected app theme. The app already bundles the Zed Gruvbox themes, so we
swap the Pierre theme payloads for their Gruvbox counterparts and align the
diff accents with Codey's Gruvbox colors.

Everything is rewritten in place and padded to its original size, so asar
offsets stay valid. Integrity hashes are recomputed for changed files.
"""
import hashlib
import json
import os
import re
import struct
import sys

TARGET_DARK = "gruvbox-dark-hard"
TARGET_LIGHT = "gruvbox-light-medium"

THEME_SWAPS = {
    "pierre-dark": TARGET_DARK,
    "pierre-light": TARGET_LIGHT,
}

# Codey's Gruvbox diff accents (src/ui/theme/codey.ts).
DIFF_BG = {
    "addition-override": "light-dark(#e2e8c2, #2d4a2d)",
    "addition-number-override": "light-dark(#dbe3bb, #345234)",
    "addition-hover-override": "light-dark(#d9e0b3, #365a36)",
    "addition-emphasis-override": "light-dark(#d3dca8, #3b613b)",
    "deletion-override": "light-dark(#f9d8d4, #4a2d2d)",
    "deletion-number-override": "light-dark(#f3c7c1, #543030)",
    "deletion-hover-override": "light-dark(#f5cfca, #523131)",
    "deletion-emphasis-override": "light-dark(#efc0ba, #5a3333)",
}

DIFF_TEXT_OLD = (
    "--diff-addition:var(--success);"
    "--diff-deletion:var(--destructive);"
    "--diff-addition-foreground:var(--lightningcss-light,var(--color-emerald-700))"
    "var(--lightningcss-dark,var(--color-emerald-400));"
    "--diff-deletion-foreground:var(--lightningcss-light,var(--color-red-700))"
    "var(--lightningcss-dark,var(--color-red-400))}"
)
DIFF_TEXT_NEW = (
    "--diff-addition:light-dark(#79740e,#b8bb26);"
    "--diff-deletion:light-dark(#9d0006,#fb4934);"
    "--diff-addition-foreground:var(--diff-addition);"
    "--diff-deletion-foreground:var(--diff-deletion)}"
)


def read_archive(path):
    with open(path, "rb") as handle:
        head = handle.read(16)
        magic, header_size, payload_size, json_size = struct.unpack("<IIII", head)
        if magic != 4:
            raise SystemExit(f"unexpected asar header magic: {magic}")
        header_bytes = handle.read(json_size)
        base = 8 + header_size
    return json.loads(header_bytes.decode("utf-8")), header_bytes, base, payload_size


def iter_files(node, prefix=""):
    for name, entry in node.get("files", {}).items():
        path = f"{prefix}/{name}"
        if "files" in entry:
            yield from iter_files(entry, path)
        else:
            yield path, entry


def read_entry(handle, base, entry):
    handle.seek(base + int(entry["offset"]))
    return handle.read(entry["size"])


def theme_catalog(handle, base, header):
    """Collect the bundled theme chunks, classified as textmate or zed."""
    catalog = {"textmate": [], "zed": []}
    for path, entry in iter_files(header):
        if not path.endswith(".js") or entry.get("unpacked"):
            continue
        if entry["size"] > 200_000:
            continue
        text = read_entry(handle, base, entry).decode("utf-8", "replace")
        if "Object.freeze(JSON.parse(`" in text:
            catalog["textmate"].append((path, entry, text))
        elif re.search(r"name\s*:\s*`[^`]+`.*style\s*:", text, re.S):
            catalog["zed"].append((path, entry, text))
    return catalog


def find_theme(catalog, kind, theme_id):
    """Find a theme chunk whose hashed filename starts with the theme id."""
    for path, entry, text in catalog[kind]:
        stem = path.rsplit("/", 1)[-1][:-3]
        if stem.startswith(theme_id + "-"):
            return path, entry, text
    return None


def patch_theme_text(text, kind, gruvbox_id, target_id):
    if kind == "textmate":
        pattern = re.compile(rf'"name"\s*:\s*"{re.escape(gruvbox_id)}"')
        new = f'"name":"{target_id}"'
        text, count = pattern.subn(new, text, count=1)
        if count != 1:
            raise SystemExit(f"missing TextMate name {gruvbox_id!r}")
        return text
    match = re.search(r"name\s*:\s*`([^`]+)`", text)
    if not match:
        raise SystemExit(f"cannot find Zed theme name in {gruvbox_id}")
    return text.replace(f"name:`{match.group(1)}`", f"name:`{target_id}`", 1)


def patch_diff_js(text):
    changed = False
    for key, value in DIFF_BG.items():
        pattern = re.compile(rf"--diffs-bg-{re.escape(key)}\s*:[^;]*;")
        replacement = f"--diffs-bg-{key}: {value};"
        text, count = pattern.subn(replacement, text, count=1)
        changed = changed or count == 1
    return text, changed


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch.py path/to/app.asar")
    archive = sys.argv[1]
    header, original_header, base, payload_size = read_archive(archive)

    with open(archive, "r+b") as handle:
        catalog = theme_catalog(handle, base, header)
        updates = {}

        for target_id, gruvbox_id in THEME_SWAPS.items():
            for kind in ("textmate", "zed"):
                target = find_theme(catalog, kind, target_id)
                source = find_theme(catalog, kind, gruvbox_id)
                if target is None or source is None:
                    raise SystemExit(
                        f"missing {kind} theme pair for {target_id} / {gruvbox_id}"
                    )
                target_path, target_entry, _ = target
                _, _, source_text = source
                updates[target_path] = (
                    target_entry,
                    patch_theme_text(source_text, kind, gruvbox_id, target_id),
                )

        patched_diff = False
        patched_text = False
        for path, entry in iter_files(header):
            if not path.endswith((".js", ".css")) or entry.get("unpacked"):
                continue
            text = read_entry(handle, base, entry).decode("utf-8")
            patched = text
            if "--diffs-bg-addition-override" in text:
                patched, changed = patch_diff_js(text)
                patched_diff = patched_diff or changed
            if DIFF_TEXT_OLD in text:
                patched = patched.replace(DIFF_TEXT_OLD, DIFF_TEXT_NEW, 1)
                patched_text = True
            if patched != text:
                updates[path] = (entry, patched)

        if not patched_diff:
            raise SystemExit("missing diff background overrides in diff renderer")
        if not patched_text:
            raise SystemExit("missing diff accent variables in stylesheet")

        for path, (entry, text) in updates.items():
            encoded = text.encode("utf-8")
            size = entry["size"]
            if len(encoded) > size:
                raise SystemExit(f"{path}: {len(encoded)} bytes exceeds original {size}")
            encoded += b" " * (size - len(encoded))
            digest = hashlib.sha256(encoded).hexdigest()
            integrity = entry.get("integrity")
            if integrity is None or integrity.get("algorithm", "").upper() != "SHA256":
                raise SystemExit(f"{path}: unsupported integrity {integrity!r}")
            block_size = int(integrity.get("blockSize", 4 * 1024 * 1024))
            integrity["hash"] = digest
            integrity["blocks"] = [
                hashlib.sha256(encoded[offset : offset + block_size]).hexdigest()
                for offset in range(0, len(encoded), block_size)
            ]
            handle.seek(base + int(entry["offset"]))
            handle.write(encoded)

    new_header = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    if len(new_header) != len(original_header):
        raise SystemExit(
            f"refusing to rewrite asar header: {len(new_header)} != {len(original_header)} bytes"
        )
    with open(archive, "r+b") as handle:
        handle.seek(16)
        handle.write(new_header)

    print(f"patched {len(updates)} files in {archive}")


if __name__ == "__main__":
    main()
