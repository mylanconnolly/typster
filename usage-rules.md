# Typster Usage Rules for LLMs

Typster is an Elixir wrapper for the Typst document preparation system. It provides functions for rendering Typst templates to PDF, SVG, and PNG formats via Rust NIFs.

## Core API

### Main Rendering Functions

```elixir
# PDF rendering (returns single binary)
{:ok, pdf} = Typster.render_pdf(source)

# SVG rendering (returns list of strings, one per page)
{:ok, svg_pages} = Typster.render_svg(source)

# PNG rendering (returns list of binaries, one per page)
{:ok, png_pages} = Typster.render_png(source)

# Save to file (format determined by extension: .pdf, .svg, .png)
:ok = Typster.render_to_file(source, path)
```

### Bang Variants

All functions have `!` versions that raise `Typster.CompileError` on failure:

```elixir
pdf = Typster.render_pdf!(source, variables, opts)
svg_pages = Typster.render_svg!(source, variables, opts)
png_pages = Typster.render_png!(source, variables, opts)
:ok = Typster.render_to_file!(source, path, variables, opts)
```

## Parameters

### Options

**All render functions** accept these options in the `opts` keyword list:

- `:package_paths` - List of local package directory paths (default: `[]`)
- `:metadata` - Map of PDF metadata (PDF only, default: `%{}`)
- `:pixel_per_pt` - PNG resolution multiplier (PNG only, default: `2.0`)
- `:root_path` - Root path for relative paths
- `:variables` - Map of variables for interpolation (explained below)

**Metadata map keys** (all optional, PDF rendering only):
- `:title` - Document title
- `:author` - Author name
- `:description` - Document description
- `:keywords` - Comma-separated keywords
- `:date` - Date string (use `"auto"` for current date)

#### Variables

- Can be maps with atom or string keys
- Supports nested maps and lists for complex data structures
- Numbers, booleans, and strings passed through directly
- Atom values (except `true`, `false`, `nil`) converted to strings
- Structs automatically converted to maps with string keys

```elixir
# Simple variables
variables = %{name: "Alice", year: 2025, active: true}

# Nested data
variables = %{
  user: %{
    name: "Alice",
    address: %{city: "Portland", state: "OR"}
  }
}

# Lists for iteration
variables = %{
  items: [
    %{name: "Apples", price: 3.99},
    %{name: "Bread", price: 2.49}
  ]
}
```

```elixir
# PDF with metadata
Typster.render_pdf(source, %{},
  metadata: %{
    title: "Annual Report",
    author: "Analytics Team",
    keywords: "report, analytics, 2025",
    date: "auto"
  }
)

# PNG with high resolution
Typster.render_png(source, %{}, pixel_per_pt: 4.0)
```

## Typst Template Syntax

### Variable Interpolation

Use `#variable_name` syntax in templates:

```elixir
template = """
= Invoice for #customer_name
*Date:* #invoice_date
*Amount:* $#amount
"""

variables = %{
  customer_name: "Acme Corp",
  invoice_date: "2025-10-03",
  amount: 1234.56
}
```

### Nested Data Access

Use dot notation for nested maps:

```elixir
template = """
= #user.name's Profile
*Email:* #user.email
*Location:* #user.address.city, #user.address.state
"""
```

### Lists and Iteration

Use Typst's `for` loop syntax:

```elixir
template = """
#for item in items [
  - #item.name: $#item.price
]
*Total Items:* #items.len()
"""
```

## Package Support

### Using Typst Packages

Import packages from the `@preview` namespace (Typst package registry):

```elixir
template = """
#import "@preview/tiaoma:0.3.0": qrcode

= Contact Information
#qrcode("https://example.com", width: 3cm)
"""

{:ok, pdf} = Typster.render_pdf(template)
```

**Package behavior:**
- Packages automatically downloaded from Typst registry on first use
- Locally cached for subsequent renders
- Concurrent downloads of same package handled with mutex locks (thread-safe)
- All packages in [@preview namespace](https://typst.app/universe) supported

## Output Formats

### PDF
- Returns single binary
- Supports metadata injection
- Files start with `%PDF` magic bytes

### SVG
- Returns list of strings (one per page)
- Multi-page documents produce multiple SVG strings
- Each page is a complete SVG document

### PNG
- Returns list of binaries (one per page)
- Resolution controlled by `:pixel_per_pt` option
- Higher values = better quality, larger file size

### File Output
- Extension determines format (`.pdf`, `.svg`, `.png`)
- For multi-page SVG/PNG, only first page saved
- Returns `:ok` on success, `{:error, reason}` on failure

## Concurrency

**Typster is fully thread-safe** and optimized for concurrent use:

```elixir
# Render multiple documents in parallel
tasks = for i <- 1..10 do
  Task.async(fn ->
    Typster.render_pdf(template, %{id: i})
  end)
end

results = Task.await_many(tasks)
```

**Performance characteristics:**
- No resource conflicts or race conditions
- Safe for Phoenix applications with multiple concurrent users
- Package downloads synchronized with mutex locks

## Error Handling

### Safe Functions
Return `{:ok, result}` or `{:error, reason}`:

```elixir
case Typster.render_pdf(template, variables) do
  {:ok, pdf} -> File.write("output.pdf", pdf)
  {:error, reason} -> Logger.error("Render failed: #{reason}")
end
```

### Bang Functions
Raise `Typster.CompileError` on failure:

```elixir
try do
  pdf = Typster.render_pdf!(template, variables: variables)
  File.write!("output.pdf", pdf)
rescue
  e in Typster.CompileError ->
    Logger.error("Compilation failed: #{e.message}")
end
```

## Important Notes

1. **Variable keys**: Both atom and string keys work, but are converted to strings internally
2. **Multi-page output**: SVG and PNG return lists; PDF returns single binary
3. **Package caching**: First render with package may be slower due to download
4. **Metadata**: Only applicable to PDF format, ignored for SVG/PNG
5. **Resolution**: Default PNG resolution is 2.0 pixel_per_pt; increase for higher quality
6. **File extension**: `render_to_file/4` determines format from extension
7. **Thread safety**: Safe to use in concurrent contexts without additional synchronization
8. **Rust requirement**: Project requires Rust toolchain to compile NIFs

## Type Specifications

```elixir
@type metadata :: %{
        optional(:title) => String.t(),
        optional(:author) => String.t(),
        optional(:description) => String.t(),
        optional(:keywords) => String.t(),
        optional(:date) => String.t()
      }
@type package_paths :: [String.t()]
@type root_path :: String.t()
@type variables :: map()
@type render_options :: [
        metadata: metadata(),
        package_paths: package_paths(),
        pixel_per_pt: float(),
        root_path: root_path(),
        variables: variables()
      ]

@type pdf_binary :: binary()
@type svg_pages :: [String.t()]
@type png_pages :: [binary()]
```
