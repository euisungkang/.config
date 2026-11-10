#!/usr/bin/env python3
"""Toggle "show desktop" for the focused workspace only.

Stash: every window on the focused monitor's active workspace is moved to the
hidden special:desktop workspace and its geometry is saved.
Restore: windows return to the same workspace and the dwindle tiling tree is
rebuilt from the saved geometry (guillotine partition + preselect), so the
original layout is reproduced instead of the order windows happen to come back.
special:special (the scratchpad) is never touched.
"""
import json
import os
import subprocess
import sys
import time


def hc(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True, check=True).stdout


def hj(what):
    return json.loads(hc("-j", what))


def batch(cmds):
    if cmds:
        hc("--batch", ";".join(cmds))


def center(rect):
    return rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2


def find_split(wins):
    """Best guillotine cut of a set of tiled windows -> (direction, A, B) or None.
    Prefers the cut nearest the middle of the bounding box (dwindle's 0.5 default)."""
    best = None
    x0 = min(w["x"] for w in wins); x1 = max(w["x"] + w["w"] for w in wins)
    y0 = min(w["y"] for w in wins); y1 = max(w["y"] + w["h"] for w in wins)
    for direction, pos, size, lo, hi in (("r", "x", "w", x0, x1), ("d", "y", "h", y0, y1)):
        ordered = sorted(wins, key=lambda w: w[pos])
        reach = None
        for i in range(len(ordered) - 1):
            end = ordered[i][pos] + ordered[i][size]
            reach = end if reach is None else max(reach, end)
            if reach <= ordered[i + 1][pos]:  # nothing crosses this line
                score = abs(reach - (lo + hi) / 2) / max(hi - lo, 1)
                if best is None or score < best[0]:
                    best = (score, direction, ordered[: i + 1], ordered[i + 1:])
    return best[1:] if best else None


def rep(wins):
    return min(wins, key=lambda w: (w["y"], w["x"]))


def place(wins, cmds):
    """Insert windows so the dwindle tree matches; rep(wins) is already placed."""
    if len(wins) < 2:
        return
    split = find_split(wins)
    if split is None:  # overlapping/unsplittable: fall back to plain insertion
        for w in wins:
            if w is not rep(wins):
                cmds.append(("move", w))
        return
    direction, a, b = split
    if rep(a) is not rep(wins):
        a, b = b, a
    cmds.append(("insert", rep(a), direction, rep(b)))
    place(a, cmds)
    place(b, cmds)


def stash(ws, state):
    clients = [c for c in hj("clients") if c["mapped"] and c["workspace"]["id"] == ws]
    if not clients:
        return
    saved = [
        {"address": c["address"], "x": c["at"][0], "y": c["at"][1], "w": c["size"][0],
         "h": c["size"][1], "floating": c["floating"], "focus": c["focusHistoryID"]}
        for c in clients
    ]
    with open(state, "w") as f:
        json.dump(saved, f)
    batch([f"dispatch movetoworkspacesilent special:desktop,address:{c['address']}" for c in clients])


def restore(ws, state):
    with open(state) as f:
        saved = json.load(f)
    os.remove(state)
    alive = {c["address"] for c in hj("clients")}
    saved = [w for w in saved if w["address"] in alive]
    if not saved:
        return
    tiled = [w for w in saved if not w["floating"]]
    float_ = [w for w in saved if w["floating"]]

    def to_ws(w):
        return f"dispatch movetoworkspacesilent {ws},address:{w['address']}"

    if tiled:
        root = rep(tiled)
        batch([to_ws(root)])
        steps = []
        place(tiled, steps)
        for step in steps:
            if step[0] == "insert":
                _, anchor, direction, new = step
                batch([f"dispatch focuswindow address:{anchor['address']}",
                       f"dispatch layoutmsg preselect {direction}", to_ws(new)])
            else:
                batch([to_ws(step[1])])
    # restore the saved split ratios (a couple of passes since resizes interact)
    for _ in range(2):
        batch([f"dispatch resizewindowpixel exact {w['w']} {w['h']},address:{w['address']}" for w in tiled])
    # clients may still be mid-configure after leaving the hidden workspace; once they settle,
    # force a real size change so they re-commit a buffer (else part of the window renders transparent)
    time.sleep(0.15)
    batch([f"dispatch resizewindowpixel exact {w['w'] + 1} {w['h']},address:{w['address']}" for w in tiled])
    batch([f"dispatch resizewindowpixel exact {w['w']} {w['h']},address:{w['address']}" for w in tiled])
    batch([to_ws(w) for w in float_])
    # put back the exact floating geometry and the original focus
    batch([f"dispatch resizewindowpixel exact {w['w']} {w['h']},address:{w['address']}" for w in float_]
          + [f"dispatch movewindowpixel exact {w['x']} {w['y']},address:{w['address']}" for w in float_])
    last = min(saved, key=lambda w: w["focus"])
    batch([f"dispatch focuswindow address:{last['address']}"])


def main():
    mon = next(m for m in hj("monitors") if m["focused"])
    ws = mon["activeWorkspace"]["id"]
    state = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), f"hypr-show-desktop-{ws}.json")
    if os.path.exists(state):
        restore(ws, state)
    else:
        stash(ws, state)


if __name__ == "__main__":
    sys.exit(main())
