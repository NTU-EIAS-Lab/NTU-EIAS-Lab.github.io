# Profile photos

Drop headshots here and point each member's `photo` field in `data/people.json` at
the file, relative to the site root:

```json
{
  "name": "Edward Tan",
  "role": "PhD Student",
  "focus": "Spatial AI; SLAM, Navigation, 3D Reconstruction",
  "photo": "assets/people/edward-tan.jpg",
  "link": "edward62740.github.io"
}
```

Leave `photo` as `""` (or omit it) and the card falls back to the hatched
`photo` placeholder swatch.

Conventions:

- Square source image, ideally 200×200 or larger — the card renders it at 46×46
  with `object-fit: cover` and `object-position: center top`, so a non-square
  image is cropped from the top edge.
- Lowercase kebab-case filename matching the person's name.
- `.jpg` for photos, `.png` only when transparency is needed.
