# zugpferd.cr

A Crystal library for generating and parsing **ZUGFeRD 2.x** (Factur-X) e-invoices — the structured XML format mandated by EU Directive 2014/55/EU and German GOBD.

Generates UN/CEFACT CII XML, validates against EN 16931 business rules, and parses CII XML back into domain structs. Validated against the official Mustang CLI (XSD + Schematron).

## Profiles supported

| Profile | Guideline URI |
|---------|--------------|
| MINIMUM | `urn:factur-x.eu:1p0:minimum` |
| BASIC WL | `urn:factur-x.eu:1p0:basicwl` |
| BASIC | `urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic` |
| EN16931 (Comfort) | `urn:cen.eu:en16931:2017` |
| EXTENDED | `urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended` |

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  zugpferd:
    github: zugpferd/zugpferd.cr
```

Then run `shards install`.

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

| Type | Description |
|------|-------------|
| `Invoice` | Top-level document; use `Invoice.build` |
| `ExchangedDocument` | Invoice ID, date, type code, notes |
| `TradeParty` | Seller or buyer with address, tax registrations, contact |
| `TradeAddress` | Postal address (`city` + `country_id` required) |
| `TaxRegistration` | VAT ID (scheme `VA`) or tax number (scheme `FC`) |
| `TradeSettlement` | Currency, taxes, totals, payment means |
| `ApplicableTradeTax` | VAT breakdown entry (calculated amount, basis, rate) |
| `SupplyChainTradeLineItem` | Invoice line with quantity, price, tax |
| `SpecifiedTradeAllowanceCharge` | Header-level or line-level discount/surcharge |
| `Profile` | Enum: `MINIMUM`, `BASIC_WL`, `BASIC`, `EN16931`, `EXTENDED`, `XRECHNUNG` |

## Development

```bash
crystal spec              # unit + compliance tests (103 examples)
make test-integration     # downloads Mustang CLI and runs XSD/Schematron validation
```

`make test-integration` requires Java. It downloads the [Mustang CLI](https://www.mustangproject.org/commandline/) JAR to `vendor/` on first run and validates all generated profiles plus fixture files against the official EN 16931 schemas.

## License

MIT — see [LICENSE](LICENSE).
