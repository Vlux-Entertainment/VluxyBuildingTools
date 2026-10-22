---
sidebar_position: 7
---

# Arrange

The **Arrange** tab works on the current selection. Select Parts or Models inside the working
folder first. Each action is one undo step.

## Flip

**Flip X**, **Flip Y** and **Flip Z** mirror the selection across that axis, around the selection's
centre. The hotkey is **Ctrl+M**, then **X**, **Y** or **Z**.

## Array

The Array makes a row of copies, like Blender's Array modifier.

1. Select what you want to copy.
2. Set **Count**: how many objects in total, the original included (up to 50).
3. Choose the spacing with one or both offsets (below).
4. Watch the preview. While the Arrange tab is open, boxes show where the copies will go.
5. Click **Apply Array** to make them. Ctrl+Z undoes the whole array.

| Offset | Fields | Spacing |
|---|---|---|
| **Relative Offset** | **Factor X**, **Y**, **Z** | In multiples of the selection's own size. `1` on X puts each copy right next to the last. |
| **Constant Offset** | **Distance X**, **Y**, **Z** | A fixed number of studs. |

With both on, the two add up. Relative Offset starts on, with Factor X at `1`.

The panel tells you when something is missing: a selection, a Count of 2 or more, or an offset.
One array can copy at most 10,000 parts, and the selected objects must have **Archivable** on.
