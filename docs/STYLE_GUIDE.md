# CookCut Style Guide

## Brand Identity

CookCut combines professional video editing with cooking-inspired design elements to create an intuitive and delightful experience for food content creators.

### Core Values
- Professional & Reliable
- Warm & Inviting
- Clear & Intuitive
- Cooking-Inspired

## Colors

### Light Mode

#### Primary Colors
- Primary Blue: `#0277BD` (rgb(2, 119, 189)) (Logo blue)
  - Used for primary actions, links, and brand elements
  - Creates a strong, trustworthy impression
- Primary Gradient: Linear gradient from `#0277BD` to `#0288D1`
  - Used for primary action buttons and key interactive elements
  - Adds depth and visual interest to important actions

#### Surface Colors
- Background: `#FFFFFF` (Pure white)
  - Main application background
  - Creates a clean, open canvas
- Surface: `#F5F5F5` (Light grey)
  - Card backgrounds and elevated surfaces
  - Provides subtle depth
- Surface Variant: `#EEEEEE` (Subtle texture)
  - Alternative surface for variety
  - Used for secondary containers
- Splash Background: `#D2E7F9` (rgb(210, 231, 249)) (Soft sky blue)
  - Used for splash screen and loading states
  - Creates a calm, welcoming first impression

#### Text Colors
- Primary Text: `#000000` (Pure black)
  - Main text color
  - Maximum contrast ratio > 21:1 on white background
- Secondary Text: `#1F1F1F` (Rich black)
  - Subtitles and secondary content
  - High contrast ratio > 18:1 for optimal readability

### Dark Mode

#### Primary Colors
- Primary Blue: `#4FC3F7` (rgb(79, 195, 247)) (Bright blue)
  - Brighter variant for dark mode visibility
  - Maintains brand recognition with improved contrast
- Primary Gradient: Linear gradient from `#4FC3F7` to `#29B6F6`
  - Enhanced visibility in dark mode
  - Preserves interactive element emphasis

#### Surface Colors
- Background: `#121212` (Material dark)
  - Dark mode main background
  - Reduces eye strain while maintaining contrast
- Surface: `#1E1E1E` (Rich black)
  - Elevated surfaces in dark mode
  - Provides depth while ensuring readability
- Surface Variant: `#2C2C2C` (Deep grey)
  - Alternative dark surfaces
  - Creates subtle layering
- Splash Background: `#001F3D` (Deep ocean blue)
  - Dark mode splash and loading states
  - Maintains brand consistency

#### Text Colors
- Primary Text: `#FAFAFA` (Off-white)
  - Main text in dark mode
  - Optimal contrast while reducing eye strain
- Secondary Text: `#EEEEEE` (Light grey)
  - Secondary content in dark mode
  - Maintains clear hierarchy with contrast ratio > 18:1

### Semantic Colors
- Success: `#4CAF50` (Material Green)
- Warning: `#FFA000` (Material Amber)
- Error: `#F44336` (Material Red)
- Info: `#2196F3` (Material Blue)

## Typography

### Fonts
- Headings: Poppins
  - Clean, modern, and professional
  - Used for titles and important text
- Body: Inter
  - Highly readable
  - Used for body text and UI elements

### Text Styles
- H1: 32px, Poppins, Bold (700)
- H2: 28px, Poppins, SemiBold (600)
- H3: 24px, Poppins, SemiBold (600)
- Body Large: 16px, Inter, Regular (400)
- Body: 14px, Inter, Regular (400)
- Caption: 12px, Inter, Regular (400)
- Button: 16px, Inter, SemiBold (600)

## Components

### Buttons
- Height: 50px
- Border Radius: 12px
- Primary: Primary Gradient background
- Secondary: Surface color with border
- Text: Secondary text color

### Input Fields
- Height: 50px
- Border Radius: 12px
- Border: 1px solid
- Padding: 16px

### Cards
- Border Radius: 12px
- Elevation: Subtle shadow
- Background: Surface color

## Spacing
- XS: 4px
- SM: 8px
- MD: 16px
- LG: 24px
- XL: 32px
- XXL: 48px

## Component Design

### Video Editing Components
- Timeline Height: 120pt
- Preview Area: 16:9 aspect ratio
- Scrubber: 44pt touch target
- Tool Panel Height: 72pt
- States:
  - Selected: Primary color highlight
  - Active: 2dp elevation
  - Dragging: Scale 1.02

### Common Components
- Height: 44pt (standard), 56pt (prominent)
- Padding: 24pt horizontal, 12pt vertical
- Corner Radius: 8pt (less pronounced than Material)
- States:
  - Default: 1dp elevation
  - Active: 2dp elevation
  - Pressed: Scale 0.98
  - Disabled: 38% opacity

### Input Fields
- Height: 44pt (matching iOS standard)
- Corner Radius: 8pt
- Border: 1pt stroke
- States:
  - Default: Light border
  - Focused: Primary color border
  - Error: Error color border
  - Disabled: 38% opacity

### Cards
- Corner Radius: 12pt
- Elevation: 2dp
- Padding: 16pt
- Clip behavior: Anti-alias
- Optional hover state: +1dp elevation

### Icons
- Size: 24x24pt (standard)
- Weight: 400
- Touch target: Minimum 44x44pt
- States:
  - Default: Secondary text color
  - Active: Primary color
  - Disabled: 38% opacity

## Motion & Animation

### Transitions
- Standard duration: 300ms
- Easing: Swift Out (emphasized)
- Page transitions: Fade through
- Dialog transitions: Scale and fade

### Interactive Feedback
- Button press: 50ms scale down
- Hover: 150ms elevation change
- State changes: 200ms color transition
- Loading states: Smooth infinite animation

## Layout & Spacing

### Grid System
- Base unit: 4pt
- Gutters: 16pt
- Margins: 24pt
- Content width: Max 1200pt

### Spacing Scale
```
xs : 4pt
sm : 8pt
md : 16pt
lg : 24pt
xl : 32pt
2xl: 48pt
3xl: 64pt
```

## Assets & Media

### Logo Usage
- Clear space: 16pt minimum
- Minimum size: 32pt height
- File formats:
  - SVG: Preferred for UI
  - PNG: When vector not possible
  - PDF: Print materials

### Icons & Graphics
- Style: Outlined with 2pt stroke
- Grid: 24x24pt
- Export: SVG with embedded colors

## Accessibility

### Color Contrast
- Text: WCAG 2.1 AA standard
  - Normal text: 4.5:1
  - Large text: 3:1
- Interactive elements: 3:1 minimum

### Touch Targets
- Minimum size: 44x44pt
- Spacing: 8pt minimum

### Text Scaling
- Support up to 200% scaling
- Maintain layout integrity

## Platform-Specific Guidelines

### Android
- Custom-designed components prioritizing video editing
- Support system back gesture
- Handle different pixel densities
- Support dark theme
- Material-inspired components where appropriate:
  - Dialogs
  - Bottom sheets
  - Navigation drawer
  - FAB for primary actions

### iOS/iPadOS
- Custom-designed components matching Android
- Support back swipe gesture
- Respect safe areas
- Support Split View
- Cupertino-inspired components where appropriate:
  - Action sheets
  - Context menus
  - Navigation bars
  - Segmented controls

### Shared Components
- Video timeline
- Preview canvas
- Tool panels
- Effect controls
- Export options
- Project management
All shared components should maintain consistency across platforms while respecting platform-specific interaction patterns.

## Version Control

### Style Updates
- Version: 1.0.0
- Last Updated: [Current Date]
- Changelog: Track all changes
- Review: Quarterly updates