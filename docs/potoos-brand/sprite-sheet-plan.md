# Poto Sprite Sheet Plan

This is a beginner-friendly plan for turning Poto into reusable animation assets.

## What Is A Sprite Sheet?

A sprite sheet is one image file that contains many animation frames arranged in a grid.

Instead of loading many separate images, the app can load one sheet and show one frame at a time.

Example:

```text
idle_01 idle_02 idle_03 idle_04
blink_01 blink_02 blink_03 blink_04
happy_01 happy_02 happy_03 happy_04
```

## Important Advice

Do not start with a sprite sheet immediately.

First create:

1. final Poto reference image
2. character sheet
3. expression sheet
4. key poses
5. cleaned PNG frames
6. sprite sheet

If you start with a sprite sheet too early, Poto may look inconsistent in every frame.

The correct mindset: sprite sheets are an implementation asset, not a character design tool.

## Recommended First Sprite States

Start with 8 states only.

| State | Purpose | Frames |
| --- | --- | --- |
| idle | Default waiting animation | 6 |
| blink | Small natural blink | 4 |
| happy | Upload/download success | 6 |
| guarding | Privacy/original protection | 8 |
| uploading | Upload progress | 8 |
| save_all | Packing originals into ZIP | 8 |
| warning | Recoverable error | 6 |
| sleeping | Empty/waiting state | 6 |

Total first batch: 52 frames.

## Frame Specs

Recommended:

```text
Frame size: 512x512
Background: transparent PNG
Character safe area: 420x420
Style: same Poto reference, same lighting
File type: PNG sequence first
Sprite sheet later: PNG
```

## Naming Convention

Use this structure:

```text
poto_idle_01.png
poto_idle_02.png
poto_idle_03.png
poto_blink_01.png
poto_blink_02.png
poto_happy_01.png
```

## Prompt Template For Each State

Use this after uploading the final Poto reference image.

```text
Using the uploaded final Poto mascot image as the exact character reference, create a clean transparent PNG animation frame set for the state: [STATE_NAME].

Mascot: Poto from Potoos.
Role: your memory guardian.
Brand: deep maroon, velvet maroon, soft gold, bright gold, warm cream.

Generate [FRAME_COUNT] frames showing a smooth loop/action. Keep Poto's face shape, big golden eyes, feather pattern, beak shape, and premium cute style perfectly consistent. Use a centered 512x512 composition with transparent background. No text, no watermark, no extra characters.

State description:
[STATE_DESCRIPTION]
```

## State Prompt Details

### Idle

```text
State: idle
Frame count: 6
Description: Poto gently breathes while looking forward. Tiny feather movement, soft eye shine, calm memory guardian expression. Loop should feel still, warm, and premium.
```

### Blink

```text
State: blink
Frame count: 4
Description: Poto slowly blinks once, then returns to the same open-eyed pose. Keep head position almost identical for a clean loop.
```

### Happy

```text
State: happy
Frame count: 6
Description: Poto smiles softly with bright golden eyes after a successful upload or download. Add a tiny warm gold sparkle near the camera frame, but keep background transparent.
```

### Guarding

```text
State: guarding
Frame count: 8
Description: Poto protects a small floating photo card with a soft gold shield glow. The shield appears gently, then settles. This represents private original-quality protection.
```

### Uploading

```text
State: uploading
Frame count: 8
Description: Poto watches a small photo card float upward with a gold progress trail. Eyes are focused and calm. Motion should feel safe and steady, not rushed.
```

### Save All

```text
State: save_all
Frame count: 8
Description: Poto gathers two or three tiny photo cards into a small gold ZIP bundle. Poto looks pleased and careful, as if packing originals safely.
```

### Warning

```text
State: warning
Frame count: 6
Description: Poto tilts head with a gentle concerned expression. A small soft gold warning sparkle appears. It should feel helpful, not alarming.
```

### Sleeping

```text
State: sleeping
Frame count: 6
Description: Poto rests with eyes closed in a calm waiting pose. Small slow breathing motion. Good for empty albums or quiet loading states.
```

## Tools For Sprite Sheet Creation

Beginner path:

1. Generate PNG frames.
2. Clean frame backgrounds if needed.
3. Rename frames consistently.
4. Use TexturePacker or Aseprite to arrange frames into a sprite sheet.
5. Export a JSON metadata file if the app needs frame coordinates.
6. Test the animation in Flutter before creating more states.

Tools:

- Aseprite: best for sprite sheet editing and frame cleanup
- TexturePacker: best for packing PNG frames into sheets
- Rive: better if you want vector-style interactive app animation instead of frame sprites
- CapCut: not recommended for sprite sheet creation

## ChatGPT Sprite Sheet Warning

ChatGPT can help create concept frames, but it may not keep every frame perfectly consistent. Use ChatGPT to explore the motion, then clean and arrange the final frames manually.

For app-quality sprite sheets, prefer this path:

```text
ChatGPT reference frames -> manual cleanup -> Aseprite/TexturePacker -> Flutter test
```

## First App Usage

Use only 2 or 3 states in the app first:

- idle on empty states
- guarding during upload
- happy after success

Add more only after these look consistent.
