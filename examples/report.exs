#!/usr/bin/env elixir

# Example: Generate multi-page reports with Typster
#
# Usage: mix run examples/report.exs

# Multi-page report template
template = """
#set page(width: 8.5in, height: 11in, margin: 1in)
#set text(size: 11pt)
#set heading(numbering: "1.")

#align(center)[
  #text(size: 24pt, weight: "bold")[#title]
  #v(0.5em)
  #text(size: 12pt)[#subtitle]
  #v(0.5em)
  #text(size: 10pt, style: "italic")[
    Author: #author\\
    Date: #date
  ]
]

#pagebreak()

= Executive Summary

#summary

#v(1em)

= Key Metrics

#for metric in metrics [
  - *#metric.name:* #metric.value
]

#pagebreak()

= Detailed Findings

#for finding in findings [
  == #finding.title

  #finding.content

  #if finding.at("details", default: none) != none [
    #for detail in finding.details [
      - #detail
    ]
  ]

  #v(1em)
]

#pagebreak()

= Conclusion

#conclusion

#v(2em)

#text(size: 9pt, style: "italic")[
  This report was generated automatically using Typster.
]
"""

# Report data
variables = %{
  title: "Q3 2025 Performance Report",
  subtitle: "Analytics & Insights",
  author: "Analytics Team",
  date: "October 3, 2025",
  summary: """
  The third quarter of 2025 showed exceptional growth across all key performance
  indicators. Revenue increased 45% year-over-year, while customer satisfaction
  scores reached an all-time high.
  """,
  metrics: [
    %{name: "Revenue Growth", value: "+45%"},
    %{name: "Customer Satisfaction", value: "4.8/5"},
    %{name: "Market Share", value: "23%"},
    %{name: "Employee Retention", value: "94%"}
  ],
  findings: [
    %{
      title: "Revenue Performance",
      content: "Q3 revenue exceeded projections by 15%, driven primarily by new customer acquisition.",
      details: [
        "New customers: 1,234 (+67% YoY)",
        "Average contract value: $12,500 (+15% YoY)",
        "Churn rate: 2.3% (-1.2% YoY)"
      ]
    },
    %{
      title: "Customer Satisfaction",
      content: "NPS score improved to 72, with particularly strong feedback on product quality.",
      details: [
        "Support response time: < 2 hours",
        "Feature adoption rate: 78%",
        "Renewal rate: 96%"
      ]
    },
    %{
      title: "Operational Efficiency",
      content: "Process improvements led to a 30% reduction in operational costs."
    }
  ],
  conclusion: """
  Q3 2025 represents our strongest quarter to date. The combination of revenue
  growth, customer satisfaction, and operational efficiency positions us well
  for continued success in Q4 and beyond.
  """
}

# Generate reports in multiple formats
IO.puts("Generating multi-page report in multiple formats...")
IO.puts("")

# PDF
case Typster.render_pdf(template, variables) do
  {:ok, pdf} ->
    File.write!("report_example.pdf", pdf)
    IO.puts("PDF: report_example.pdf (#{byte_size(pdf)} bytes)")

  {:error, reason} ->
    IO.puts("PDF Error: #{reason}")
end

# SVG (multi-page)
case Typster.render_svg(template, variables) do
  {:ok, svg_pages} ->
    IO.puts("SVG: #{length(svg_pages)} pages")

    svg_pages
    |> Enum.with_index()
    |> Enum.each(fn {svg, idx} ->
      filename = "report_example_page_#{idx + 1}.svg"
      File.write!(filename, svg)
      IO.puts("   Saved: #{filename}")
    end)

  {:error, reason} ->
    IO.puts("SVG Error: #{reason}")
end

# PNG (first page only, high resolution)
case Typster.render_png(template, variables, pixel_per_pt: 4.0) do
  {:ok, png_pages} ->
    first_page = List.first(png_pages)
    File.write!("report_example_page_1.png", first_page)
    IO.puts("PNG: report_example_page_1.png (#{byte_size(first_page)} bytes, high-res)")

  {:error, reason} ->
    IO.puts("PNG Error: #{reason}")
end

IO.puts("\nReport generation complete!")
