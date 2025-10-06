#!/usr/bin/env elixir

# Demonstration of reusable template components without filesystem dependencies
# Use case: 50 letter templates × 50 clients with shared headers/footers/blocks

# Define reusable template components as strings that can be injected
defmodule TemplateComponents do
  # All reusable Typst functions defined once
  def all do
    """
    #let letterhead(company_name, company_address, company_phone) = [
      #set text(size: 10pt)
      #grid(
        columns: (1fr, auto),
        align(left)[
          #text(size: 14pt, weight: "bold")[#company_name]\\
          #company_address\\
          Phone: #company_phone
        ],
        align(right)[
          #rect(width: 2cm, height: 1.5cm, stroke: 0.5pt, fill: gray.lighten(90%))[
            #align(center + horizon)[LOGO]
          ]
        ]
      )
      #line(length: 100%, stroke: 0.5pt)
      #v(0.5cm)
    ]

    #let address_block(recipient_name, recipient_title, recipient_company, recipient_address) = [
      #recipient_name\\
      #recipient_title\\
      #recipient_company\\
      #recipient_address
      #v(1cm)
    ]

    #let date_line(date_str) = [
      #align(right)[#date_str]
      #v(0.5cm)
    ]

    #let reference_number(ref_num) = [
      *Re:* #ref_num
      #v(0.5cm)
    ]

    #let closing_block(closing_phrase, signer_name, signer_title) = [
      #v(1cm)
      #closing_phrase,

      #v(1.5cm)

      #signer_name\\
      #signer_title
    ]

    #let footer_content(company_name, page_num) = [
      #line(length: 100%, stroke: 0.5pt)
      #v(0.3cm)
      #set text(size: 8pt)
      #grid(
        columns: (1fr, 1fr),
        align(left)[#company_name - Confidential],
        align(right)[Page #page_num]
      )
    ]
    """
  end
end

# Example: Define client-specific data (could be from database)
client_data = %{
  company_name: "Acme Legal Services",
  company_address: "123 Law Street, Suite 456\\nNew York, NY 10001",
  company_phone: "(555) 123-4567",
  signer_name: "Jane Smith",
  signer_title: "Senior Partner"
}

# Example: Define recipient data (could be from database)
recipient_data = %{
  recipient_name: "John Doe",
  recipient_title: "CEO",
  recipient_company: "Tech Innovations Inc.",
  recipient_address: "789 Innovation Blvd\\nSan Francisco, CA 94105",
  date: "October 3, 2025",
  reference: "Contract Amendment - Project Alpha"
}

# LETTER TEMPLATE 1: Contract Amendment Notice
# Components are injected at the top, then used throughout
letter_template_1 = """
#{TemplateComponents.all()}

#set page(
  margin: (top: 2.5cm, bottom: 3cm, left: 2.5cm, right: 2.5cm),
  footer: context [
    #footer_content(company_name, str(counter(page).get().first()))
  ]
)

#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: true, leading: 0.65em)

#letterhead(company_name, company_address, company_phone)
#date_line(date)
#address_block(recipient_name, recipient_title, recipient_company, recipient_address)
#reference_number(reference)

Dear #recipient_name,

We are writing to inform you of proposed amendments to the existing contract between
#company_name and #recipient_company.

The following amendments are proposed:

+ *Extension of Term*: The contract term shall be extended by an additional twelve (12) months.

+ *Fee Adjustment*: The monthly service fee shall be adjusted to reflect current market rates.

+ *Scope Modification*: Additional services as detailed in Appendix A shall be incorporated.

We believe these amendments will strengthen our partnership and ensure continued success for both parties.

Please review the attached detailed amendment document and provide your written acknowledgment
within fifteen (15) business days.

#closing_block("Sincerely", signer_name, signer_title)
"""

# LETTER TEMPLATE 2: Payment Reminder
letter_template_2 = """
#{TemplateComponents.all()}

#set page(
  margin: (top: 2.5cm, bottom: 3cm, left: 2.5cm, right: 2.5cm),
  footer: context [
    #footer_content(company_name, str(counter(page).get().first()))
  ]
)

#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: true, leading: 0.65em)

#letterhead(company_name, company_address, company_phone)
#date_line(date)
#address_block(recipient_name, recipient_title, recipient_company, recipient_address)
#reference_number(payment_reference)

Dear #recipient_name,

This letter serves as a friendly reminder regarding Invoice *#invoice_number* dated #invoice_date,
which remains outstanding.

*Invoice Details:*

#table(
  columns: (auto, auto),
  stroke: none,
  [Invoice Number:], [#invoice_number],
  [Invoice Date:], [#invoice_date],
  [Amount Due:], [\\$#amount_due],
  [Due Date:], [#due_date]
)

We kindly request payment within #payment_days business days to avoid any service interruptions.

If payment has already been sent, please disregard this notice and accept our thanks.

#closing_block("Best regards", signer_name, signer_title)
"""

# Generate Letter 1
IO.puts("Generating Contract Amendment Letter...")

variables_1 = Map.merge(client_data, recipient_data)

case Typster.render_pdf(letter_template_1, variables_1) do
  {:ok, pdf} ->
    File.write!("letter_contract_amendment.pdf", pdf)
    IO.puts("Generated: letter_contract_amendment.pdf (#{byte_size(pdf)} bytes)")

  {:error, reason} ->
    IO.puts("Error: #{reason}")
end

# Generate Letter 2 with additional variables
IO.puts("\nGenerating Payment Reminder Letter...")

variables_2 =
  Map.merge(client_data, recipient_data)
  |> Map.merge(%{
    payment_reference: "Payment Reminder - Outstanding Invoice",
    invoice_number: "INV-2025-001",
    invoice_date: "September 3, 2025",
    amount_due: "5,250.00",
    due_date: "September 18, 2025",
    payment_days: "10"
  })

case Typster.render_pdf(letter_template_2, variables_2) do
  {:ok, pdf} ->
    File.write!("letter_payment_reminder.pdf", pdf)
    IO.puts("Generated: letter_payment_reminder.pdf (#{byte_size(pdf)} bytes)")

  {:error, reason} ->
    IO.puts("Error: #{reason}")
end

IO.puts("\n✓ Demonstration complete!")
IO.puts("\nKey Benefits:")
IO.puts("  • All template components defined in Elixir code (no files needed)")
IO.puts("  • Components injected as Typst function definitions")
IO.puts("  • Full reusability across 50+ letter templates")
IO.puts("  • Easy to version control and manage")
IO.puts("  • Can be stored in database, GenServer, or ETS")
IO.puts("\nFor your use case:")
IO.puts("  • Define shared components once in a module")
IO.puts("  • Store client data in database")
IO.puts("  • Store 50 letter templates as strings")
IO.puts("  • Inject components + client data at render time")
