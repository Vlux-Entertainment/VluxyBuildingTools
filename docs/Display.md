---
sidebar_position: 6
---

# Display

The **Display** tab changes how the map looks while you build. It has two cards: **View** and
**Hidden parts**.

:::caution
Theme colors and the surface grid are saved with the place. Switch them off before you publish.
Turning them off puts every part's original color back.
:::

## Themes

Turn on **Themes** (or press **P**) to color the parts in your working folder. Pick a theme from the
six buttons, or hold **P** and scroll to switch.

| Theme | What it colors by |
|---|---|
| **Pastel** | A random soft color for every part. |
| **Unity** | What the part is: walls grey; floors, ceilings and stairs orange. |
| **Levels** | Building level: one color per floor of the building, from the ground up. |
| **Structures** | One bold color per room, corridor or model. |
| **Facing** | Direction, so crooked parts stand out. |
| **Size** | Size, from yellow (small) to violet (big). |

In every theme, a part that is partly see-through is purple.

The **Facing** colors:

| Color | Part |
|---|---|
| Blue | Runs along X |
| Green | Runs along Z |
| Orange | Diagonal |
| Tan | Flat |
| Grey | Square, with no clear direction |
| Magenta | Tilted off level |

The **Size** colors go yellow (under 1 stud), green (under 4), teal (under 12), blue (under 32),
then violet for anything bigger.

New parts the plugin builds take the theme color straight away, in the same undo step.

## Surface grid

Turn on **Surface grid** (or press **L**) to put a grid texture on every part in the working folder.

- **Grid tile size** sets how many studs one tile covers.
- Pick a grid color from the swatches, or type a hex code such as `FF8A24`.

The grid stays on, even after you close and reopen Studio, until you switch it off.

## Camera light

**Camera light** (or **Alt+L**) adds a light that follows your camera, for building in dark places.
Set its **Light range** and **Light brightness**. The light is never saved into the place, and only
you see it.

## Hidden parts

Select parts and press **H** to hide them. Only you see this: hiding never changes the place and
never reaches teammates.

| Control | What it does |
|---|---|
| **Show hidden parts (ghosted)** (or **I**) | Show hidden parts as faint ghosts instead of not at all. |
| **Ghost transparency** | How see-through the ghosts are. |
| **Unhide all** (or **Alt+H**) | Bring back every part you hid. |

The card also counts how many parts are hidden.
