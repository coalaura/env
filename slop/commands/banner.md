---
description: Create distinctive README banner SVGs for dark and light themes
---

Create a wide SVG banner for this repository's README that feels deliberately designed for this project, rather than assembled from a generic developer-tool template.

First inspect the repository and README. Understand what the project does, what makes it distinctive, and its tone and existing visual identity. Look for a useful visual hook in its behavior, name, domain, or an appropriate bit of humor.

Before drawing, consider a few genuinely different visual concepts and choose the strongest. These should differ in their central idea and composition, not just colors or decorations. Then implement the chosen concept.

Create:

- `.github/banner.svg` for dark-mode backgrounds
- `.github/banner-light.svg` for light-mode backgrounds

## Art direction

- Build the banner around one clear, project-specific visual idea. It might explain a mechanism, illustrate a metaphor, make a small visual joke, or integrate a distinctive motif into the lettering. These are possibilities, not a checklist or a required style.
- Aim for a memorable silhouette and clear visual hierarchy: the project name and main visual should read immediately; smaller details reward a closer look.
- Make the main visual work primarily through shapes and composition, rather than requiring the viewer to read tiny labels or code.
- Choose the composition to suit the concept. Do not default to the same title-left / panel-right layout for every project.
- Prefer a few well-developed elements over many small embellishments. Detail should explain something, add character, or strengthen the composition.
- Do not use terminal windows, code samples, dashboard cards, badges, accent bars, or floating symbols merely to make the banner look technical or complete. They are welcome when they are genuinely the right subject.
- Personality is welcome when it fits: a restrained visual joke, a custom illustration, or a mascot interacting meaningfully with the concept. Do not add a Go gopher merely because the repository uses Go.
- Keep copy economical. Usually the project name and, if useful, one short supporting line are enough. Avoid turning the banner into a miniature README. Any technical claims or code shown must be supported by the repository.
- Do not force complexity. A simple, distinctive concept is better than a busy illustration or an elaborate but generic mock interface.

## Visual and technical requirements

- Transparent background.
- Matching dark/light pair: the same design, with colors thoughtfully adapted for contrast and visual balance in each theme.
- Wide proportions and a reasonably compact height, but give the main visual enough room to be expressive and legible.
- Balance the artwork across the canvas with intentional whitespace. Avoid both cramped content and large areas that feel accidentally empty.
- Ensure important text and details remain readable at typical README display widths, not just when viewing the SVG at full size.
- Keep corner radii on UI-like boxes and frames to a minimum (max 2px). This does not restrict curves in lettering, illustrations, or organic shapes.
- Keep SVG markup clean, maintainable, and self-contained. Use sensible grouping, reusable definitions where useful, and no external font or image dependencies.

## Review

Before finishing, review the result:

- Does the visual express something specific about this project, or could it accompany almost any library after changing the name?
- Is there one clear focal idea, rather than several competing decorations?
- Can any small text, border, or ornament be removed to make it stronger?
- Does it still read well when scaled down to README width?
- Are both theme variants legible and balanced?

## README integration

Add or update the README to use:

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/banner.svg">
  <source media="(prefers-color-scheme: light)" srcset=".github/banner-light.svg">
  <img alt="alt text here" src=".github/banner-light.svg">
</picture>
```

Write concise, meaningful alt text based on the repository and chosen concept. Keep the surrounding README intact unless a small adjustment is needed for the banner integration.

$ARGUMENTS