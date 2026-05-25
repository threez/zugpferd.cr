require "../spec_helper"

describe Zugpferd::Validator do
  describe "MINIMUM profile" do
    it "passes with minimum required fields" do
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM)
      expect_raises(Exception) { }.should be_nil rescue nil
      # Should not raise
      invoice.to_xml.should contain("CrossIndustryInvoice")
    end

    it "fails without seller name" do
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM)
      invoice.seller = Zugpferd::TradeParty.new("")
      expect_raises(Zugpferd::ValidationError) { invoice.to_xml }
        .violations.any?(&.includes?("BT-27")).should be_true
    end

    it "fails without invoice id" do
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM)
      invoice.document = Zugpferd::ExchangedDocument.new(id: "", issue_date: Time.utc)
      expect_raises(Zugpferd::ValidationError) { invoice.to_xml }
        .violations.any?(&.includes?("BT-1")).should be_true
    end

    it "fails without taxes" do
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM)
      s = invoice.settlement
      invoice.settlement = Zugpferd::TradeSettlement.new(
        currency_code: s.currency_code,
        taxes: [] of Zugpferd::ApplicableTradeTax,
        line_total_amount: s.line_total_amount,
        tax_basis_total_amount: s.tax_basis_total_amount,
        tax_total_amount: s.tax_total_amount,
        grand_total_amount: s.grand_total_amount,
        due_payable_amount: s.due_payable_amount
      )
      expect_raises(Zugpferd::ValidationError) { invoice.to_xml }
        .violations.any?(&.includes?("BG-23")).should be_true
    end
  end

  describe "BASIC profile" do
    it "requires seller address" do
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::BASIC)
      invoice.seller = Zugpferd::TradeParty.new("Muster GmbH",
        tax_registrations: [Zugpferd::TaxRegistration.new(Zugpferd::TaxRegistration::SchemeID::VA, "DE123")],
        electronic_address: "a@b.de")
      expect_raises(Zugpferd::ValidationError) { invoice.to_xml }
        .violations.any?(&.includes?("Seller postal address")).should be_true
    end

    it "requires at least one line item" do
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::BASIC)
      invoice.line_items.clear
      expect_raises(Zugpferd::ValidationError) { invoice.to_xml }
        .violations.any?(&.includes?("BG-25")).should be_true
    end
  end

  describe "EN16931 profile" do
    it "requires buyer address" do
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      invoice.buyer = Zugpferd::TradeParty.new("Kunde AG",
        electronic_address: "buyer@example.de")
      expect_raises(Zugpferd::ValidationError) { invoice.to_xml }
        .violations.any?(&.includes?("Buyer postal address")).should be_true
    end

    it "requires payment means code" do
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      s = invoice.settlement
      invoice.settlement = Zugpferd::TradeSettlement.new(
        currency_code: s.currency_code,
        taxes: s.taxes,
        line_total_amount: s.line_total_amount,
        tax_basis_total_amount: s.tax_basis_total_amount,
        tax_total_amount: s.tax_total_amount,
        grand_total_amount: s.grand_total_amount,
        due_payable_amount: s.due_payable_amount
      )
      expect_raises(Zugpferd::ValidationError) { invoice.to_xml }
        .violations.any?(&.includes?("BT-81")).should be_true
    end
  end
end
