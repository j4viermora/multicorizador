---
name: flowbite-tailwind
description: Build and style the UI with Flowbite + Tailwind CSS 4 in this Rails 7+/Hotwire app. Use for any frontend work — buttons, cards, tables, badges, alerts, stats, forms, dropdowns, modals, tabs, the Flowbite datepicker, and general styling. Enforces the project's Flowbite-only convention (no DaisyUI/Bootstrap) and the reusable component classes in app/assets/tailwind/application.css. Invoke when creating, editing, styling, migrating, or reviewing UI/components/pages, or when wiring Flowbite JS via CDN.
---

This skill documents how to build UI in the **Ruka** app. The stack is **Tailwind CSS 4** (compiled by `tailwindcss-rails`) + **Flowbite** (JS via CDN) + Hotwire (Turbo + Stimulus). There is **no Node/webpack** step.

## The one rule

**Flowbite is the ONLY styling system.** Never reintroduce DaisyUI (removed), Bootstrap, Material, or any other CSS framework. If you find a DaisyUI class (`btn-primary` with a plugin, `bg-base-100`, `text-error`, `data-theme`, `card-body` coming from a plugin, `menu`, `navbar-start`, `dropdown dropdown-end`, `rounded-box`, `input-bordered`, `badge-success` from a plugin, etc.), migrate it (see "Migration cheat-sheet" below).

How styling is organised:
- **`app/assets/tailwind/application.css`** — the Tailwind entry. Contains `@import "tailwindcss";` and a `@layer components { ... }` block that defines **reusable component classes** (`.btn`, `.card`, `.badge`, `.table`, `.stat`, `.alert`, `.input`, `.label-text`, `.loading`, `.link`, etc.) built with `@apply` in Flowbite's design language. These are OUR classes, not a third-party plugin. **Reuse them.** To add a new reusable pattern, extend this layer rather than pasting long utility strings into every view.
- **`app/assets/stylesheets/application.css`** — plain CSS (Propshaft) for bespoke component CSS (e.g. the quote-wizard `wizard-*` classes). Plain CSS only — no `@apply` here (it is not processed by Tailwind).
- **Brand/primary colour = `teal`** (Tailwind `teal-600/700`), matching the wizard's `--wz-teal`. Success=`green`, Warning=`amber`, Error=`red`, Info=`blue`.

## CDN wiring (already in the layouts)

- **`flowbite.turbo.min.js`** — interactive components (dropdowns, modals, tabs, accordions, collapse). Use the `.turbo` build: it re-initialises components on Turbo navigation. Source from jsDelivr, pinned (e.g. `flowbite@2.5.2`).
- **`flowbite-datepicker`** — the Flowbite datepicker. Loaded as standalone CSS (`dist/css/datepicker.min.css`, self-contained calendar styling) + full JS bundle (`dist/js/datepicker-full.min.js`, includes all locales). Used through a Stimulus controller, not the bare `datepicker` attribute.

Do not load plain `flowbite.min.js` (it does not re-init on Turbo Drive navigations).

## Icons: Tabler only

**Always use Tabler Icons** (`<i class="ti ti-<name>"></i>`). Never inline hand-pasted SVGs, Heroicons, or other sets. Search https://tabler.io/icons for the most semantically accurate name.

## Components — canonical patterns

### Buttons — use the component classes
```html
<%= link_to "Nuevo", new_x_path, class: "btn btn-primary" %>
<%= f.button :submit, "Guardar", class: "btn btn-primary" %>
<button class="btn btn-outline">Cancel</button>
<button class="btn btn-ghost">Ghost</button>
<button class="btn btn-success">Approve</button>
<button class="btn btn-error">Delete</button>
<button class="btn btn-neutral">Dark</button>
<button class="btn btn-primary btn-sm">Small</button>
<button class="btn btn-primary btn-xs">Tiny</button>
```
Variants: `primary` (teal), `success` (green), `error` (red), `neutral` (gray-800), `ghost`, `outline`. Sizes: `btn-sm`, `btn-xs`, `btn-lg`.

### Card
```html
<div class="card">
  <div class="card-body">
    <h2 class="card-title">Title</h2>
    <p>Body…</p>
  </div>
</div>
```

### Table
```html
<div class="overflow-x-auto bg-white shadow rounded-lg">
  <table class="table table-zebra">
    <thead><tr><th>Col</th></tr></thead>
    <tbody><tr><td>…</td></tr></tbody>
  </table>
</div>
```
`.table` styles th/td; `.table-zebra` adds zebra rows.

### Badge
```html
<span class="badge badge-success">Active</span>
```
Variants: `success`, `error`, `warning`, `info`, `primary`, `secondary`, `ghost`. Use with a helper that returns the variant name, e.g. `badge badge-<%= quote_status_color(status) %>`. Add `badge-lg` for a larger badge.

### Alert
```html
<div class="alert alert-success"><%= notice %></div>
```
Variants: `success`, `error`, `info`, `warning`.

### Stat (dashboard cards)
```html
<div class="grid grid-cols-1 md:grid-cols-3 gap-6">
  <div class="stat">
    <div class="stat-title">Cotizaciones</div>
    <div class="stat-value text-teal-600"><%= count %></div>
    <div class="stat-desc"><%= link_to "Nueva", x_path, class: "link" %></div>
  </div>
</div>
```

### Forms — simple_form with Flowbite wrappers
**Always** `simple_form_for` + `f.input`. Wrappers (`:default`, `:boolean`, `:auth`, `:select`) already emit Flowbite input/label classes. Inputs get `.input`; labels get `.label-text`; errors get `.input-error`/red text.
```html
<%= f.input :email, label: "Correo" %>
<%= f.input :role, collection: User.roles.keys, include_blank: false %>
<%= f.input :active, as: :boolean %>
```
Form container pattern: `<%= simple_form_for ..., html: { class: "bg-white p-6 rounded-lg shadow max-w-lg" } do |f| %>`.

### Datepicker (Flowbite) — always, never `as: :date`
Date fields use the `DatepickerInput` simple_form input (`as: :datepicker`) which renders a text field wired to the `datepicker` Stimulus controller (es locale, `yyyy-mm-dd` value so Rails parses it natively, autohide, week starts Monday).
```html
<%= f.input :departure_date, as: :datepicker %>
```
Do **not** use `as: :date` (renders 3 `<select>`s) or `<input type="date">`.

### Navbar + dropdown (Flowbite JS)
```html
<nav class="bg-white border-b border-gray-200">
  <div class="max-w-7xl mx-auto px-4 flex items-center justify-between h-16">
    <%= link_to "Ruka", root_path, class: "text-xl font-bold text-gray-900" %>
    <div class="flex items-center gap-1">
      <%= link_to "Dashboard", x_path, class: "px-3 py-2 text-sm text-gray-700 rounded hover:bg-gray-100" %>
    </div>
    <button id="user-menu" data-dropdown-toggle="user-dropdown" class="...">Menu</button>
    <div id="user-dropdown" class="z-50 hidden bg-white divide-y divide-gray-100 rounded-lg shadow w-44">
      <ul class="py-2 text-sm text-gray-700">
        <li><%= link_to "Perfil", edit_user_registration_path, class: "block px-4 py-2 hover:bg-gray-100" %></li>
      </ul>
    </div>
  </div>
</nav>
```
`data-dropdown-toggle="<id>"` is handled by `flowbite.turbo.min.js`.

### Other Flowbite JS components
Modals (`data-modal-target`/`data-modal-toggle`), tabs (`data-tabs-toggle`), accordion (`data-accordion-target`), collapse (`data-collapse-toggle`) — all powered by `flowbite.turbo.min.js`. See https://flowbite.com/docs/ .

## Migration cheat-sheet (DaisyUI → Flowbite/Tailwind)

| DaisyUI | Replace with |
|---|---|
| `bg-base-100` | `bg-white` |
| `bg-base-200` | `bg-gray-50` |
| `text-base-content` | `text-gray-900` |
| `text-base-content/{n}` | `text-gray-500` |
| `border-base-200` | `border-gray-200` |
| `text-error` / `border-error` | `text-red-600` / `border-red-300` |
| `text-warning` / `bg-warning/10` | `text-amber-600` / `bg-amber-50` |
| `text-success` | `text-green-600` |
| `text-primary` / `bg-primary` | `text-teal-600` / `bg-teal-600` |
| `text-primary-content` | `text-white` |
| `link` / `link-primary` | `.link` / `.link-primary` (component classes) |
| `<html data-theme="light">` | `<html>` (drop it) |
| `rounded-box` | `rounded-lg` |
| `menu` / `menu-horizontal` | plain nav links (see navbar) |
| `dropdown` + `tabindex` | Flowbite `data-dropdown-toggle` |
| `avatar` / `btn-circle` | Flowbite avatar markup |
| `loading loading-spinner` | `.loading` (component class) |
| `input input-bordered` / `label label-text` | `.input` / `.label-text` (component classes via simple_form) |
| `table table-zebra` | `.table .table-zebra` (component classes) |
| `stat` / `stat-*` | `.stat` / `.stat-title` / `.stat-value` / `.stat-desc` |

When migrating, prefer reusing the project's component classes over inlining huge utility strings.

## Gotchas
- `@apply` only works inside `app/assets/tailwind/application.css` (the Tailwind-compiled entry) and `@layer components`. Never use `@apply` in `app/assets/stylesheets/*.css` (Propshaft, plain CSS).
- Flowbite components are JS-driven; if one stops working after a Turbo navigation, you are using the plain `flowbite.min.js` instead of the `.turbo` build.
- The datepicker injects its calendar via JS with its own self-contained CSS — do not try to restyle it with utility classes; theme it via the `flowbite-datepicker` options if needed.
