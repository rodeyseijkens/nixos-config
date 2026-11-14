#!/usr/bin/env python3
"""Screenshot and colour check for the Aarambh QEMU harness.

  screen.py dump <monitor-socket> <out.png>   ask QEMU for a screenshot
  screen.py check <image.png>                  check the Gruvbox theme colours

check exits 0 when the paper colour fills a large part of the screen and the
accent colour shows up, which is how the editorial-gruvbox theme looks. The
Editorial Dark theme (#15130f paper) fails the check.
"""

import socket
import subprocess
import sys

PAPER = (0x3C, 0x38, 0x36)  # base01
ACCENT = (0x98, 0x97, 0x1A)  # base0D
TOLERANCE = 12
STEP = 3  # sample every third pixel in each direction

PROMPT = b"(qemu) "


def dump(socket_path, out):
    monitor = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    monitor.settimeout(10)
    monitor.connect(socket_path)

    def read_prompt():
        data = b""
        while not data.endswith(PROMPT):
            chunk = monitor.recv(4096)
            if not chunk:
                break
            data += chunk
        return data

    read_prompt()
    # QEMU writes the file named here. The monitor reads paths in its own
    # working directory, so the harness passes absolute paths.
    monitor.sendall(f"screendump {out}\n".encode())
    read_prompt()
    monitor.close()


def pixels(image):
    size = subprocess.run(
        ["identify", "-format", "%w %h", image],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    width, height = int(size[0]), int(size[1])
    raw = subprocess.run(
        ["convert", image, "-depth", "8", "rgb:-"],
        check=True,
        capture_output=True,
    ).stdout
    return width, height, raw


def near(pixel, target):
    return all(abs(a - b) <= TOLERANCE for a, b in zip(pixel, target))


def check(image):
    width, height, raw = pixels(image)
    sampled = 0
    paper = 0
    accent = 0
    for y in range(0, height, STEP):
        row = y * width * 3
        for x in range(0, width, STEP):
            i = row + x * 3
            pixel = (raw[i], raw[i + 1], raw[i + 2])
            sampled += 1
            if near(pixel, PAPER):
                paper += 1
            elif near(pixel, ACCENT):
                accent += 1

    paper_share = paper / sampled
    print(f"paper {paper_share:.1%} of the screen, accent pixels {accent}")
    if paper_share >= 0.20 and accent >= 20:
        print("theme: editorial-gruvbox colours found")
        return 0
    print("theme: editorial-gruvbox colours NOT found")
    return 1


def main(argv):
    if len(argv) == 4 and argv[1] == "dump":
        dump(argv[2], argv[3])
        return 0
    if len(argv) == 3 and argv[1] == "check":
        return check(argv[2])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
