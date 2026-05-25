require "spec"
require "../src/zugpferd"
require "./support/mustang_validator"

module SpecHelper
  FIXTURE_DIR = File.join(__DIR__, "fixtures")

  def self.fixture(profile : String, filename : String) : String
    path = File.join(FIXTURE_DIR, profile, filename)
    File.read(path)
  end

  def self.fixture_files(profile : String) : Array(String)
    dir = File.join(FIXTURE_DIR, profile)
    return [] of String unless Dir.exists?(dir)
    Dir[File.join(dir, "*.xml")]
  end

  # Returns a minimal valid invoice for the given profile, used across specs.
  def self.minimal_invoice(profile : Zugpferd::Profile = Zugpferd::Profile::MINIMUM) : Zugpferd::Invoice
    net = BigDecimal.new("100.00")
    vat = BigDecimal.new("19.00")

    Zugpferd::Invoice.build(profile) do |inv|
      inv.document = Zugpferd::ExchangedDocument.new(
        id: "INV-001",
        issue_date: Time.utc(2025, 1, 15),
        buyer_reference: profile == Zugpferd::Profile::XRECHNUNG ? "LEITWEG-001" : nil
      )

      addr = Zugpferd::TradeAddress.new("Berlin", "DE", postcode: "10115", line_one: "Musterstr. 1")

      inv.seller = Zugpferd::TradeParty.new(
        "Muster GmbH",
        address: addr,
        tax_registrations: [Zugpferd::TaxRegistration.new(Zugpferd::TaxRegistration::SchemeID::VA, "DE123456789")],
        electronic_address: "seller@example.de"
      )

      inv.buyer = Zugpferd::TradeParty.new(
        "Kunde AG",
        address: addr,
        electronic_address: "buyer@example.de"
      )

      taxes = [
        Zugpferd::ApplicableTradeTax.new(
          calculated_amount: vat,
          basis_amount: net,
          category_code: Zugpferd::ApplicableTradeTax::CategoryCode::S,
          rate_applicable_percent: BigDecimal.new("19.00")
        ),
      ]

      inv.settlement = Zugpferd::TradeSettlement.new(
        currency_code: "EUR",
        taxes: taxes,
        line_total_amount: net,
        tax_basis_total_amount: net,
        tax_total_amount: vat,
        grand_total_amount: net + vat,
        due_payable_amount: net + vat,
        payment_means_code: "58",
        payee_iban: "DE89370400440532013000",
        # BR-CO-25: due date required when due payable amount > 0
        due_date: Time.utc(2025, 2, 14)
      )

      # BR-FX-EN-04: delivery date (or invoicing period) required for BASIC+
      if profile.at_least?(Zugpferd::Profile::BASIC)
        inv.delivery_date = Time.utc(2025, 1, 15)
      end

      if profile.at_least?(Zugpferd::Profile::BASIC)
        inv.add_line_item Zugpferd::SupplyChainTradeLineItem.new(
          position: 1,
          name: "Consulting",
          billed_quantity: BigDecimal.new("1"),
          unit_code: "HUR",
          net_price: net,
          tax_category_code: Zugpferd::ApplicableTradeTax::CategoryCode::S,
          tax_rate_percent: BigDecimal.new("19.00")
        )
      end
    end
  end
end
