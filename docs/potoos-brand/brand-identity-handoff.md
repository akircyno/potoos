# Potoos Brand Identity Handoff

## Brand Decision

Product name: **Potoos**

Mascot name: **Poto**

Tagline: **Original memories, safely shared.**

Mascot role: **Your memory guardian.**

Current implementation name: **LitratoLink**

Future implementation name: **Potoos**

## Brand Meaning

Potoos is a private photo and video sharing app focused on preserving original quality. The name sounds close to "photos" while feeling more ownable and mascot-friendly.

Poto is the app's guardian character. Poto watches over private albums, protects original files, helps with uploads and downloads, and makes technical safety feel warm and understandable.

## Positioning

Potoos is not a social media app.

Potoos is for:

- private albums
- invited people only
- original-quality photo and video sharing
- easy Save All downloads
- trusted memory storage workflows

## Core Message

```text
Your memories. Your circle. Your quality.
```

## Personality

Potoos should feel:

- warm
- private
- premium
- protective
- calm
- trustworthy
- a little magical

Poto should feel:

- watchful
- gentle
- curious
- helpful
- expressive
- protective, not scary
- cute, but not baby-ish

## Color Palette

Based on the provided Potoos brand image.

### Core Colors

| Token | Hex | Use |
| --- | --- | --- |
| Midnight Burgundy | `#21070D` | Dark backgrounds, splash depth |
| Deep Maroon | `#4A1220` | Main app headers, primary brand |
| Velvet Maroon | `#6B1C2E` | Buttons, cards, gradients |
| Garnet Highlight | `#8A2438` | Hover/active accents, secondary highlights |
| Soft Gold | `#C4973A` | Primary accent, icons, borders |
| Bright Gold | `#F1C85B` | Mascot eye glow, success sparkle |
| Warm Cream | `#FAF6F0` | Main app background |
| Pearl Cream | `#FFF8E8` | Logo text, light surfaces |
| Feather Taupe | `#B9A58A` | Mascot feather-neutral UI accents |
| Charcoal Ink | `#24191B` | Body text on light surfaces |

### Suggested App Usage

- App background: `#FAF6F0`
- Header background: `#4A1220`
- Primary button: `#6B1C2E`
- Accent icons and borders: `#C4973A`
- Mascot glow and premium detail: `#F1C85B`
- Body text: `#24191B`

## Typography Direction

The brand image uses an Apple-like premium display direction.

Recommended app typography:

- Display/headings: General Sans or SF Pro Display style
- Body/UI: Inter or SF Pro Text style

If keeping the current app stack:

- Headings: General Sans
- Body/UI: Inter

This is still compatible with the new Potoos brand.

## Poto's Product Roles

Poto should not be decoration only. Poto should appear when it helps users understand the product.

### Upload Guardian

Use when uploading original files.

Example copy:

```text
Poto is protecting your original.
```

### Quality Checker

Use after upload/download quality checks.

Example copy:

```text
Original quality confirmed.
```

### Privacy Guide

Use on invite-only and role screens.

Example copy:

```text
Only invited people can enter this album.
```

### Save All Helper

Use when bundling originals into a ZIP.

Example copy:

```text
Poto packed your originals.
```

### Empty State Companion

Use in empty albums or empty activity.

Example copy:

```text
Poto is waiting for your first memory.
```

### Error Helper

Use only for recoverable errors.

Example copy:

```text
Poto could not reach storage. Try again.
```

## Poto UI Placement Rules

Use Poto only where the mascot reduces confusion or adds trust:

- onboarding and splash
- empty albums
- upload progress
- upload success
- Save All progress
- privacy/invite explanation
- friendly recoverable errors

Avoid using Poto on every screen. Too much mascot presence will make the app feel less premium and more childish.

## Claude Implementation Notes For Later

When implementation starts, Claude should treat this folder as the brand handoff and follow this order:

1. Rename visible app copy from LitratoLink to Potoos.
2. Update app icon, PWA manifest, browser title, and splash metadata.
3. Update Flutter theme color tokens to the approved Potoos palette.
4. Keep layouts and user flows from the current Sprint 1 UI unless the user explicitly asks for redesign.
5. Keep Supabase project URL, Google OAuth client, GitHub repo, and storage setup unchanged unless a separate migration plan is approved.
6. Re-test Google OAuth, album creation, upload, download original, Save All, invites, and PWA route refresh.

## Rename Caution

Do not rename everything immediately. Rename in this order later:

1. Finalize mascot reference.
2. Finalize app icon and logo.
3. Update app display name and PWA metadata.
4. Update UI text from LitratoLink to Potoos.
5. Update docs.
6. Update Supabase/Google/GitHub URLs only if project URLs change.
7. Test OAuth redirect after every hosted-domain change.

## Handoff Summary

Use this as the brand source of truth:

```text
Potoos is a private photo and video sharing app for original-quality memories.
Poto is the memory guardian who protects uploads, privacy, and downloads.
The visual world is deep maroon, soft gold, warm cream, and gentle owl-like watchfulness.
```
