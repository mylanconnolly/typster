defmodule Typster.IntegrationTest do
  @moduledoc """
  Integration tests using realistic templates with complex variable binding.
  """

  use ExUnit.Case

  describe "invoice template" do
    setup do
      template = File.read!("test/fixtures/invoice.typ")

      variables = %{
        company_name: "Acme Corp",
        company_address: "123 Main St\nSpringfield, IL 62701",
        customer_name: "Wayne Enterprises",
        customer_address: "1 Wayne Tower\nGotham City, NY 10001",
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

      %{template: template, variables: variables}
    end

    test "renders invoice to PDF", %{template: template, variables: variables} do
      assert {:ok, pdf} = Typster.render_pdf(template, variables: variables)
      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF")
      # Invoice should be reasonable size
      assert byte_size(pdf) > 2000
    end

    test "renders invoice with metadata", %{template: template, variables: variables} do
      metadata = %{
        title: "Invoice INV-2025-001",
        author: "Acme Corp Billing System",
        keywords: "invoice, billing, acme"
      }

      assert {:ok, pdf} =
               Typster.render_pdf(template, variables: variables, metadata: metadata)

      assert is_binary(pdf)
    end

    test "renders invoice to SVG", %{template: template, variables: variables} do
      assert {:ok, svg_pages} = Typster.render_svg(template, variables: variables)
      assert is_list(svg_pages)
      assert length(svg_pages) == 1
      # Invoice SVG should be reasonable size
      assert byte_size(List.first(svg_pages)) > 1000
    end

    test "renders invoice to PNG", %{template: template, variables: variables} do
      assert {:ok, png_pages} = Typster.render_png(template, variables: variables)
      assert is_list(png_pages)
      assert length(png_pages) == 1
    end
  end

  describe "report template" do
    setup do
      template = File.read!("test/fixtures/report.typ")

      variables = %{
        title: "Annual Performance Report",
        subtitle: "Fiscal Year 2025",
        author: "Analytics Team",
        date: "October 3, 2025",
        summary: "This report summarizes our key performance indicators for FY2025.",
        introduction: "The year 2025 marked significant growth across all departments.",
        findings: [
          %{
            title: "Revenue Growth",
            content: "Revenue increased by 45% compared to previous year.",
            metrics: [
              "Q1 Revenue: $2.5M",
              "Q2 Revenue: $3.1M",
              "Q3 Revenue: $3.8M",
              "Q4 Revenue: $4.2M"
            ]
          },
          %{
            title: "Customer Satisfaction",
            content: "Customer satisfaction scores improved across all metrics.",
            metrics: [
              "NPS Score: 72",
              "CSAT: 4.5/5",
              "Retention Rate: 94%"
            ]
          },
          %{
            title: "Operational Efficiency",
            content: "Process improvements led to significant cost savings."
          }
        ],
        conclusion: "FY2025 exceeded expectations in all key areas.",
        appendix: "Additional charts and data tables available upon request."
      }

      %{template: template, variables: variables}
    end

    test "renders multi-page report to PDF", %{template: template, variables: variables} do
      assert {:ok, pdf} = Typster.render_pdf(template, variables: variables)
      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF")
      # Multi-page report should be substantial
      assert byte_size(pdf) > 3000
    end

    test "renders report to multi-page SVG", %{template: template, variables: variables} do
      assert {:ok, svg_pages} = Typster.render_svg(template, variables: variables)
      assert is_list(svg_pages)
      # Report has pagebreaks, so should be multiple pages
      assert length(svg_pages) >= 2
    end

    test "renders report with metadata", %{template: template, variables: variables} do
      metadata = %{
        title: "Annual Performance Report FY2025",
        author: "Analytics Team",
        description: "Comprehensive annual performance analysis",
        keywords: "report, analytics, performance, 2025"
      }

      assert {:ok, pdf} =
               Typster.render_pdf(template, variables: variables, metadata: metadata)

      assert is_binary(pdf)
    end
  end

  describe "package integration" do
    @tag :packages
    test "renders document with remote package (QR code)" do
      template = """
      #import "@preview/tiaoma:0.3.0": qrcode

      #set page(width: 200pt, height: 200pt)

      = QR Code Test

      #qrcode("https://example.com")
      """

      assert {:ok, pdf} = Typster.render_pdf(template)
      assert is_binary(pdf)
      assert byte_size(pdf) > 1000
    end

    @tag :packages
    test "renders document with cetz plotting package" do
      template = """
      #import "@preview/cetz:0.3.2": canvas, draw

      #set page(width: 300pt, height: 300pt)

      = Chart Example

      #canvas({
        import draw: *
        circle((0, 0), radius: 1)
        rect((-2, -2), (2, 2))
      })
      """

      assert {:ok, pdf} = Typster.render_pdf(template)
      assert is_binary(pdf)
    end
  end

  describe "stress tests" do
    test "handles large documents" do
      template = """
      #set page(width: 8.5in, height: 11in)
      = Large Document Test

      #for i in range(100) [
        == Section #(i + 1)
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        #if calc.rem(i, 5) == 4 [
          #pagebreak()
        ]
      ]
      """

      assert {:ok, pdf} = Typster.render_pdf(template)
      assert is_binary(pdf)
      # Should produce a substantial document
      assert byte_size(pdf) > 10_000
    end

    test "handles deeply nested data structures" do
      template = """
      = Organization Chart
      #org.name
      Department: #org.department.name
      Manager: #org.department.manager.name
      Team Lead: #org.department.manager.reports.lead.name
      """

      variables = %{
        org: %{
          name: "TechCorp",
          department: %{
            name: "Engineering",
            manager: %{
              name: "Alice Johnson",
              reports: %{
                lead: %{
                  name: "Bob Smith"
                }
              }
            }
          }
        }
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables: variables)
      assert is_binary(pdf)
    end

    test "handles lists with many items" do
      template = """
      = Product List
      #for product in products [
        - #product.name: \\$#product.price
      ]
      """

      products =
        for i <- 1..50 do
          %{name: "Product #{i}", price: i * 10.0}
        end

      variables = %{products: products}

      assert {:ok, pdf} = Typster.render_pdf(template, variables: variables)
      assert is_binary(pdf)
    end
  end
end
