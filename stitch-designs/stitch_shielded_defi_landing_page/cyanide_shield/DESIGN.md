# Design System Document: Shielded Precision

## 1. Overview & Creative North Star
**Creative North Star: "The Monolithic Void"**
This design system moves away from the cluttered, neon-soaked tropes of traditional DeFi. Instead, it adopts a high-end editorial approach rooted in **The Monolithic Void**. The aesthetic is defined by extreme high contrast, expansive negative space, and a sense of architectural permanence. 

By utilizing a strictly limited three-color palette, we convey a "Zero-Knowledge" philosophy: what isn't essential is hidden. The design breaks the "standard template" look through intentional asymmetry, where large typographic displays are offset by microscopic, high-precision data points, creating a UI that feels like a secure, high-end vault.

---

## 2. Colors
The palette is restricted to three core tones to ensure absolute visual clarity and focus on shielded assets.

*   **Primary Accent:** `#0AD9DC` (Primary / Action)
*   **Secondary/Text:** `#FFFFFF` (On-Surface / On-Background)
*   **Deep Background:** `#001623` (Surface / Background)

### The "No-Line" Rule
Traditional 1px borders are strictly prohibited for sectioning. Structural definition must be achieved through:
1.  **Direct Contrast:** Placing `#FFFFFF` text blocks directly against the `#001623` void.
2.  **Spatial Isolation:** Using the Spacing Scale (specifically `16` to `24`) to create "islands" of information.
3.  **Tonal Shifts:** Utilizing the `surface_container` tiers (e.g., `#0b222f` vs `#001522`) to create subtle, non-linear containment.

### Surface Hierarchy & Nesting
To create depth without gradients or shadows, we use **Nesting**. 
- **Base Level:** `surface` (`#001522`) for the main canvas.
- **Level 1 (Sections):** `surface_container_low` (`#061e2b`) for large content blocks.
- **Level 2 (Cards/Actions):** `surface_container` (`#0b222f`) for interactive elements.
- **Level 3 (Focus):** `surface_container_highest` (`#223745`) for high-priority data overlays.

---

## 3. Typography
Typography is the primary architecture of this system. We pair the technical sharpness of **Space Grotesk** with the functional clarity of **Inter**.

*   **Display & Headlines (Space Grotesk):** Use `display-lg` (3.5rem) for balance totals and "Shielded" status. The aggressive tracking and geometric weight convey institutional security.
*   **Titles & Body (Inter):** Use `title-md` (1.125rem) for transaction labels and `body-md` (0.875rem) for metadata. 
*   **Labels (Inter):** `label-sm` (0.6875rem) should be used for micro-data (gas fees, hashes). Use all-caps with `0.05em` letter spacing to maintain a "blueprint" feel.

The hierarchy is "Top-Heavy": Large headlines command attention, while data is kept small and precise, mimicking a Swiss editorial layout.

---

## 4. Elevation & Depth
In a system without gradients or traditional shadows, depth is a product of **Value Stacking**.

*   **The Layering Principle:** Rather than "lifting" an object with a shadow, we "carve" it out of the background. An asset card should sit on `surface_container_low`. If a modal appears, it uses `surface_container_highest`.
*   **The "Ghost Border" Fallback:** In high-density data environments where separation is critical, use the `outline_variant` (`#3b4949`) at **15% opacity**. This creates a "barely-there" guide that maintains the minimalist aesthetic.
*   **Glassmorphism:** For floating transaction drawers, use `surface_container` with a `20px` backdrop blur. This allows the primary accent color (`#0AD9DC`) of underlying buttons to "glow" through the dark glass, indicating activity beneath the surface.

---

## 5. Components

### Buttons
*   **Primary:** Background `#0AD9DC`, Text `#003738` (on_primary). Roundedness: `md` (0.375rem). Use for "Send," "Execute," or "Confirm."
*   **Secondary:** Background `none`, Border `Ghost Border` (15% opacity), Text `#FFFFFF`.
*   **Tertiary:** Text `#0AD9DC`, no background. Used for "Cancel" or "View Details."

### Input Fields
*   **Base:** Background `surface_container_lowest`, no border.
*   **Active State:** A bottom-only stroke of `2px` using `#0AD9DC`. 
*   **Data Entry:** Use `title-lg` for amount inputs to emphasize the value of the assets being moved.

### Cards & Lists
*   **The Rule of Zero Dividers:** Never use a horizontal line to separate list items. Use spacing `3` (0.6rem) between items. 
*   **Selection:** Active list items should shift from `surface` to `surface_container_high`.

### Shielded Status Indicator
*   A custom component: A `12px` circle of `#0AD9DC` with a pulse animation, paired with `label-md` text. This is the only "active" colored element on a dark screen, signifying security is active.

---

## 6. Do’s and Don’ts

### Do:
*   **Embrace Asymmetry:** Align your "Total Balance" to the far left, while placing "Action Buttons" in the bottom right.
*   **Use Excessive Whitespace:** If a section feels crowded, double the spacing value. In DeFi, breathing room equals trust.
*   **Type as UI:** Treat a large 64pt number as a graphical element, not just data.

### Don’t:
*   **No Gradients:** Do not use a transition from `#0AD9DC` to any other color. Use flat, bold blocks.
*   **No Icons for Everything:** Use text labels (`label-md`) instead of ambiguous icons. Words are more secure than symbols.
*   **No Pure Black:** Never use `#000000`. Only use the defined background `#001623` to maintain the deep, "midnight-blue" sophistication of the system.
*   **No Standard Shadows:** If an element needs to stand out, increase its surface brightness (`surface_bright`) rather than adding a drop shadow.