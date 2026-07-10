#import "@preview/cades:0.3.1": qr-code
#let data = toml("data/invoice.toml")
#let company_info = toml("data/company_info.toml")



#set align(center)
#set table.hline(stroke: 0.5pt + black)
#set grid.hline(stroke: 0.5pt + black)
#set table(
  inset: 5pt,
  stroke: none,
  align: horizon,
)
#show table: set text(features: ("tnum",))
#set text(size: 10pt, font: "Iosevka Aile")

#show title: set text(size: 2em)

#title[Factuur]

#let format_currency(d, digits: 2) = {
  calc.round(decimal(d + .001), digits: digits)
}

#let pretty_iban(iban: str) = {
  let cleaned = iban.replace(" ", "")
  let chunks = ()
  let i = 0
  while i < cleaned.len() {
    let end = calc.min(i + 4, cleaned.len())
    chunks.push(cleaned.slice(i, end))
    i += 4
  }
  chunks.join(" ")
}

#let eqp-qr-data(
  name: none,
  iban: str,
  amount: decimal, // number, e.g. 12.30
  bic: none, // optional
  reference: none, // structured remittance info (isolated reference)
  purpose: none, // optional purpose code, e.g. "GDDS"
  info: none, // unstructured remittance info (use instead of reference)
) = {
  let lines = (
    "BCD",
    "002",
    "1",
    "SCT",
    if bic != none { bic } else { "" },
    name,
    iban,
    "EUR" + str(format_currency(amount)),
    if purpose != none { purpose } else { "" },
    if reference != none { reference } else { "" },
    if info != none { info } else { "" },
  )

  // Trailing empty optional fields can be dropped
  while lines.len() > 8 and lines.last() == "" {
    lines = lines.slice(0, lines.len() - 1)
  }

  lines.join("\n")
}

#let payment-info(height: 10%, name: str, iban: str) = align(horizon, rect(
  height: height,
  stroke: (top: 0.5pt, bottom: 0.5pt),
  fill: gray.lighten(70%),
  grid(
    columns: 2,
    align: (right + horizon, left + horizon),
    inset: 10pt,
    [Eigenaar:], [*#name*],
    [IBAN:], [*#{ pretty_iban(iban: iban) }*],
  ),
))

#grid(
  columns: 2,
  rows: 1pt,
  align: (right, left),
  gutter: (10pt, 20pt),
  [Factuurnummer:], strong[#data.id],
  [Factuurdatum:], strong[#data.date_posted.display()],
)

#v(5%)

#block(width: 80%)[
  // adresgegevens
  #columns(2)[
    #align(left)[
      #strong[#data.customer.name]

      #data.customer.address.join([\ ])
    ]

    #colbreak()
    #align(right)[
      #block[
        #align(left)[
          #strong[#company_info.name]

          #company_info.address \
          KvK: #company_info.kvk \
          BTW: #company_info.tax_number
        ]
      ]
    ]
  ]
]


#v(10%)

#block(width: 100%)[

  #table(
    columns: (auto, 1fr, auto, 11%, 11%),
    align: (left, left, right, right, right),
    stroke: none,
    table.hline(),
    table.header([*Datum*], [*Omschrijving*], [*Aantal*], align(center)[*Prijs* \ (€)], align(center)[*Totaal* \ (€)]),
    table.hline(),
    ..data
      .entries
      .map(entry => (
        [#entry.date.display()],
        [#entry.description],
        [#entry.quantity],
        [#format_currency(entry.unit_price)],
        [#format_currency(entry.amount)],
      ))
      .flatten(),
    table.hline(),
  )

  #align(right)[
    #table(
      columns: 2,
      stroke: none,
      inset: (x, y) => (
        right: if x == 0 { 10pt } else { 0pt },
        top: 5pt,
        bottom: 5pt,
        left: 3pt,
      ),
      [Subtotaal: \ ],
      [#format_currency(data.subtotal) €],
      [BTW 21%:],
      [#format_currency(data.tax) €],
      table.hline(),
      table.cell(strong[Totaal:], fill: gray.lighten(70%)),
      table.cell(strong[#format_currency(data.total) €], fill: gray.lighten(70%)),
      table.hline(),
    )
  ]
]

#v(5%)

#align(left)[
  _Gelieve het bedrag voor
  #strong[#{ data.date_posted + duration(weeks: 4) }.display() ]
  over te maken naar de volgende bankrekening. \
  U kunt de QR-code scannen met uw bankapp._

]


#v(10pt)

#stack(
  dir: ltr,
  spacing: 10pt,
  payment-info(height: 10%, name: company_info.name, iban: company_info.bank_account),
  qr-code(
    eqp-qr-data(
      name: company_info.name,
      iban: company_info.bank_account,
      amount: data.total,
      info: company_info.name + " factuur " + data.id,
    ),
    error-correction: "M",
    height: 10%,
  ),
)


#v(10pt)
#align(left)[_Bedankt voor de goede samenwerking._]
