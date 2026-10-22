# Contract: UI theme — "Soft Pastel Light"

A calm, modern, **light** theme with muted pastel accents. Pastels are used for **surfaces, chips and
highlights**; text always uses the deep ink colours, so everything stays readable. No saturated or neon
colours, no dark mode, no pure black.

The single source of truth for colour values is `harness/layer2-playwright/theme.tokens.json`.
The app defines the same tokens once as named formulas in `App.Formulas` (see plan.md, Design Decision 8),
and controls reference tokens by name. **No hex colour may appear in a screen file**, only in `App.Formulas`.

## Colour tokens

| Token | Hex | Used for |
|---|---|---|
| `Bg` | `#F7F8FC` | Screen background (cool off-white) |
| `Surface` | `#FFFFFF` | Cards, forms, gallery rows |
| `SurfaceAlt` | `#F1F2F9` | Alternating gallery rows, input fills, hover |
| `Border` | `#DADDEA` | 1 px card and input borders (decorative) |
| `AppBar` | `#E9E8F8` | Top app bar (soft lavender) |
| `Primary` | `#5F66B8` | Primary buttons, selected nav, focus accents (muted periwinkle) |
| `OnPrimary` | `#FFFFFF` | Text and icons on Primary |
| `PrimarySoft` | `#E6E8F7` | Selected row, secondary-button fill |
| `FocusRing` | `#7A80D0` | Keyboard focus outline (2 px) |
| `Ink` | `#2E3142` | Primary text (deep slate, never pure black) |
| `InkMuted` | `#5B6075` | Secondary text, labels, helper text |
| `Error` | `#A3364A` | Validation text |

### Status chips (pastel fill + deep text of the same hue)
| Status | Fill token / hex | Text token / hex | Contrast |
|---|---|---|---|
| Draft | `ChipSky` `#DDEBF7` | `ChipSkyInk` `#2F5A80` | 5.98:1 |
| Submitted | `ChipPeach` `#FCE5D6` | `ChipPeachInk` `#8A4A26` | 5.61:1 |
| Approved | `ChipMint` `#D5EEE3` | `ChipMintInk` `#2D6650` | 5.49:1 |
| Rejected | `ChipRose` `#F9DDE2` | `ChipRoseInk` `#8C3343` | 6.17:1 |
| Highlight (e.g. vacation widget, feature 002) | `ChipButter` `#FAF1D6` | `ChipButterInk` `#6E5410` | 6.34:1 |

### Project colour dots (decorative, 10 px circle before the project name)
Contoso Migration `#B9C3F2` (periwinkle) · Fabrikam Portal `#F6C9B4` (peach) · Internal Training `#BFE3D2` (mint) ·
any other project `#E8D7F1` (lilac).

All text pairs meet **WCAG 2.1 AA (≥ 4.5:1)**. This is verified automatically by
`harness/layer2-playwright/tests/theme-contrast.spec.ts`.

## Typography
- Font: the theme's default modern font (Segoe UI family). One family only.
- Sizes: screen title 24 semibold · section title 18 semibold · body 14 · helper and labels 12 (`InkMuted`) · big number (week total) 32 semibold.
- Sentence case everywhere; no all-caps body text.

## Shape, spacing, depth
- 8-pt spacing grid: gaps of 8 / 16 / 24; screen padding 24.
- Corner radius: cards 12, inputs and buttons 8, chips 999 (pill).
- Depth: cards use `Border` plus the lightest available shadow; no heavy drop shadows.
- Buttons: primary = `Primary` fill / `OnPrimary` text; secondary = `PrimarySoft` fill / `Ink` text; destructive actions (Delete, Reject) = outline in `ChipRoseInk` (text and border) on the card surface, never bright red. Modern buttons derive their fill from the base colour and darken pastels, so a pastel fill is not used.

## Screen composition (what makes it feel modern and friendly)

**App bar (both screens)**: `AppBar` background, app name "Timekeeper" in `Ink`, a friendly greeting on the left
("Good morning, Priya", based on the time of day: morning before 12, afternoon before 17, otherwise evening),
and on the right the navigation button (`Go to Approvals` / `Go to Log Time`) as a secondary button.

**Log Time**
- A **week summary card** at the top: the big week total ("17.5 h"), "of 40 h" in `InkMuted`, and a slim rounded
  **progress bar** (track `SurfaceAlt`, fill `Primary` at 60% opacity) showing hours ÷ weekly capacity.
- **This week** as a list of soft cards: project dot, project name, date (e.g. "Mon 12 Oct"), hours, and a status chip.
- **Add entry** form in its own card, with inputs on `SurfaceAlt` fill, the primary "Save entry" button, and validation text in `Error` under the field.
- **Empty state**: "No time logged yet this week. Add your first entry below ✨" in `InkMuted`, centred.

**Approvals**
- Each pending entry is a card: the person's initials in a `PrimarySoft` circle, name, project dot + project, date, hours.
- "Approve entry" is primary; "Reject entry" is the soft rose button. The rejection comment box expands inside the card.
- **Empty state**: "All caught up — nothing waiting for approval 🎉".

## Don'ts
No saturated reds, greens or blues · no gradients · no pure black (`#000000`) · no text on pastel fills except the matching chip ink · no more than one primary button per card.
