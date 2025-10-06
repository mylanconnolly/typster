# Typster

**Typster** is an Elixir wrapper for the [Typst](https://typst.app) document preparation system, providing powerful and ergonomic functions for rendering Typst templates to PDF, SVG, and PNG formats.

[![CI](https://github.com/mylanconnolly/typster/actions/workflows/ci.yml/badge.svg)](https://github.com/mylanconnolly/typster/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/typster.svg)](https://hex.pm/packages/typster)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/typster)

## Features

- **Multiple Output Formats**: Render to PDF, SVG, or PNG
- **Variable Binding**: Inject Elixir data into templates with deep nesting support
- **Package Support**: Use Typst packages from the official registry
- **PDF Metadata**: Embed title, author, keywords, and more
- **Type-Safe**: Full typespecs for all public functions
- **Fast**: Powered by Rust via NIFs
- **Ergonomic API**: Simple, consistent interface with bang (`!`) variants
- **Well-Tested**: 58 comprehensive tests including property-based testing

## Installation

Add `typster` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:typster, "~> 0.3.2"}
  ]
end
```

Then run:

```bash
mix deps.get
```

**Note**: Precompiled binaries are available for macOS (ARM64/x86_64) and Linux (ARM64/x86_64). If a precompiled binary is not available for your platform, Typster will automatically compile from source, which requires Rust to be installed (see [rustup.rs](https://rustup.rs/)). You can force compilation from source by setting `TYPSTER_BUILD=1`.

## Quick Start

### Simple PDF Rendering

```elixir
# Create a simple template
template = """
#set page(width: 8.5in, height: 11in)
#set text(size: 11pt)

= Hello from Typster!

This is a simple document rendered with Typster.
"""

# Render to PDF
{:ok, pdf} = Typster.render_pdf(template)

# Save to file
File.write!("output.pdf", pdf)

# Or use the convenience function
Typster.render_to_file(template, "output.pdf")
```

### Variable Binding

```elixir
template = """
= Invoice for #customer_name

*Date:* #invoice_date
*Amount:* \\$#amount

Thank you for your business!
"""

variables = %{
  customer_name: "Acme Corp",
  invoice_date: "2025-10-03",
  amount: 1234.56
}

{:ok, pdf} = Typster.render_pdf(template, variables)
```

### Nested Data Structures

```elixir
template = """
= #user.name's Profile

*Email:* #user.email
*Location:* #user.address.city, #user.address.state
"""

variables = %{
  user: %{
    name: "Alice Johnson",
    email: "alice@example.com",
    address: %{
      city: "Portland",
      state: "OR"
    }
  }
}

{:ok, pdf} = Typster.render_pdf(template, variables)
```

### Lists and Iteration

```elixir
template = """
= Shopping List

#for item in items [
  - #item.name: \\$#item.price
]

*Total Items:* #items.len()
"""

variables = %{
  items: [
    %{name: "Apples", price: 3.99},
    %{name: "Bread", price: 2.49},
    %{name: "Milk", price: 4.29}
  ]
}

{:ok, pdf} = Typster.render_pdf(template, variables)
```

### PDF Metadata

```elixir
metadata = %{
  title: "Annual Report 2025",
  author: "Analytics Team",
  description: "Comprehensive performance analysis",
  keywords: "report, analytics, 2025",
  date: "auto"  # Use current date
}

{:ok, pdf} = Typster.render_pdf(template, variables, metadata: metadata)
```

### SVG and PNG Output

```elixir
# Render to SVG (returns list of SVG strings, one per page)
{:ok, svg_pages} = Typster.render_svg(template)

# Render to PNG with custom resolution
{:ok, png_pages} = Typster.render_png(template, %{}, pixel_per_pt: 4.0)

# Save first page
File.write!("page1.png", List.first(png_pages))
```

### Using Typst Packages

```elixir
# Use packages from the Typst registry
template = """
#import "@preview/tiaoma:0.3.0": qrcode

= Contact Information

#qrcode("https://example.com", width: 3cm)
"""

# Packages are automatically downloaded and cached
{:ok, pdf} = Typster.render_pdf(template)

# Use multiple packages together
template = """
#import "@preview/tiaoma:0.3.0": qrcode
#import "@preview/cetz:0.3.2": canvas, draw

= Document with Packages

#qrcode("https://example.com", width: 2cm)

#canvas({
  import draw: *
  rect((0, 0), (3, 2), fill: blue.lighten(80%))
})
"""

{:ok, pdf} = Typster.render_pdf(template)
```

**Package Features:**
- Automatic download from the Typst package registry
- Local caching for fast subsequent renders
- Concurrent download protection with mutex locks
- Support for all packages in the [@preview namespace](https://typst.app/universe)

### Bang Functions

```elixir
# Use bang (!) versions for cleaner code
# (raises Typster.CompileError on failure)

try do
  pdf = Typster.render_pdf!(template, variables)
  File.write!("output.pdf", pdf)
rescue
  e in Typster.CompileError ->
    IO.puts("Compilation failed: #{e.message}")
end
```

## API Reference

### Core Functions

- `Typster.render_pdf(source, variables \\ %{}, opts \\ [])` - Render to PDF
- `Typster.render_svg(source, variables \\ %{}, opts \\ [])` - Render to SVG (multi-page)
- `Typster.render_png(source, variables \\ %{}, opts \\ [])` - Render to PNG (multi-page)
- `Typster.render_to_file(source, path, variables \\ %{}, opts \\ [])` - Save to file

### Bang Variants

- `Typster.render_pdf!(source, variables \\ %{}, opts \\ [])` - Raises on error
- `Typster.render_svg!(source, variables \\ %{}, opts \\ [])` - Raises on error
- `Typster.render_png!(source, variables \\ %{}, opts \\ [])` - Raises on error
- `Typster.render_to_file!(source, path, variables \\ %{}, opts \\ [])` - Raises on error

### Options

All render functions accept the following options:

- `:metadata` - Map of PDF metadata (`%{title:, author:, description:, keywords:, date:}`)
- `:package_paths` - List of local package directories (for custom packages)
- `:pixel_per_pt` - PNG resolution multiplier (default: `2.0`, higher = better quality)

## Examples

See the `examples/` directory for complete working examples:

- `examples/invoice.exs` - Generate invoices with calculations
- `examples/report.exs` - Multi-page reports with charts
- `examples/qrcode.exs` - Generate QR codes using packages
- `examples/reusable_templates.exs` - Reusable template components without filesystem dependencies

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/typster) or can be generated locally:

```bash
mix docs
open doc/index.html
```

## Testing

Run the test suite:

```bash
mix test
```

The test suite includes:
- 42 unit and integration tests
- 9 property-based tests using StreamData
- 9 concurrent rendering tests (thread safety)
- 7 package download and import tests
- Realistic fixtures (invoice, report templates)
- Comprehensive error handling tests

Run concurrent tests separately:
```bash
mix test test/concurrent_test.exs
```

## Performance

Typster uses native Rust code via NIFs for high performance:

- Typical invoice rendering: **< 50ms**
- Multi-page reports: **< 200ms**
- Package downloads are cached locally

## Concurrency

Typster is **fully thread-safe** and designed for concurrent use:

```elixir
# Render multiple documents in parallel
tasks = for i <- 1..10 do
  Task.async(fn ->
    template = get_template(i)
    Typster.render_pdf(template, %{id: i})
  end)
end

results = Task.await_many(tasks)
```

**Tested Performance:**
- 50 concurrent renders: All successful
- 100 concurrent renders: Completed in ~22ms total
- Mixed format rendering (PDF/SVG/PNG): No conflicts

**Thread Safety:**
- Multiple processes can render simultaneously
- Concurrent package downloads are safely handled with mutex locks
- No resource conflicts or race conditions
- Suitable for Phoenix applications with multiple concurrent users

## Typst Resources

- [Typst Documentation](https://typst.app/docs)
- [Typst Package Universe](https://typst.app/universe)
- [Typst Syntax Reference](https://typst.app/docs/reference/syntax/)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Built on [Typst](https://github.com/typst/typst) - A modern typesetting system
- Uses [Rustler](https://github.com/rusterlium/rustler) for Elixir-Rust interop
