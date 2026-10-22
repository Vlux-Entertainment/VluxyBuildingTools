---
sidebar_position: 9
---

# Teams

VluxyBuildingTools works in Team Create. Everyone can build in the same working folder, and the
team sees the same colors and grid.

## The admin

Studio sends every change to a part to the whole team, so the things everyone sees can only be
decided by one person. Each working folder has one **admin**.

- The admin is whoever has had the plugin open on the folder the longest. Someone working alone is
  always the admin.
- When the admin closes the plugin, changes folder or stops answering for about 45 seconds, admin
  passes to the next person who has been there longest.
- The Working Folder card's title line shows a face for everyone in the folder. The admin's has a
  ring; hover a face to see the name.
- The admin can click someone's face and pick **Give admin**. Anyone else can click a face and pick
  **Request admin**; the admin then sees the request on the card and picks **Give** or **Ignore**.
  A request runs out after a minute.

Only the admin can change these. For everyone else the controls are greyed, hovering them names the
admin, and their hotkeys and toolbar buttons only say so in the status line:

| What | Where |
|---|---|
| Themes on or off, and which theme | Display tab, the toolbar, P, hold P and scroll |
| Surface grid on or off, tile size and color | Display tab, the toolbar, L |
| Ghost transparency | Display tab |
| Hiding parts and Unhide all | H, Alt+H, Display tab |
| Whose settings a folder keeps (Use folder's or Overwrite) | Working Folder card |

Everyone keeps every build tool, Arrange, Props, the camera light, the ghost view (I), their own
Settings tab and hint bar.

Who is in a folder is kept in attributes on the folder: `VluxyBT_Here_<userId>` (the last
heartbeat, every 15 seconds), `VluxyBT_Joined_<userId>`, `VluxyBT_Admin` and
`VluxyBT_AdminRequest`. They are cleared when you leave and are not undo steps.

## Shared through the folder

These settings are saved as attributes on the working folder, so everyone working in it shares them:

| Setting | Where the admin sets it |
|---|---|
| The theme | Display tab, or hold P and scroll |
| Ghost transparency | Display tab, Hidden parts card |
| Themes on or off | Display tab, P, or the toolbar |
| Surface grid on or off | Display tab, L, or the toolbar |
| Grid tile size and grid color | Display tab |

When the admin changes one, it is written to the folder and everyone takes it over.

When you pick a folder whose shared settings differ from yours and nobody else is working in it,
you choose **Use folder's** (take theirs), **Overwrite** (save yours onto the folder) or
**Cancel**. If teammates are already working in it, you simply take the folder's settings.

The theme colors and the surface grid are real changes to the parts, so everyone sees them. The
shared on/off switches decide whether they come back on by themselves when someone opens the plugin.
If you close the plugin while a teammate still has it open, the colors and grid stay on for them.

## Kept to yourself

| What | Why it is private |
|---|---|
| Ghost view (I) | It only changes how hidden parts look on your screen. |
| Camera light (Alt+L) | It lives under your camera and is never saved. |
| Sounds | They play in a hidden plugin window of your own, so only you hear them. |
| Tool options and the Settings tab | Saved in your own Studio settings. |

## Hidden parts are shared

When the admin hides a part (H), it gets the `VluxyBT_Hidden` tag and is locked. Tags and locks
reach the whole team, and every copy of the plugin hides tagged parts on its own screen, so the part
disappears for everyone. The tools aim through hidden parts. Undo brings a hidden part back.

## Tips

- Agree on one tagged folder for the map, so the shared settings stay in one place.
- Switch themes and the grid off before anyone publishes. They are saved with the place.
