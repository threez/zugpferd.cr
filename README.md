# zugpferd.cr

A Crystal library for generating and parsing **ZUGFeRD 2.x** (Factur-X) e-invoices — the structured XML format mandated by EU Directive 2014/55/EU and German GOBD.

Generates UN/CEFACT CII XML, validates against EN 16931 business rules, parses CII XML back into domain structs, and optionally embeds the XML into a PDF/A-3b file. Validated against the official Mustang CLI (XSD + Schematron).

## Profiles supported

- **MINIMUM** — `urn:factur-x.eu:1p0:minimum`
- **BASIC WL** — `urn:factur-x.eu:1p0:basicwl`
- **BASIC** — `urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic`
- **EN16931 (Comfort)** — `urn:cen.eu:en16931:2017`
- **EXTENDED** — `urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended`

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  zugpferd:
    github: zugpferd/zugpferd.cr
```

Then run `shards install`.

### PDF/A-3b embedding (optional)

PDF embedding requires [libharu](http://libharu.org/) (system package) and the `hpdf` shard. Add it to your `shard.yml`:

```yaml
dependencies:
  zugpferd:
    github: zugpferd/zugpferd.cr
  hpdf:
    github: threez/hpdf.cr
    version: ~> 0.9.10
```

Then opt in with a separate require:

```crystal
require "zugpferd"
require "zugpferd/pdf"
```

## Usage

### Generating an invoice

```crystal
require "zugpferd"

invoice = Zugpferd::Invoice.build(Zugpferd::Profile::EN16931) do |b|
  b.document = Zugpferd::ExchangedDocument.new(
    id: "INV-2025-001",
    issue_date: Time.utc(2025, 1, 15)
  )

  b.seller = Zugpferd::TradeParty.new(
    "Muster GmbH",
    address: Zugpferd::TradeAddress.new("Berlin", "DE",
      postcode: "10115", line_one: "Musterstr. 1"),
    tax_registrations: [
      Zugpferd::TaxRegistration.new(
        Zugpferd::TaxRegistration::SchemeID::VA, "DE123456789")
    ],
    electronic_address: "seller@example.de"
  )

  b.buyer = Zugpferd::TradeParty.new(
    "Kunde AG",
    address: Zugpferd::TradeAddress.new("Hamburg", "DE"),
    electronic_address: "buyer@example.de"
  )

  b.delivery_date = Time.utc(2025, 1, 15)

  b.add_line_item Zugpferd::SupplyChainTradeLineItem.new(
    position: 1,
    name: "Consulting",
    billed_quantity: BigDecimal.new("8"),
    unit_code: "HUR",           # UN/ECE Rec 20: HUR = hour
    net_price: BigDecimal.new("150.00"),
    tax_category_code: Zugpferd::ApplicableTradeTax::CategoryCode::S,
    tax_rate_percent: BigDecimal.new("19.00")
  )

  net   = BigDecimal.new("1200.00")
  vat   = BigDecimal.new("228.00")

  b.settlement = Zugpferd::TradeSettlement.new(
    currency_code: "EUR",
    taxes: [
      Zugpferd::ApplicableTradeTax.new(
        calculated_amount: vat,
        basis_amount: net,
        category_code: Zugpferd::ApplicableTradeTax::CategoryCode::S,
        rate_applicable_percent: BigDecimal.new("19.00")
      )
    ],
    line_total_amount:     net,
    tax_basis_total_amount: net,
    tax_total_amount:      vat,
    grand_total_amount:    net + vat,
    due_payable_amount:    net + vat,
    payment_means_code:    "58",   # SEPA credit transfer
    payee_iban:            "DE89370400440532013000",
    due_date:              Time.utc(2025, 2, 14)
  )
end

xml = invoice.to_xml   # validates then serialises
File.write("invoice.xml", xml)
```

### Parsing an invoice

```crystal
require "zugpferd"

xml = File.read("invoice.xml")
inv = Zugpferd::Reader.from_xml(xml)

puts inv.profile                          # => EN16931
puts inv.document.id                      # => "INV-2025-001"
puts inv.seller.name                      # => "Muster GmbH"
puts inv.settlement.grand_total_amount    # => 1428.00
puts inv.line_items.size                  # => 1
```

### Embedding XML into a PDF/A-3b file

Requires the optional `hpdf` dependency and `require "zugpferd/pdf"` (see Installation above).

```crystal
require "zugpferd"
require "zugpferd/pdf"

xml = invoice.to_xml

Zugpferd::PdfEmbed.create(xml, "invoice.pdf") do |doc|
  page = doc.add_page
  # draw invoice layout using the Hpdf::Doc API...
end
```

`PdfEmbed.create` sets up PDF/A-3b conformance (XMP metadata, sRGB output intent, Factur-X extension namespace) and attaches `factur-x.xml` before saving.

### Validation

`Invoice#to_xml` runs the built-in validator automatically. To validate without generating XML:

```crystal
begin
  Zugpferd::Validator.new(invoice).validate!
rescue Zugpferd::ValidationError => e
  e.violations.each { |v| puts v }
end
```

## Key types

- `Invoice` — top-level document; use `Invoice.build`
- `ExchangedDocument` — invoice ID, date, type code, notes
- `TradeParty` — seller or buyer with address, tax registrations, contact
- `TradeAddress` — postal address (`city` + `country_id` required)
- `TaxRegistration` — VAT ID (scheme `VA`) or tax number (scheme `FC`)
- `TradeSettlement` — currency, taxes, totals, payment means
- `ApplicableTradeTax` — VAT breakdown entry (calculated amount, basis, rate)
- `SupplyChainTradeLineItem` — invoice line with quantity, price, tax
- `SpecifiedTradeAllowanceCharge` — header-level or line-level discount/surcharge
- `Profile` — enum: `MINIMUM`, `BASIC_WL`, `BASIC`, `EN16931`, `EXTENDED`, `XRECHNUNG`
- `PdfEmbed` — embeds CII XML into a PDF/A-3b file (`require "zugpferd/pdf"`)

## Development

```bash
crystal spec              # unit + compliance tests
make spec-integration     # downloads Mustang CLI and runs XSD/Schematron + PDF/A-3b validation
```

`make spec-integration` requires Java. It downloads the [Mustang CLI](https://www.mustangproject.org/commandline/) JAR to `vendor/` on first run and validates all generated profiles plus fixture files against the official EN 16931 schemas.

## License

MIT — see [LICENSE](LICENSE).
