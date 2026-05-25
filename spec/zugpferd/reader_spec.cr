require "../spec_helper"

describe Zugpferd::Reader do
  # ── Layer 1: Round-trip (Generator → Reader) ──────────────────────────────

  describe "round-trip via Generator then Reader" do
    Zugpferd::Profile.each do |profile|
      it "round-trips #{profile} minimal invoice" do
        original = SpecHelper.minimal_invoice(profile)
        xml = original.to_xml
        parsed = Zugpferd::Reader.from_xml(xml)

        parsed.profile.should eq(original.profile)
        parsed.document.id.should eq(original.document.id)
        parsed.document.issue_date.should eq(original.document.issue_date)
        parsed.document.type_code.should eq(original.document.type_code)
        parsed.seller.name.should eq(original.seller.name)
        parsed.buyer.name.should eq(original.buyer.name)
        parsed.settlement.currency_code.should eq(original.settlement.currency_code)
        parsed.settlement.grand_total_amount.should eq(original.settlement.grand_total_amount)
        parsed.settlement.due_payable_amount.should eq(original.settlement.due_payable_amount)
        parsed.line_items.size.should eq(original.line_items.size)
      end
    end

    it "round-trips seller tax registration" do
      original = SpecHelper.minimal_invoice(Zugpferd::Profile::BASIC)
      parsed = Zugpferd::Reader.from_xml(original.to_xml)
      parsed.seller.tax_registrations.size.should eq(1)
      parsed.seller.tax_registrations.first.scheme_id.should eq(Zugpferd::TaxRegistration::SchemeID::VA)
      parsed.seller.tax_registrations.first.id.should eq("DE123456789")
    end

    it "round-trips seller electronic address" do
      original = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      parsed = Zugpferd::Reader.from_xml(original.to_xml)
      parsed.seller.electronic_address.should eq("seller@example.de")
    end

    it "round-trips seller postal address" do
      original = SpecHelper.minimal_invoice(Zugpferd::Profile::BASIC)
      parsed = Zugpferd::Reader.from_xml(original.to_xml)
      parsed.seller.address.should_not be_nil
      addr = parsed.seller.address.as(Zugpferd::TradeAddress)
      addr.city.should eq("Berlin")
      addr.country_id.should eq("DE")
      addr.postcode.should eq("10115")
      addr.line_one.should eq("Musterstr. 1")
    end

    it "round-trips VAT tax breakdown" do
      original = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      parsed = Zugpferd::Reader.from_xml(original.to_xml)
      parsed.settlement.taxes.size.should eq(1)
      tax = parsed.settlement.taxes.first
      tax.category_code.should eq(Zugpferd::ApplicableTradeTax::CategoryCode::S)
      tax.rate_applicable_percent.should eq(BigDecimal.new("19.00"))
      tax.calculated_amount.should eq(BigDecimal.new("19.00"))
    end

    it "round-trips payment means with IBAN" do
      original = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      parsed = Zugpferd::Reader.from_xml(original.to_xml)
      parsed.settlement.payment_means_code.should eq("58")
      parsed.settlement.payee_iban.should eq("DE89370400440532013000")
    end

    it "round-trips line items" do
      original = SpecHelper.minimal_invoice(Zugpferd::Profile::BASIC)
      parsed = Zugpferd::Reader.from_xml(original.to_xml)
      item = parsed.line_items.first
      item.position.should eq(1)
      item.name.should eq("Consulting")
      item.unit_code.should eq("HUR")
      item.billed_quantity.should eq(BigDecimal.new("1"))
      item.net_price.should eq(BigDecimal.new("100.00"))
      item.tax_category_code.should eq(Zugpferd::ApplicableTradeTax::CategoryCode::S)
      item.tax_rate_percent.should eq(BigDecimal.new("19.00"))
    end

    it "round-trips invoice notes" do
      invoice = Zugpferd::Invoice.build(Zugpferd::Profile::MINIMUM) do |inv|
        inv.document = Zugpferd::ExchangedDocument.new(
          id: "NOTE-1", issue_date: Time.utc(2025, 3, 1),
          notes: ["First note", "Second note"])
        inv.seller = SpecHelper.minimal_invoice.seller
        inv.buyer = SpecHelper.minimal_invoice.buyer
        inv.settlement = SpecHelper.minimal_invoice.settlement
      end
      parsed = Zugpferd::Reader.from_xml(invoice.to_xml)
      parsed.document.notes.should eq(["First note", "Second note"])
    end

    it "round-trips buyer_order_reference" do
      original = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      original.buyer_order_reference = "PO-999"
      parsed = Zugpferd::Reader.from_xml(original.to_xml)
      parsed.buyer_order_reference.should eq("PO-999")
    end

    it "round-trips delivery date" do
      original = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      original.delivery_date = Time.utc(2025, 2, 28)
      parsed = Zugpferd::Reader.from_xml(original.to_xml)
      parsed.delivery_date.should eq(Time.utc(2025, 2, 28))
    end

    it "round-trips payee_name / AccountName" do
      s = SpecHelper.minimal_invoice.settlement
      settlement = Zugpferd::TradeSettlement.new(
        currency_code: s.currency_code,
        taxes: s.taxes,
        line_total_amount: s.line_total_amount,
        tax_basis_total_amount: s.tax_basis_total_amount,
        tax_total_amount: s.tax_total_amount,
        grand_total_amount: s.grand_total_amount,
        due_payable_amount: s.due_payable_amount,
        payment_means_code: "58",
        payee_iban: "DE89370400440532013000",
        payee_name: "Max Mustermann"
      )
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      invoice.settlement = settlement
      parsed = Zugpferd::Reader.from_xml(invoice.to_xml)
      parsed.settlement.payee_name.should eq("Max Mustermann")
    end

    it "round-trips line-item allowance charges" do
      ac = Zugpferd::SpecifiedTradeAllowanceCharge.new(
        charge: false,
        actual_amount: BigDecimal.new("10.00"),
        tax_category_code: Zugpferd::ApplicableTradeTax::CategoryCode::S,
        reason: "Discount"
      )
      item = Zugpferd::SupplyChainTradeLineItem.new(
        position: 1,
        name: "Consulting",
        billed_quantity: BigDecimal.new("1"),
        unit_code: "HUR",
        net_price: BigDecimal.new("100.00"),
        tax_category_code: Zugpferd::ApplicableTradeTax::CategoryCode::S,
        tax_rate_percent: BigDecimal.new("19.00"),
        allowance_charges: [ac]
      )
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::BASIC)
      invoice.line_items = [item]
      parsed = Zugpferd::Reader.from_xml(invoice.to_xml)
      parsed.line_items.first.allowance_charges.size.should eq(1)
      parsed.line_items.first.allowance_charges.first.reason.should eq("Discount")
      parsed.line_items.first.allowance_charges.first.actual_amount.should eq(BigDecimal.new("10.00"))
    end

    it "round-trips payment terms note and due date" do
      s = SpecHelper.minimal_invoice.settlement
      settlement = Zugpferd::TradeSettlement.new(
        currency_code: s.currency_code,
        taxes: s.taxes,
        line_total_amount: s.line_total_amount,
        tax_basis_total_amount: s.tax_basis_total_amount,
        tax_total_amount: s.tax_total_amount,
        grand_total_amount: s.grand_total_amount,
        due_payable_amount: s.due_payable_amount,
        payment_means_code: "58",
        due_date: Time.utc(2025, 4, 30),
        payment_terms_note: "Zahlbar innerhalb 30 Tage"
      )
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931)
      invoice.settlement = settlement
      parsed = Zugpferd::Reader.from_xml(invoice.to_xml)
      parsed.settlement.payment_terms_note.should eq("Zahlbar innerhalb 30 Tage")
      parsed.settlement.due_date.should eq(Time.utc(2025, 4, 30))
    end
  end

  # ── Layer 2: Fixture files ─────────────────────────────────────────────────

  describe "fixture files" do
    it "parses MINIMUM_Einfach.xml" do
      xml = SpecHelper.fixture("minimum", "MINIMUM_Einfach.xml")
      inv = Zugpferd::Reader.from_xml(xml)
      inv.profile.should eq(Zugpferd::Profile::MINIMUM)
      inv.document.id.should eq("RE-2024-001")
      inv.document.type_code.should eq("380")
      inv.seller.name.should eq("Muster GmbH")
      inv.buyer.name.should eq("Kunde AG")
      inv.settlement.currency_code.should eq("EUR")
      inv.settlement.grand_total_amount.should eq(BigDecimal.new("119.00"))
      inv.settlement.due_payable_amount.should eq(BigDecimal.new("119.00"))
      inv.line_items.should be_empty
    end

    it "parses BASIC-WL_Einfach.xml" do
      xml = SpecHelper.fixture("basic_wl", "BASIC-WL_Einfach.xml")
      inv = Zugpferd::Reader.from_xml(xml)
      inv.profile.should eq(Zugpferd::Profile::BASIC_WL)
      inv.seller.address.try(&.city).should eq("Berlin")
      inv.settlement.payee_iban.should eq("DE89370400440532013000")
      inv.line_items.should be_empty
    end

    it "parses BASIC_Einfach.xml with one line item" do
      xml = SpecHelper.fixture("basic", "BASIC_Einfach.xml")
      inv = Zugpferd::Reader.from_xml(xml)
      inv.profile.should eq(Zugpferd::Profile::BASIC)
      inv.line_items.size.should eq(1)
      item = inv.line_items.first
      item.name.should eq("Consulting")
      item.unit_code.should eq("HUR")
      item.billed_quantity.should eq(BigDecimal.new("1.0000"))
      inv.settlement.payee_iban.should eq("DE89370400440532013000")
    end

    it "parses factur-x_EN16931.xml with multiple line items (short URI)" do
      xml = SpecHelper.fixture("en16931", "factur-x_EN16931.xml")
      inv = Zugpferd::Reader.from_xml(xml)
      # The fixture uses the short-form URI "urn:cen.eu:en16931:2017"
      inv.profile.should eq(Zugpferd::Profile::EN16931)
      inv.document.id.should eq("RE-20201121/508")
      inv.line_items.size.should eq(3)
      inv.settlement.taxes.size.should eq(2)
      inv.seller.name.should eq("Bei Spiel GmbH")
      inv.buyer.name.should eq("Theodor Est")
      inv.delivery_date.should eq(Time.utc(2020, 11, 10))
      inv.settlement.due_date.should eq(Time.utc(2020, 12, 12))
      inv.settlement.payee_iban.should eq("DE88200800000970375700")
      inv.settlement.payee_bic.should eq("COBADEFFXXX")
      inv.settlement.grand_total_amount.should eq(BigDecimal.new("571.04"))
      # buyer_reference from ApplicableHeaderTradeAgreement
      inv.document.buyer_reference.should eq("AB321")
    end

    it "parses EXTENDED_Einfach.xml" do
      xml = SpecHelper.fixture("extended", "EXTENDED_Einfach.xml")
      inv = Zugpferd::Reader.from_xml(xml)
      inv.profile.should eq(Zugpferd::Profile::EXTENDED)
      inv.line_items.size.should be > 0
      inv.settlement.allowance_charges.size.should be > 0
    end

    it "parses payee_name (AccountName) from factur-x_EN16931.xml" do
      xml = SpecHelper.fixture("en16931", "factur-x_EN16931.xml")
      inv = Zugpferd::Reader.from_xml(xml)
      inv.settlement.payee_name.should eq("Max Mustermann")
    end

    it "parses line-item allowance charges from EXTENDED_Einfach.xml" do
      xml = SpecHelper.fixture("extended", "EXTENDED_Einfach.xml")
      inv = Zugpferd::Reader.from_xml(xml)
      items_with_charges = inv.line_items.select { |item| !item.allowance_charges.empty? }
      items_with_charges.size.should be > 0
    end
  end

  # ── Layer 3: Error cases ───────────────────────────────────────────────────

  describe "error handling" do
    it "raises ParseError on empty input" do
      expect_raises(Exception) { Zugpferd::Reader.from_xml("") }
    end

    it "raises ParseError on unknown profile URI" do
      xml = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
        .sub("urn:factur-x.eu:1p0:minimum", "urn:unknown:custom:profile")
      expect_raises(Zugpferd::ParseError) { Zugpferd::Reader.from_xml(xml) }
    end

    it "raises ParseError when invoice ID is missing" do
      xml = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
        .sub("<ram:ID>INV-001</ram:ID>", "")
      expect_raises(Zugpferd::ParseError) { Zugpferd::Reader.from_xml(xml) }
    end

    it "raises ParseError when TaxBasisTotalAmount is missing" do
      xml = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
        .sub(/<ram:TaxBasisTotalAmount>[^<]+<\/ram:TaxBasisTotalAmount>/, "")
      expect_raises(Zugpferd::ParseError) { Zugpferd::Reader.from_xml(xml) }
    end
  end

  # ── Layer 4: parse_profile unit tests ─────────────────────────────────────

  describe ".parse_profile" do
    it "maps each profile's own guideline_id back to itself" do
      Zugpferd::Profile.each do |profile|
        Zugpferd::Reader.parse_profile(profile.guideline_id).should eq(profile)
      end
    end

    it "recognises the short-form EN16931 URI from real-world fixtures" do
      Zugpferd::Reader.parse_profile("urn:cen.eu:en16931:2017")
        .should eq(Zugpferd::Profile::EN16931)
    end

    it "raises ParseError for truly unknown URIs" do
      expect_raises(Zugpferd::ParseError) do
        Zugpferd::Reader.parse_profile("urn:completely:unknown")
      end
    end
  end
end
