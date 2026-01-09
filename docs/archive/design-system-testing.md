# Design System Testing Guide

This guide explains how to test new components against the AgentEngine design system to ensure consistency and compliance.

## Testing Framework Overview

The AgentEngine design system testing includes:

1. **Storybook** - Visual component documentation and testing
2. **Vitest** - Unit tests for design token compliance
3. **Chromatic** - Visual regression testing
4. **ESLint Rules** - Automated design token enforcement

## Running Tests

### Component Tests
```bash
# Run all tests
npm test

# Run design token validation tests
npm run test:design-tokens

# Run component-specific tests
npm run test:components

# Run tests with UI
npm run test:ui
```

### Visual Testing
```bash
# Start Storybook locally
npm run storybook

# Build Storybook for production
npm run build-storybook

# Run Chromatic visual tests
npm run chromatic
```

## Creating Component Stories

Create a `.stories.tsx` file for each component:

```typescript
import type { Meta, StoryObj } from '@storybook/react';
import { YourComponent } from './your-component';

const meta: Meta<typeof YourComponent> = {
  title: 'Design System/Components/YourComponent',
  component: YourComponent,
  parameters: {
    layout: 'centered',
    docs: {
      description: {
        component: 'Component description highlighting design token usage.',
      },
    },
  },
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    children: 'Example content',
  },
};

export const DesignTokenValidation: Story = {
  render: () => (
    <div className="space-y-4">
      <YourComponent 
        style={{ 
          padding: 'var(--space-4)',
          borderRadius: 'var(--radius-lg)',
          color: 'hsl(var(--color-primary))'
        }}
      >
        Direct token usage
      </YourComponent>
      <YourComponent className="p-4 rounded-lg text-primary">
        Tailwind classes
      </YourComponent>
    </div>
  ),
};
```

## Writing Component Tests

Create unit tests that validate design token compliance:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { YourComponent } from '../your-component';
import { validateComponentTokenUsage } from '../../utils/design-token-validator';

describe('YourComponent - Design System Compliance', () => {
  it('should use design token classes', () => {
    render(<YourComponent />);
    const component = screen.getByRole('...');
    
    // Verify design system classes
    expect(component).toHaveClass('component-padding-md');
    expect(component).toHaveClass('rounded-lg');
  });

  it('should pass design token validation', () => {
    const componentCode = `
      <YourComponent 
        style={{ 
          padding: 'var(--space-4)',
          color: 'hsl(var(--color-primary))'
        }}
      />
    `;
    
    const validation = validateComponentTokenUsage(componentCode);
    expect(validation.isValid).toBe(true);
  });
});
```

## Design Token Validation

The system automatically checks for:

### ❌ Hardcoded Values to Avoid
```css
/* Spacing */
padding: 16px; /* Use var(--space-4) */
margin: 24px;  /* Use var(--space-6) */

/* Colors */
color: #3b82f6;     /* Use hsl(var(--color-primary)) */
background: #f8fafc; /* Use hsl(var(--color-background)) */

/* Border radius */
border-radius: 8px; /* Use var(--radius-lg) */

/* Font sizes */
font-size: 16px; /* Use var(--text-base) */
```

### ✅ Correct Design Token Usage
```css
/* Direct token usage */
padding: var(--space-4);
color: hsl(var(--color-primary));
border-radius: var(--radius-lg);
font-size: var(--text-base);

/* Tailwind classes (mapped to tokens) */
.p-4 { padding: var(--space-4); }
.text-primary { color: hsl(var(--color-primary)); }
.rounded-lg { border-radius: var(--radius-lg); }
```

## Available Design Tokens

### Spacing
- **Standard**: `--space-1` to `--space-96`
- **Golden Ratio**: `--space-phi-xs` to `--space-phi-4xl`
- **Component**: `--component-padding-xs` to `--component-padding-xl`

### Colors
- **Semantic**: `--color-primary`, `--color-secondary`, `--color-background`
- **States**: `--color-success`, `--color-warning`, `--color-destructive`
- **UI**: `--color-border`, `--color-input`, `--color-muted`

### Typography
- **Sizes**: `--text-xs` to `--text-9xl`
- **Families**: `--font-sans`, `--font-display`, `--font-mono`
- **Weights**: `--font-normal` to `--font-black`

## ESLint Integration

The custom ESLint plugin automatically detects design token violations:

```json
{
  "rules": {
    "design-tokens/no-hardcoded-values": "warn",
    "design-tokens/prefer-design-tokens": "warn"
  }
}
```

## Visual Regression Testing

Chromatic automatically captures visual changes:

1. **Push to GitHub** - Triggers visual testing workflow
2. **Review Changes** - Chromatic shows visual diffs
3. **Approve/Reject** - Accept legitimate changes or fix regressions

## Best Practices

1. **Always use design tokens** instead of hardcoded values
2. **Create stories for all variants** of your component
3. **Test responsive behavior** at different viewport sizes
4. **Validate accessibility** with Storybook a11y addon
5. **Document token usage** in component stories
6. **Run tests before committing** to catch violations early

## Troubleshooting

### Common Issues

**ESLint not detecting plugin:**
- Ensure `eslint-plugin-design-tokens.js` is in project root
- Restart your editor/ESLint server

**Storybook not loading styles:**
- Check that `design-tokens.css` is imported in `.storybook/preview.ts`
- Verify CSS is building correctly

**Vitest tests failing:**
- Ensure `@testing-library/jest-dom` is set up in test config
- Check that design token mocks are correct in `setup.ts`

**Chromatic not running:**
- Add `CHROMATIC_PROJECT_TOKEN` to GitHub secrets
- Ensure workflow has proper permissions

For more details, see the component examples in the Storybook documentation.