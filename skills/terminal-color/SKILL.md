---
description: Change the current macOS Terminal.app window's background color so you can visually distinguish terminals working on different repos / branches / topics. Usage: /terminal-color <color>. Supported names: red, orange, yellow, green, blue, purple, pink, gray, dark, light, reset. Also accepts hex codes like #FF5733.
---

# /terminal-color — Change Terminal Background Color

Run an AppleScript command to change the current Terminal.app window's background color. Useful for color-coding terminals so you can tell at a glance which one is working on which repo.

## Usage

```
/terminal-color <color>
```

Examples:
- `/terminal-color red` — dim red background (good for kindra / backend work)
- `/terminal-color blue` — dim blue background (good for kinlia-web / frontend)
- `/terminal-color green` — dim green background (good for kindraapp / mobile)
- `/terminal-color reset` — restore the default profile background

Custom hex code is also accepted: `/terminal-color #2a4a6b`.

## When to use this

Manual invocation only — when the user types `/terminal-color <color>` in their CURRENT message. Do NOT auto-change colors based on cwd or branch; the user decides.

## Implementation

When invoked, parse the color name (or hex) and run an AppleScript command to set the front window's background.

### Color lookup table (dim, readable backgrounds)

| Name | RGB (0–65535) | Hex |
|---|---|---|
| red | 16000, 4000, 4000 | dim red |
| orange | 16000, 8500, 3000 | dim orange |
| yellow | 14000, 12000, 3000 | dim yellow |
| green | 4000, 14000, 5000 | dim green |
| blue | 4000, 7000, 16000 | dim blue |
| purple | 11000, 4000, 14000 | dim purple |
| pink | 18000, 7000, 11000 | dim pink |
| gray | 9000, 9000, 9000 | neutral gray |
| dark | 2000, 2000, 2000 | near-black |
| light | 60000, 60000, 60000 | near-white |

For "reset," restore the default profile background by re-applying the user's default Terminal profile.

### Steps

1. **Confirm explicit invocation.** The user must have typed `/terminal-color <color>` in their CURRENT message. Do NOT change terminal colors based on "continue" or any ambiguous prior approval.

2. **Parse the color argument.**
   - If it matches one of the named colors above, look up the RGB.
   - If it's a hex code like `#RRGGBB`, parse the 3 hex bytes and convert each from 0–255 to 0–65535 by multiplying by 257 (which is `65535/255`).
   - If it's `reset`, run the reset command instead.

3. **Run the AppleScript command** via Bash:

   ```bash
   osascript -e 'tell application "Terminal" to set background color of front window to {R, G, B}'
   ```

   For reset:
   ```bash
   osascript -e 'tell application "Terminal" to set current settings of front window to default settings'
   ```

4. **Report success** to the user with one short line: `Terminal background set to <color>.` Don't be verbose.

5. **If the user is NOT on Terminal.app** (e.g., iTerm2, Warp, VS Code terminal), check `$TERM_PROGRAM`. For now, only Terminal.app is supported — for other terminals, tell the user: `This skill only supports macOS Terminal.app. You're using [$TERM_PROGRAM]. Tell me what terminal you'd like to support and I can extend it.`

## Rules

- **NEVER change the terminal color without explicit `/terminal-color <color>` invocation in the user's current message.** No auto-coloring.
- **Don't be verbose in the success report.** One line is enough.
- **Don't try to "improve" the color choice.** If the user types `/terminal-color red`, use red — don't override to "a more readable maroon" or similar.
- **Only modify the FRONT window.** Don't try to color all windows or all tabs.
