# Project figures

Each entry in `data/research.json` has one `media` field that accepts **either** a
still or a clip — the type is detected from the file extension, so there is no
separate video field to set:

| Extension | Rendered as |
| --- | --- |
| `.jpg` `.jpeg` `.png` `.webp` `.avif` `.svg` `.gif` | `<img>` (an animated GIF plays on its own) |
| `.mp4` `.webm` `.ogv` `.mov` `.m4v` | `<video>`, muted and looping |

```json
{
  "title": "SLAM on FPGA",
  "media": "assets/research/fpga-demo.mp4",
  "poster": "assets/research/fpga-demo.jpg",
  "link": "#"
}
```

Leave `media` as `""` and the card falls back to the hatched `project figure`
placeholder.

Conventions:

- 16:9 source — the figure box is `aspect-ratio: 16/9` with `object-fit: cover`,
  so other ratios get centre-cropped.
- `poster` is optional and only used for video. Point it at a still frame; it is
  what shows before the clip loads, and what a visitor who has "reduce motion"
  turned on sees instead of a playing video. Ignored for images.
- Prefer MP4/WebM over GIF for anything longer than a beat or two — the same
  clip is routinely 20× smaller as video.
- Clips play muted and looping with no controls (they sit inside a link, so
  controls would fight the click). Keep them short and seamless.
