---
name: web-design
description: Design, implement, refine, or review web interfaces with a distinctive visual identity and clear information hierarchy. Use for websites, landing pages, dashboards, forms, components, responsive layouts, visual polish, or requests to make a UI feel less generic or AI-generated.
---

# Web design

Build an interface that belongs to its subject and makes its purpose clear. Originality should improve expression or understanding without making familiar tasks harder.

## Establish the scope

Read the applicable instructions and inspect the relevant page, components, styles, content, and assets before choosing a direction. Look for existing design decisions in the project; do not infer a website's style from unrelated editor or terminal preferences.

Identify the audience, the main task or message, the available content, and what the user actually wants changed. Use the repository and brief to resolve ordinary details. Ask only when missing information would materially change the result.

Match the work to the request:

- For a small fix or component addition, preserve the surrounding visual language and solve the local problem.
- For a new site or substantial redesign, establish a coherent direction before implementing.
- For a review or design discussion, return findings or proposals without modifying files.

Follow project rules for code, dependencies, tools, and verification. This skill does not authorize installations, application startup, external browsing, or additional documentation files.

## Choose a direction

For a new site or substantial redesign with open creative choices, consider a few plausible directions that differ in composition, information order, and treatment of the subject. Changing only the font and accent color does not create another direction. Choose the strongest fit; do not make the user approve routine design decisions.

Follow an explicit aesthetic brief or supplied design reference; do not impose novelty over the user's direction. Where the brief leaves room, make a confident visual choice and carry it through instead of averaging competing directions into a safe default.

Ground the choice in something concrete: the product's behavior, the audience's working environment, the material being presented, or an existing identity. References supplied by the user or available in the project can help. When external reference research is authorized, borrow principles such as hierarchy or pacing, not another site's identity or entire composition.

Before substantial implementation, briefly state the chosen direction and its practical consequences: what receives attention first, how the page is organized, and which visual decisions give it character. Keep this in chat unless the user requests a document.

Develop one coherent idea across the interface. Do not combine unrelated stylistic effects to demonstrate variety. Carry the same design logic into navigation, secondary sections, forms, and responsive behavior.

Distinctiveness does not require maximalism, unusual navigation, or a decorative metaphor. A restrained interface can have character through excellent composition, precise typography, useful content, and careful interaction.

## Let content determine the layout

Work with actual headings, labels, data, and assets early. Establish the reading or interaction order before polishing individual components.

- Give each region a clear job. Use headings, grouping, alignment, spacing, and contrast to communicate relationships.
- Choose the opening around the most useful introduction to this subject. It might be the work itself, a clear explanation, a useful control, or evidence of the product in use.
- Let section boundaries follow changes in topic or task. Do not automatically assemble a hero, logo strip, equal feature cards, testimonials, and a closing call to action.
- Use cards when items need independent grouping or interaction. Use lists, tables, plain sections, or other structures when they express the relationship more clearly.
- Match density to the job. Reading, comparison, monitoring, and promotion need different amounts of space and different priorities.
- Make the primary action clear where it belongs. Do not add competing calls to action merely to fill a layout.

Write concrete copy supported by the brief or repository. Name actions by what they do, and keep terminology consistent. Do not invent customer quotes, adoption figures, awards, product capabilities, or performance claims. Label necessary example data as illustrative. Do not let placeholder copy or repeated dummy records determine the final layout.

Use imagery that explains the subject, shows the work, or establishes relevant atmosphere. If suitable assets are unavailable, build around strong content and composition; do not fill the gap with unrelated stock imagery or decorative mock interfaces.

## Build a consistent visual system

Use the project's existing tokens and components where they fit. For a new direction, define a small set of reusable decisions in the implementation: type roles, spacing, content widths, colors, borders, surfaces, and interaction states.

- Choose type for its role and tone, then tune size, weight, line height, and measure. Existing or system fonts are valid choices. Do not add font dependencies merely to seem distinctive.
- Use color to establish hierarchy, identity, and state. Keep text and controls legible; do not use color as the only carrier of meaning.
- Make spacing express relationships. Related items should read as a group, and major transitions should be visibly different from minor gaps.
- Make borders, shadows, radii, textures, and ornament serve a visible purpose. Do not apply the same container treatment to every element.
- Use motion to explain a change or support the chosen experience. Keep essential content available without animation, respect reduced-motion preferences, and avoid repeated entrance effects without a reason.
- Design responsive behavior as a change in composition and priority, not a scaled-down desktop screenshot. Preserve useful content and actions without forcing every section to fill the viewport.

No font, color, radius, or layout is universally forbidden. A stock gradient-and-card composition and a fashionable serif-and-hairline composition can both become templates. Judge whether the decisions fit this project and work together.

## Implement the real interface

Keep the implementation proportional to the design and compatible with the existing stack. Prefer native HTML and CSS capabilities and existing components before introducing another abstraction or dependency. Follow the project's dependency approval rules.

Use semantic elements, sensible heading order, labeled controls, visible keyboard focus, and appropriate alternative text. Keep DOM order aligned with reading and focus order. Ensure essential interactions work without hover and remain usable with touch and enlarged text.

Implement the states relevant to the task: selected, disabled, loading, empty, error, or success. Account for realistic text lengths and data volumes. Preserve existing behavior and integrations.

Controls should perform their stated actions. Do not make a prototype appear connected to services it does not use; describe the boundary clearly and avoid fabricated success states.

## Review and refine

Inspect the rendered result when an authorized running application, preview, or suitable rendering tool is available. Follow project restrictions: do not start the application or a server without explicit authorization. Use available tooling; do not install browser tooling just to complete this checklist.

For an implemented page, inspect a wide viewport, a narrow viewport, and an intermediate width where the composition changes. Check relevant interactions and states. Supplied screenshots can support visual review but do not establish that interactions work.

Review the result in this order:

1. Purpose: Is the message or main task clear? Does the content support it?
2. Structure: Is attention directed deliberately? Are grouping, reading order, and density appropriate?
3. Identity: For a new site or substantial redesign, could another project use the page after only swapping its name and accent color? If so, improve the content or composition instead of adding decoration.
4. Usability: Check keyboard access, focus, contrast, touch behavior, text enlargement, overflow, and relevant states.
5. Finish: Check alignment, spacing, type, image cropping, visual consistency, and unnecessary ornament.

Fix the largest observed problems first, then recheck the affected areas. Do not redesign repeatedly without identifying a specific defect. For an established product, consistency and task clarity can matter more than visual novelty.

Use the project's normal build, lint, and test checks as appropriate. A passing build does not verify visual quality. If rendering or interaction checks are unavailable, report that limitation and distinguish static review from observed behavior.

Finish with a brief account of the design decisions, checks actually performed, and any remaining limitations. Do not claim the result is accessible, responsive, or visually verified solely because the code intends it to be.