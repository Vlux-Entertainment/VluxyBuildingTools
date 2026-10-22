---
sidebar_position: 2
---

# Installation

VluxyBuildingTools is a local Studio plugin. You can install a built plugin file, or run it live
from the source with Rojo.

## The toolchain

Both ways need the repository and its tools. The tool versions are pinned in `rokit.toml`.

```sh
git clone https://github.com/Vlux-Entertainment/VluxyBuildingTools
cd VluxyBuildingTools
rokit install
npm run packages:refresh
```

| Command | What it does |
|---|---|
| `rokit install` | Installs Rojo, Wally, Lune and the other pinned tools. |
| `npm run packages:refresh` | Installs the Wally packages and writes their types. |

You need [Rokit](https://github.com/rojo-rbx/rokit) and [Node.js](https://nodejs.org/) for these.

## From the built file

```sh
npm run plugin:build
```

This builds `VluxyBuildingTools.rbxm` with Rojo's `--plugin` option, which puts it straight into
Studio's local Plugins folder. Restart Studio, or reopen your place, and the
**VluxyBuildingTools** toolbar shows up in the Plugins tab.

If someone gives you the `VluxyBuildingTools.rbxm` file instead, open Studio, go to the
**Plugins** tab, click **Plugins Folder** and drop the file in.

## From source with Rojo

Use this when you want your code changes to show up in Studio while you work.

1. Run `rojo serve default.project.json`.
2. In Studio, connect with the Rojo plugin. The source appears as a `VluxyBuildingTools` folder in
   `ServerStorage`.
3. Right-click that folder in the Explorer and choose **Save as Local Plugin**.

Save it as a local plugin again after each change you want to try.

:::note
`default.project.json` only serves to the project's own place (`servePlaceIds`). To use another
place, change or remove that line.
:::

## The toolbar

Once installed, the **VluxyBuildingTools** toolbar has three buttons:

| Button | What it does |
|---|---|
| **VluxyBuildingTools** | Opens or closes the panel. |
| **Themes** | Turns theme colors on or off (same as P). |
| **Grid** | Turns the surface grid on or off (same as L). |

Next: [Getting started](GettingStarted).
