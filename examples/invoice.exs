#!/usr/bin/env elixir

# Example: Generate invoices with Typster
#
# Usage: mix run examples/invoice.exs

# Invoice template with variable binding and calculations
template = """
#set page(width: 8.5in, height: 11in, margin: 1in)
#set text(font: "Linux Libertine", size: 11pt)

#align(center)[
  #text(size: 20pt, weight: "bold")[INVOICE]
]

#v(1em)

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  [
    *From:*\\
    #company_name\\
    #company_address
  ],
  [
    *To:*\\
    #customer_name\\
    #customer_address
  ]
)

#v(2em)

*Invoice Number:* #invoice_number\\
*Date:* #invoice_date\\
*Due Date:* #due_date

#v(2em)

#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  [*Description*], [*Quantity*], [*Rate*], [*Amount*],
  ..items.map(item => (
    item.description,
    str(item.quantity),
    "$" + str(item.rate),
    "$" + str(item.quantity * item.rate)
  )).flatten()
)

#v(1em)

#align(right)[
  *Subtotal:* \\$#subtotal\\
  *Tax (#tax_rate%):* \\$#tax\\
  #line(length: 100pt)\\
  *Total:* \\$#total
]

#v(2em)

#text(size: 9pt, style: "italic")[
  Payment is due within #payment_terms days.\\
  Thank you for your business!
]
"""

# Invoice data
variables = %{
  company_name: "Acme Corporation",
  company_address: "123 Business St\\nSpringfield, IL 62701",
  customer_name: "Wayne Enterprises",
  customer_address: "1 Wayne Tower\\nGotham City, NY 10001",
  invoice_number: "INV-2025-001",
  invoice_date: "October 3, 2025",
  due_date: "November 3, 2025",
  items: [
    %{description: "Consulting Services", quantity: 10, rate: 150.00},
    %{description: "Software License", quantity: 5, rate: 200.00},
    %{description: "Support & Maintenance", quantity: 1, rate: 500.00}
  ],
  subtotal: 3000.00,
  tax_rate: 8.5,
  tax: 255.00,
  total: 3255.00,
  payment_terms: 30
}

# PDF metadata
metadata = %{
  title: "Invoice INV-2025-001",
  author: "Acme Corporation",
  keywords: "invoice, billing"
}

# Generate the invoice
IO.puts("Generating invoice...")

case Typster.render_pdf(template, variables, metadata: metadata) do
  {:ok, pdf} ->
    filename = "invoice_example.pdf"
    File.write!(filename, pdf)
    IO.puts("Invoice generated: #{filename} (#{byte_size(pdf)} bytes)")
    IO.puts("\nVerify PDF metadata with: pdfinfo #{filename}")

  {:error, reason} ->
    IO.puts("Error: #{reason}")
end
