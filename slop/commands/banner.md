---
description: Create README banner SVGs for dark and light themes
---

Create a clean, wide SVG banner for this repository's README.

First inspect the repository and README so the banner fits the project's purpose, tone and existing visual identity.

Create:

- `.github/banner.svg` for dark-mode backgrounds
- `.github/banner-light.svg` for light-mode backgrounds

Requirements:

- Transparent background.
- Matching dark/light pair.
- Wide banner shape, with a generally more compact height.
- Clean, inviting and nicely detailed (but not overly complicated).
- Good contrast for each theme.
- Optional small personal touches when they fit the project (for example the Go gopher or similar matching details, but do not force it).
- We don't want just a logo, title and slogan.
- Keep border radii to a minimum (max 2px).
- Keep the SVG markup clean and maintainable.

Add or update the README to use:

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/banner.svg">
  <source media="(prefers-color-scheme: light)" srcset=".github/banner-light.svg">
  <img alt="alt text here" src=".github/banner-light.svg">
</picture>

Write concise alt text yourself based on the repository.