---
sidebar_position: 3
---

# Getting started

This walks you from an empty place to a room with a door. Open the panel with the
**VluxyBuildingTools** toolbar button first.

## 1. Make a working folder

The plugin only builds and edits inside one **working folder**. Nothing outside it is touched.

1. Make a `Folder` in `Workspace`, for example `Map`.
2. Tag it: select the folder, open **View > Tag Editor** and add the tag `VluxyBT_Map`.

The tag is a safety catch, so the plugin can't change a folder by mistake. You can switch it off with
**Allow untagged folders** in [Settings](Settings#advanced), but that is not recommended.

## 2. Pick the folder

1. In the **Working Folder** card at the top of the panel, click **Choose working folder**.
2. Click any part inside the folder in the viewport, or select the folder in the Explorer.
   The folder gets an outline and the panel asks **Work in this folder?**
3. Click **Yes**. Click **Cancel** (or press Esc) to back out.

If the folder already holds shared settings from a teammate that differ from yours, the panel names
them and offers three buttons:

| Button | What happens |
|---|---|
| **Use folder's** | You take the settings saved on the folder. |
| **Overwrite** | Your settings are saved onto the folder. |
| **Cancel** | You keep your current working folder. |

See [Teams](Teams) for which settings are shared. Next time you open the place, the plugin offers the
folder you last worked in.

## 3. Draw a wall

1. Press **Ctrl+1** (or click the **Basic** tile) and pick **Walls**.
2. Click a start point on the ground, then click an end point. The wall is built.
3. Keep clicking to add more walls to the chain. Press **Enter** to start a new chain.

While drawing:

- Hold **Shift** to snap to the fine grid.
- Press **X** or **Z** to lock to an axis. Press it again to unlock.
- Type a number, such as `16`, for an exact length.
- Press **Y** to drag the height with the mouse, or use **[** and **]**.

## 4. Draw a room

1. Press **Ctrl+4** (**Structures**) and pick **Room**.
2. Click two opposite corners. You get a floor and four walls.

Rooms drawn against each other join up. The **Open**, **Shared** and **Separate** buttons choose
whether the rooms share no wall, one wall, or keep both.

## 5. Add a door

1. Press **Ctrl+3** (**Additive**) and pick **Doorway**.
2. Click a plain wall. The doorway is centred on the cursor.
3. Move the mouse to set how deep the cut goes, then click. Past the far side, it cuts all the way
   through. (Turn off **Set cut depth with mouse** to cut through in one click.)

By default you get a doorway with a frame and a see-through door panel.

## 6. Undo and stop

- **Ctrl+Z** undoes a build. Every build is one undo step.
- **Esc** or a right-click drops the point you are drawing from. Press it again to stop the tool.
- Pressing a tool's Ctrl+number again also stops it. **Enter** with no tool on brings back the last one.

The status line in the panel always says what to do next. Next: [Tools](Tools).
