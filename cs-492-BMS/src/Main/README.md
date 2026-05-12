# Bookstore Management System — Godot 4 Scene Structure

## Folder layout

```
bookstore/
├── scenes/
│   ├── Main.tscn                  ← Root scene — open this in Godot
│   └── pages/
│       ├── Dashboard.tscn
│       ├── Catalog.tscn
│       ├── AddEditBook.tscn
│       ├── Sales.tscn
│       ├── Customers.tscn
│       └── Reports.tscn
├── scripts/
│   ├── Main.gd                    ← Navigation controller
│   └── pages/
│       ├── Dashboard.gd
│       ├── Catalog.gd
│       ├── AddEditBook.gd
│       ├── Sales.gd
│       ├── Customers.gd
│       └── Reports.gd
└── themes/
	└── BookstoreTheme.tres        ← Shared theme (edit in Godot Theme editor)
```

## How navigation works

`Main.gd` owns navigation. It:
1. Connects every sidebar `Button`'s `pressed` signal
2. Hides all page nodes under `Pages/`
3. Shows only the target page
4. Updates the top bar title label

Child pages can trigger navigation by calling:
```gdscript
# Walk up to Main and call navigate_to()
get_parent().get_parent().get_parent().get_parent().navigate_to("catalog")
```
Or better — add an autoload singleton so any script can call `Nav.go("catalog")`.

## How to set up in Godot

1. Copy this entire folder into your Godot 4 project's `res://` directory.
2. Open **Project Settings → Application → Run → Main Scene** and set it to `res://scenes/Main.tscn`.
3. Open `res://themes/BookstoreTheme.tres` in the **Theme editor** and style to match the mockup.
4. Run the project — sidebar navigation should work immediately.

## Next steps (build out page by page)

- **Data layer**: Create an Autoload singleton (`res://scripts/BookStore.gd`) that holds your books/customers arrays and exposes add/update/delete methods. Each page script reads from and writes to that singleton.
- **Persistence**: Use `FileAccess` or `SQLite` (via GDExtension) to save data between sessions.
- **Dashboard charts**: Replace `ProgressBar` genre bars with a custom `Control` that uses `_draw()` for proper bar charts.
- **Theme**: Polish `BookstoreTheme.tres` — set `StyleBoxFlat` panels with `border_color = Color("#E0DED8")`, `border_width_* = 1`, `corner_radius_* = 8`, `bg_color = Color("#FFFFFF")`.
