# Prism Roll icon

The production icon is `../PrismRoll/Assets.xcassets/AppIcon.appiconset/AppIcon.png`: opaque, 1024 × 1024, with no baked-in corner mask. `AppIcon-original.png` preserves the original generated artwork. The built-in image-generation tool produced it on September 6, 2026; `sips` resampled it for the asset catalog. Apple applies the system icon shape.

## Generation prompt

Use case: stylized-concept. Asset type: production iOS game app icon for Prism Roll, a 3D swipe-to-paint maze game. Create one exceptionally polished, memorable, bold app icon as a square full-bleed 1024x1024 opaque image. A large glossy violet-to-hot-coral iridescent rolling sphere sits at the end of a broad freshly painted coral/violet path turning through one clean right-angle bend in a small sculptural ivory ceramic maze. Strong recognizable silhouette readable at 60 pixels. Close overhead three-quarter view, just 2 or 3 substantial rounded maze walls, elegant contact shadows and studio highlights. Deep midnight indigo background fills all four corners; vibrant paint is the only saturated accent besides the sphere. Ball and clear curved paint trail are the focus, simple balanced composition with generous outer breathing room. Premium playful tactile 3D render, crisp edges and rich materials, not a screenshot or flat clipart. No text, no letters, no border, no inset app-icon rounded-square, no extra symbols, no tiny maze grid, no watermark, no transparency. Original artwork.

## Export

```sh
sips -z 1024 1024 ios/Design/AppIcon-original.png \
  --out ios/PrismRoll/Assets.xcassets/AppIcon.appiconset/AppIcon.png
sips -g hasAlpha -g pixelWidth -g pixelHeight \
  ios/PrismRoll/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

Visually inspect the full-resolution result and its small-size appearance before publishing. The previous procedural icon generator has been removed so it cannot overwrite this asset.
