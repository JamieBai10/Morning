# Morning Folder Motion Spec v0.1

## 0. Purpose

This document defines the motion system for Morning Folder.

It is meant to bridge three workflows:

- Figma: static states and prototype structure.
- After Effects: motion taste, easing, timing, and visual refinement.
- SwiftUI: implementation parameters for the macOS prototype/app.

The product should feel like a small native macOS object: calm, tactile, precise, and lightly charming. Motion should support the folder/paper metaphor without becoming decorative noise.

## 1. Motion Principles

### 1.1 Mac-Native Calm

Motion should be short, clean, and easy to ignore when the user is focused. Avoid large bounces, long transitions, looping decoration, or theatrical effects.

### 1.2 Paper Inside A Folder

The core metaphor is not generic cards. It is folder, tabs, sheets, slips, and small physical layers. Use subtle vertical offsets, opacity, scale, and depth changes to imply paper moving forward or backward.

### 1.3 One Focus Per Interaction

At any moment, only one or two elements should carry motion emphasis.

Examples:

- Opening: folder and papers move; text should not separately animate.
- Task completion: selected task and check dot move; other rows only respond to layout.
- Fortune reveal: cookie/slip move; surrounding cards stay quiet.

### 1.4 Reduced Motion Is A First-Class State

Every interaction must have a reduced-motion version. Reduced motion should preserve state change clarity with opacity and instant layout changes, not spatial travel.

## 2. Motion Tokens

### 2.1 Duration

| Token | Value | Use |
| --- | ---: | --- |
| `duration.micro` | 80ms | press compression, hover response |
| `duration.fast` | 140ms | small opacity or color state |
| `duration.base` | 220ms | tab switching, focus state |
| `duration.soft` | 300ms | task completion, small sheet movement |
| `duration.slow` | 380ms | folder expand/collapse, fortune reveal |

### 2.2 Easing

| Token | Curve | Use |
| --- | --- | --- |
| `ease.enter` | ease-out | elements entering view |
| `ease.exit` | ease-in | elements leaving view |
| `ease.state` | ease-in-out | color, opacity, focus changes |
| `spring.soft` | response 0.34, damping 0.82 | folder/paper motion |
| `spring.snap` | response 0.22, damping 0.90 | checkbox, press release |
| `spring.lazy` | response 0.48, damping 0.88 | larger sheet settling |

### 2.3 Transform

| Token | Value | Use |
| --- | ---: | --- |
| `scale.press` | 0.96 | click/press feedback |
| `scale.hover` | 1.015 | hover for clickable tile, optional |
| `scale.folderOpenPeak` | 1.03 | folder opening emphasis |
| `offset.paperIn` | 14px | sheet entering from behind folder |
| `offset.tabSwitch` | 8px | content card switch |
| `offset.fortuneSlip` | 12px | fortune slip reveal |
| `blur.hidden` | 4px | optional hidden slip/card softness |

### 2.4 Opacity

| Token | Value | Use |
| --- | ---: | --- |
| `opacity.hidden` | 0 |
| `opacity.muted` | 0.42 | completed task text/time |
| `opacity.secondary` | 0.62 | captions, hints |
| `opacity.full` | 1 |

## 3. Global Accessibility Rule

SwiftUI implementation should read:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

If `reduceMotion == true`:

- Disable y-offset travel.
- Disable scale overshoot.
- Use opacity-only transitions at `duration.fast`.
- Preserve layout/state changes immediately.

## 4. Interaction Specs

## 4.1 Collapsed Folder To Expanded Card

### Trigger

User clicks the collapsed folder icon.

### States

```text
collapsed
-> pressed
-> opening
-> expanded
```

### Intent

The folder feels like it wakes up, then the tabbed sheet rises from inside it.

### Figma Storyboard

Frame: `Motion Spec 01 - Folder Reveal`

Prototype preview:

- `Editable collapsed folder icon - black mono` click -> `Expanded TODAY card - mono base`
- Figma transition: `SMART_ANIMATE`, custom spring, 430ms
- Return preview: click TODAY frame -> collapsed folder, 260ms ease-in-out

The Figma prototype is only a rough preview. The implementation should follow the detailed timing below.

### Timeline v0.2

| Time | Element | Property |
| ---: | --- | --- |
| 0ms | folder | resting, scale 1, y 0 |
| 0-90ms | folder | y 0 -> -8, scale 1 -> 1.015, `cubic-bezier(.20, .80, .20, 1)` |
| 90-150ms | three inner papers | quick peek: front paper y -13px, left/right papers y -6/-7px with tiny x/rotation offsets |
| 130-170ms | three inner papers | tuck back before the main sheet extracts; opacity stays full |
| 150-240ms | card/sheet | begins inside folder mask, y 92 -> 34, scale 0.90 -> 0.94, opacity 0 -> 0.58 |
| 150-260ms | background/backplate | blur 0 -> 8px, opacity 0 -> 1, very soft focus lock |
| 240-340ms | card/sheet | morphs into full TODAY tab card, y 34 -> 0, scale 0.94 -> 1 |
| 270-360ms | folder | fades behind card, opacity 1 -> 0, y -8 -> 10 |
| 290-350ms | TODAY tab/title | opacity 0 -> 1, y 8 -> 0 |
| 340-440ms | task rows | row 1/2/3 fade in with 50ms stagger, y 6 -> 0 |
| 440-460ms | card | settles, max overshoot 2px, no visible wobble |

### Paper Peek Detail

This is a small anticipation beat before the main reveal.

- Use the existing three folded card layers inside the collapsed folder.
- The front tilted paper moves the most: about 13px up.
- The two back papers move less: about 6-7px up, with 3-4px horizontal separation.
- The motion should be quick and quiet: ease-out to reveal, ease-in to tuck.
- Do not add bounce here. The peek is a hint, not a reward.
- In reduced motion, skip this beat entirely.

### Motion Feel

- The motion should feel like a small macOS object being lifted and unfolded, not like a web modal popping up.
- Use one visible physical idea: the folder rises and the sheet comes forward.
- Keep the overshoot extremely small. It should feel tactile, not bouncy.
- Drop shadow should fade in with the card, not appear before the card has volume.

### AE Notes

- Animate folder as one precomp.
- Animate expanded card as one precomp for extraction and morph.
- Split content only for the final stagger: date/title first, then task rows.
- Do not animate every small icon or separator.
- The card should appear to come from the folder, not from the center of screen.

### SwiftUI Notes

Use a single state:

```swift
enum MorningFolderState {
    case collapsed
    case expanded(activeTab: MorningTab)
}
```

Recommended animation:

```swift
withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
    state = .expanded(activeTab: .today)
}
```

Implementation targets:

```swift
let revealSpring = Animation.spring(response: 0.34, dampingFraction: 0.86)
let liftEase = Animation.timingCurve(0.20, 0.80, 0.20, 1.00, duration: 0.09)
let paperPeekOut = Animation.timingCurve(0.16, 0.84, 0.24, 1.00, duration: 0.06)
let paperPeekIn = Animation.timingCurve(0.42, 0.00, 0.74, 0.42, duration: 0.04)
let contentStagger: TimeInterval = 0.05
```

### Reduced Motion

Use `opacity 0 -> 1` only, 120-140ms, no scale, no y movement, no blur ramp.

## 4.2 Expanded Card To Collapsed Folder

### Trigger

User clicks close area, outside click, or a future menu-bar collapse command.

### States

```text
expanded
-> closing
-> collapsed
```

### Timeline

| Time | Element | Property |
| ---: | --- | --- |
| 0-120ms | active content | opacity 1 -> 0, y 0 -> 6 |
| 40-260ms | tabs/card | opacity 1 -> 0, y 0 -> 12 |
| 80-300ms | folder | opacity 0 -> 1, scale 0.985 -> 1 |

### Notes

Closing should be quieter than opening. The user is leaving the surface, not being rewarded.

## 4.3 Tab Switching

### Trigger

User clicks `TODAY`, `YESTERDAY`, or `MOOD`.

### States

```text
active(tabA)
-> switching(from tabA, to tabB)
-> active(tabB)
```

### Intent

The selected tab behaves like the front sheet of a small folder stack.

### Figma Storyboard

Frame: `Motion Spec 02 - Tab Switching`

The storyboard uses TODAY -> YESTERDAY as the canonical example. YESTERDAY -> MOOD should reuse the same timing and distances.

### Timeline v0.2

| Time | Element | Property |
| ---: | --- | --- |
| 0ms | active tab | current tab is front sheet |
| 0-90ms | old content | opacity 1 -> 0.64, y 0 -> 6, `ease.exit` |
| 40-170ms | tab surface | active tab shape shifts to target position, `ease.state` |
| 40-170ms | tab labels | active/inactive weight and opacity transition |
| 90-170ms | sheet stack | old sheet tucks behind, new sheet becomes front |
| 170-240ms | new content | opacity 0.72 -> 1, y -6 -> 0, `ease.enter` |
| 240ms | target tab | target tab rests as front sheet |

### Direction Rule

Avoid large horizontal carousel movement. These are not pages sliding across a viewport; they are paper states switching front position.

### Motion Feel

- The old content should get quieter before the new tab fully asserts itself.
- The tab surface should feel like it is re-layering, not traveling across the card.
- Keep vertical movement within 6px.
- Do not scale the whole card during tab switching; the container is already open.
- Do not animate every list row independently unless the active tab content needs a brief stagger. Default is content-group fade/y only.

### SwiftUI Notes

Use the active tab as source of truth:

```swift
enum MorningTab {
    case today
    case yesterday
    case mood
}

withAnimation(.easeInOut(duration: 0.17)) {
    activeTab = .yesterday
}
```

Implementation targets:

```swift
let tabSurfaceMotion = Animation.easeInOut(duration: 0.17)
let oldContentExit = Animation.easeIn(duration: 0.09)
let newContentEnter = Animation.easeOut(duration: 0.10).delay(0.14)
let tabContentOffset: CGFloat = 6
```

### Reduced Motion

No y movement. Crossfade content and update tab state.

## 4.4 TODAY Task Completion

### Trigger

User clicks the completion dot.

### States

```text
open
-> confirming
-> completed
-> reordered
```

### Intent

The task acknowledges completion, becomes quiet, and moves to the bottom without feeling like it disappeared.

### Figma Storyboard

Frame: `Motion Spec 03 - Today Task Completion`

The storyboard uses the first TODAY task as the canonical example.

### Timeline v0.2

| Time | Element | Property |
| ---: | --- | --- |
| 0ms | task row | active task is readable; dot is open |
| 0-80ms | completion dot | scale 1 -> 0.88, `duration.micro`, click acknowledgement |
| 80-180ms | completion dot | check/fill appears, scale 0.88 -> 1, `spring.snap` |
| 80-220ms | task label/time | opacity 1 -> 0.42, color to muted grey |
| 140-300ms | task row | selected row moves to completed/bottom position, `spring.soft` |
| 140-300ms | neighboring rows | close the gap using the same layout spring |
| 180-300ms | separators | settle with layout, no independent flourish |
| 300ms | completed row | rests at bottom, quiet but still readable |

### Motion Feel

- The click feedback happens on the dot first. The whole row should not jump immediately.
- The row should become visually quiet before it finishes moving.
- The movement should feel like sorting, not deletion.
- No confetti, sparkle, bounce, or celebratory decoration.
- The row remains visible throughout; do not fade it to zero.

### AE Notes

Use row precomps. Do not animate text letter-by-letter.

### SwiftUI Notes

Use stable task IDs so layout animation can track reorder.

```swift
withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
    task.isComplete = true
    reorderTasks()
}
```

Implementation targets:

```swift
let dotPress = Animation.easeIn(duration: 0.08)
let dotRelease = Animation.spring(response: 0.22, dampingFraction: 0.90)
let mutedFade = Animation.easeInOut(duration: 0.14).delay(0.08)
let rowReorder = Animation.spring(response: 0.30, dampingFraction: 0.86).delay(0.14)
let completedOpacity: Double = 0.42
```

### Reduced Motion

Check appears and row jumps to completed position. Use opacity change only.

## 4.5 Fortune Cookie Reveal

### Trigger

User clicks the fortune tile inside the MOOD card.

### States

```text
closed
-> pressed
-> revealing
-> revealed
-> hiding
-> closed
```

### Intent

The interaction should feel like a small private surprise, not a modal. The fortune is hidden until asked for, then appears as a soft paper panel above the existing MOOD layout.

### Content

Fortune content is English only. This includes the label and the proverb/body text.

Example:

```text
FORTUNE COOKIE
A quiet beginning can still lead to a bright discovery.
```

Do not include lucky colors in the fortune panel. The palette dots already carry that information.

### Figma State

Frame: `Expanded MOOD card - fortune revealed`

The final static state is an in-card overlay: the MOOD surface remains visible behind the fortune panel, but it should visually recede.

### Reveal Timeline v0.2

| Time | Element | Property |
| ---: | --- | --- |
| 0ms | fortune tile | resting in MOOD grid |
| 0-70ms | fortune tile | scale 1 -> 0.965, press acknowledgement |
| 70-140ms | fortune tile | scale 0.965 -> 1, `spring.snap` |
| 80-220ms | underlying MOOD content | opacity 1 -> 0.62, blur 0 -> 3px, no position travel |
| 100-260ms | fortune panel | opacity 0 -> 1, y 10 -> 0, scale 0.975 -> 1 |
| 130-280ms | cookie icon | opacity 0 -> 1, y 6 -> 0 |
| 170-320ms | label/body text | opacity 0 -> 1, y 5 -> 0, 40ms stagger between label and body |
| 320-360ms | panel shadow | settles from soft/high to final subtle depth |

### Hide Timeline

| Time | Element | Property |
| ---: | --- | --- |
| 0-90ms | label/body text | opacity 1 -> 0, y 0 -> 3 |
| 40-180ms | cookie icon | opacity 1 -> 0, y 0 -> 4 |
| 50-220ms | fortune panel | opacity 1 -> 0, y 0 -> 8, scale 1 -> 0.985 |
| 120-240ms | underlying MOOD content | opacity 0.62 -> 1, blur 3px -> 0 |
| 0-120ms | fortune tile | optional subtle press scale 1 -> 0.985 -> 1 |

### Visual Direction

The panel is part of the MOOD card system:

- Use the same warm off-white surface language as ENERGY, PALETTE, and the capture input.
- Use the same corner radius family as the existing card interiors.
- Keep the cookie icon black, thin, and graphic.
- The fortune panel can overlap ENERGY/PALETTE slightly, but it should not feel like a separate app alert.
- Keep the static hierarchy: icon first, `FORTUNE COOKIE` second, proverb third.

Avoid:

- Confetti.
- Sparkles.
- Emoji.
- Large modal behavior.
- Dramatic bounce.
- A black fortune tile or heavy black container.
- Sliding a long paper strip out of the cookie.

### AE Notes

AE is optional. If explored, build one taste sample only:

- `MF_03_Fortune_Reveal`: tile press -> content recedes -> fortune panel appears.

Keep it under 360ms. The goal is Apple-like restraint: pressure, depth, and focus shift, not illustration.

### SwiftUI Notes

State:

```swift
enum FortuneState {
    case closed
    case revealed
}
```

Use a `ZStack` inside the MOOD content area. Keep the original MOOD layout mounted behind the overlay so the reveal feels spatial rather than page-changing.

Implementation targets:

```swift
let fortunePress = Animation.easeInOut(duration: 0.07)
let fortunePanelIn = Animation.spring(response: 0.32, dampingFraction: 0.88)
let fortuneContentIn = Animation.easeOut(duration: 0.15).delay(0.16)
let fortunePanelOut = Animation.easeInOut(duration: 0.18)
let fortuneBackdropBlur: CGFloat = 3
let fortuneBackdropOpacity: Double = 0.62
```

### Reduced Motion

Disable blur and y travel. Crossfade the overlay in place at `duration.fast`.

## 4.6 Quick Capture Focus And Save

### Trigger

User clicks the input field or presses a shortcut.

### States

```text
idle
-> focused
-> typing
-> saving
-> saved
-> idle
```

### Focus Timeline

| Time | Element | Property |
| ---: | --- | --- |
| 0-160ms | input surface | fill slightly brighter, inner shadow clearer |
| 0-160ms | placeholder | opacity 0.78 -> 0.55 |
| 0-160ms | save chip | opacity/contrast increases if text is non-empty |

### Save Timeline

| Time | Element | Property |
| ---: | --- | --- |
| 0-100ms | save chip | scale 1 -> 0.96 -> 1 |
| 0-220ms | input surface | brief highlight pulse |
| 160-260ms | input text | clears or moves into saved state |

### SwiftUI Notes

Use:

```swift
@FocusState private var captureFocused: Bool
```

The save action should never feel like a blocking network operation in MVP. If persistence takes time, show a tiny inline saving state, not a global spinner.

### Reduced Motion

Focus changes color/opacity only. Save shows text state change only.

## 4.7 Hover And Press States

### Hover

Use hover sparingly because this is a desktop app, but not every element needs lift.

| Element | Hover |
| --- | --- |
| Fortune tile | scale 1 -> 1.015, shadow slightly stronger |
| Task row | background tint appears at low opacity |
| Completion dot | stroke darkens |
| Save chip | fill deepens slightly |

### Press

Press states should be tactile and brief:

```text
scale 1 -> 0.96 -> 1
duration 80-140ms
```

## 5. AE Workflow Recommendation

### 5.1 Comps To Build First

AE is optional for taste exploration, not required for MVP. If we use AE, make only one or two short samples instead of rebuilding the whole product flow.

Recommended optional samples:

1. `MF_01_Folder_Open`
2. `MF_03_Fortune_Reveal`

Skip AE for tab switching and task completion unless the coded prototype feels wrong.

### 5.2 Frame Rate

Use 60fps if you want to inspect micro-timing. Export preview video at 30fps is fine for sharing, but keep the AE comp at 60fps for motion judgment.

### 5.3 Layer Prep

If an AE sample is needed, export or recreate these groups from Figma:

- Folder collapsed icon as one group.
- Expanded card as one group.
- Tabs as separate groups only if tab animation is being tested.
- TODAY task row as reusable precomp.
- Fortune tile, cookie icon, and fortune panel as separate layers.

### 5.4 What To Measure From AE

For each approved sample, record only the implementation-relevant values:

- Total duration.
- Keyframe timestamps.
- Position delta.
- Scale values.
- Opacity values.
- Easing curve notes.
- Whether motion should be spring-like or cubic.

## 6. SwiftUI Translation Checklist

Before implementation, every motion sample should answer:

- What state triggers it?
- What properties animate?
- What duration/token is used?
- What animation curve/spring is used?
- What happens in reduced motion?
- Does it need layout animation or only transform animation?
- Is the element still keyboard accessible?

## 7. Current Priority

Recommended next step:

1. Build or update a Figma storyboard for `MF_03_Fortune_Reveal`.
2. Keep it close to the final static design: tile press, content recedes, fortune panel appears.
3. Use the storyboard as the reference for the SwiftUI prototype.

Second:

1. Translate `MF_01_Folder_Open` into SwiftUI state/animation code.
2. This defines the app's first impression.

Third:

1. Translate `MF_02_Task_Complete` into SwiftUI row animation.
2. This defines everyday utility and feedback.

## 8. Open Questions

- Should the app support hover preview for weather/lucky color in v1, or defer until after the core three animations?
- Should completed TODAY tasks remain visible immediately, or move after a short delay?
- Should opening the app happen automatically each morning with the same animation, or should automatic pop-up use a quieter reduced variant?
