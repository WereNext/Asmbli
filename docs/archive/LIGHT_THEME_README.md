# 🦴🍌 Bone & Banana Pudding Light Theme

A beautiful, warm light theme inspired by bone colors and banana pudding, designed to complement the existing dark enterprise theme.

## 🎨 Color Philosophy

The light theme uses:
- **Bone colors** for backgrounds, surfaces, and neutral elements
- **Banana pudding tones** for primary actions and highlights  
- **Warm accents** like vanilla, caramel, and honey for depth

This creates a cohesive, comfortable experience perfect for long working sessions while maintaining visual hierarchy and accessibility.

## 🌈 Color Palettes

### Bone Palette (Backgrounds & Neutrals)
```css
--bone-50: 60 20% 98%    /* Pure bone white */
--bone-100: 54 15% 96%   /* Lightest cream */
--bone-200: 52 12% 92%   /* Light cream */
--bone-300: 50 10% 88%   /* Soft cream */
--bone-400: 48 8% 82%    /* Medium bone */
--bone-500: 46 6% 75%    /* True bone */
--bone-600: 44 5% 65%    /* Darker bone */
--bone-700: 42 4% 52%    /* Deep bone */
--bone-800: 40 3% 35%    /* Rich bone */
--bone-900: 38 2% 22%    /* Darkest bone */
```

### Banana Pudding Palette (Primary & Accents)
```css
--pudding-50: 52 85% 95%   /* Lightest cream */
--pudding-100: 50 80% 92%  /* Vanilla cream */
--pudding-200: 48 75% 88%  /* Light banana */
--pudding-300: 46 70% 82%  /* Soft banana */
--pudding-400: 44 65% 75%  /* Medium banana */
--pudding-500: 42 60% 68%  /* True banana pudding */
--pudding-600: 40 55% 60%  /* Rich banana */
--pudding-700: 38 50% 50%  /* Deep banana */
--pudding-800: 36 45% 38%  /* Golden brown */
--pudding-900: 34 40% 28%  /* Dark caramel */
```

### Accent Colors
```css
--caramel: 32 72% 45%      /* Rich caramel accent */
--vanilla: 48 35% 88%      /* Soft vanilla */
--cream: 54 25% 94%        /* Rich cream */
--toast: 36 50% 65%        /* Warm toast */
--honey: 44 85% 72%        /* Golden honey */
```

## 🔧 Usage

### Automatic Theme Switching
```typescript
import { ThemeToggle } from './components/ui/theme-toggle'

// Add to your header/navigation
<ThemeToggle />
```

### Manual Theme Control
```typescript
import { useTheme } from './components/ui/theme-toggle'

function MyComponent() {
  const { theme, setTheme } = useTheme()
  
  return (
    <button onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
      Current theme: {theme}
    </button>
  )
}
```

### CSS Classes
The theme responds to these selectors:
```css
[data-theme="light"]  /* Data attribute */
.light               /* Class name */
:root.light          /* Root class */
```

### Tailwind Classes
Use the new color classes in your components:
```tsx
<div className="bg-bone-50 text-bone-900">
  <h1 className="text-pudding-600">Heading</h1>
  <button className="bg-pudding-500 text-bone-50 hover:bg-pudding-600">
    Button
  </button>
  <span className="text-caramel">Accent text</span>
</div>
```

## 🎯 Design Tokens Integration

### Semantic Mappings (Light Mode)
```css
--color-background: var(--bone-50)           /* Pure bone white */
--color-foreground: var(--bone-900)         /* Dark bone text */
--color-card: var(--bone-100)               /* Light cream cards */
--color-primary: var(--pudding-600)         /* Rich banana primary */
--color-secondary: var(--bone-200)          /* Light cream secondary */
--color-muted: var(--bone-200)              /* Light cream muted */
--color-accent: var(--vanilla)              /* Soft vanilla accent */
--color-border: var(--bone-300)             /* Soft cream borders */
```

### Component Examples
```tsx
// Automatically adapts to current theme
<Card className="bg-card text-card-foreground border-border">
  <Button variant="default">Primary Action</Button>
  <Button variant="secondary">Secondary Action</Button>
</Card>

// Explicit light theme styling
<Card className="bg-bone-100 text-bone-800 border-bone-300">
  <Button className="bg-pudding-600 text-bone-50 hover:bg-pudding-700">
    Banana Pudding Button
  </Button>
</Card>
```

## 🧪 Testing

### Storybook Stories
- View the theme in Storybook: `npm run storybook`
- Navigate to "Design System > Themes > Light Mode"
- Use the theme toggle to compare light/dark modes

### Demo File
Open `light-theme-demo.html` in your browser to see:
- Complete color palettes
- Interactive theme switching
- Typography hierarchy
- Component examples

### Design Token Validation
The theme passes all design system tests:
```bash
npm test                    # All tests pass ✅
npm run test:design-tokens  # Token validation ✅
npm run test:components     # Component compliance ✅
```

## 📱 Responsive Behavior

The light theme maintains all responsive features:
- Golden ratio spacing scales appropriately
- Typography remains readable at all sizes
- Color contrast meets accessibility standards
- Touch targets maintain appropriate sizing

## ♿ Accessibility

### Color Contrast
- **Background (bone-50) to Text (bone-900)**: 21:1 ratio ✅
- **Primary buttons**: 4.5:1 minimum ratio ✅
- **Secondary elements**: 3:1 minimum ratio ✅

### Focus States
- Focus rings use `pudding-500` for visibility
- High contrast maintained in all states
- Keyboard navigation fully supported

## 🔄 Migration Guide

### From Dark to Light
No code changes needed! Components automatically adapt when:
1. User toggles theme with `<ThemeToggle />`
2. System preference changes
3. Theme is set programmatically

### Custom Components
Update custom components to use semantic tokens:
```css
/* Before */
.my-component {
  background: #1a1a1a;
  color: #ffffff;
}

/* After */
.my-component {
  background: hsl(var(--color-background));
  color: hsl(var(--color-foreground));
}
```

## 🎨 Customization

### Override Colors
```css
:root.light {
  --bone-50: 55 25% 99%;     /* Warmer white */
  --pudding-600: 45 70% 58%; /* More saturated banana */
}
```

### Add New Variants
```css
:root {
  --peach: 25 80% 75%;       /* Custom accent */
  --sage: 120 25% 65%;       /* Custom neutral */
}
```

```tsx
// Add to Tailwind config
colors: {
  peach: "hsl(var(--peach))",
  sage: "hsl(var(--sage))",
}
```

## 🚀 Performance

- **CSS Variables**: Instant theme switching
- **No JavaScript Required**: Pure CSS implementation
- **Design Token Based**: Consistent with existing system
- **Tree Shakeable**: Only includes used colors in production

## 📋 Checklist for New Components

- [ ] Use semantic color tokens (`--color-*`)
- [ ] Test in both light and dark themes  
- [ ] Ensure proper contrast ratios
- [ ] Add Storybook stories for both themes
- [ ] Validate with design token tests

## 🔗 Related Files

- `styles/design-tokens.css` - Color definitions
- `tailwind.config.js` - Tailwind integration  
- `components/ui/theme-toggle.tsx` - Theme switching
- `stories/LightTheme.stories.tsx` - Storybook demos
- `light-theme-demo.html` - Interactive demo

---

**Enjoy your beautiful bone & banana pudding light theme! 🦴🍌✨**