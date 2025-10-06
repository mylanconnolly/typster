#set page(width: 8.5in, height: 11in, margin: 1in)
#set text(font: "Linux Libertine", size: 11pt)

#align(center)[
  #text(size: 20pt, weight: "bold")[Invoice]
]

#v(1em)

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  [
    *From:*\
    #company_name\
    #company_address
  ],
  [
    *To:*\
    #customer_name\
    #customer_address
  ]
)

#v(2em)

*Invoice Number:* #invoice_number\
*Date:* #invoice_date\
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
  *Subtotal:* \$#subtotal\
  *Tax (#tax_rate%):* \$#tax\
  *Total:* \$#total
]

#v(2em)

#text(size: 9pt, style: "italic")[
  Payment is due within #payment_terms days.\
  Thank you for your business!
]
