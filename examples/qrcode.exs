#!/usr/bin/env elixir

# Example: Generate documents with QR codes using Typst packages
#
# Usage: mix run examples/qrcode.exs

# Template using the tiaoma package for QR codes
template = """
#import "@preview/tiaoma:0.3.0": qrcode, ean

#set page(width: 6in, height: 8in, margin: 0.5in)
#set text(size: 11pt)

= Business Card with QR Code

#grid(
  columns: (1fr, auto),
  gutter: 1em,
  [
    *#name*\\
    #title\\
    #company

    #v(1em)

    📧 #email\\
    📱 #phone\\
    🌐 #website
  ],
  [
    #qrcode(vcard, width: 3cm)
  ]
)

#pagebreak()

= Product Label

*Product:* #product_name\\
*SKU:* #sku\\
*Price:* \\$#price

#v(1em)

#align(center)[
  #ean(barcode, width: 6cm)
]

#v(2em)

#align(center)[
  *Scan for more information:*\\
  #v(0.5em)
  #qrcode(product_url, width: 4cm)
]
"""

# Data for the document
variables = %{
  name: "Alice Johnson",
  title: "Senior Developer",
  company: "Acme Corporation",
  email: "alice@acme.com",
  phone: "+1 (555) 123-4567",
  website: "https://acme.com",
  vcard: "BEGIN:VCARD\nVERSION:3.0\nFN:Alice Johnson\nORG:Acme Corporation\nTEL:+1-555-123-4567\nEMAIL:alice@acme.com\nURL:https://acme.com\nEND:VCARD",
  product_name: "Premium Widget",
  sku: "WDG-001",
  price: 29.99,
  barcode: "012345678905",
  product_url: "https://acme.com/products/premium-widget"
}

IO.puts("Generating document with QR codes and barcodes...")
IO.puts("(This will download the tiaoma package if not cached)")
IO.puts("")

case Typster.render_pdf(template, variables: variables) do
  {:ok, pdf} ->
    filename = "qrcode_example.pdf"
    File.write!(filename, pdf)
    IO.puts("Generated: #{filename} (#{byte_size(pdf)} bytes)")
    IO.puts("\nThe document contains:")
    IO.puts("  - Business card with vCard QR code")
    IO.puts("  - Product label with EAN-13 barcode")
    IO.puts("  - Product info QR code")

  {:error, reason} ->
    IO.puts("Error: #{reason}")
end
