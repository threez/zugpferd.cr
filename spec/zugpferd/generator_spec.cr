require "../spec_helper"

describe Zugpferd::Generator do
  describe "MINIMUM profile" do
    it "produces well-formed XML with correct root element" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
      doc = XML.parse(xml_str)
      doc.first_element_child.try(&.name).should eq("CrossIndustryInvoice")
    end

    it "embeds the correct MINIMUM profile guideline ID" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
      xml_str.should contain("urn:factur-x.eu:1p0:minimum")
    end

    it "includes invoice number" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
      xml_str.should contain("INV-001")
    end

    it "formats issue date as YYYYMMDD with format 102" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
      xml_str.should contain("20250115")
      xml_str.should contain(%[format="102"])
    end

    it "includes seller and buyer names" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
      xml_str.should contain("Muster GmbH")
      xml_str.should contain("Kunde AG")
    end

    it "includes monetary totals" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM).to_xml
      xml_str.should contain("119.00") # grand total
    end
  end

  describe "EN16931 profile" do
    it "includes line items" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931).to_xml
      xml_str.should contain("IncludedSupplyChainTradeLineItem")
      xml_str.should contain("Consulting")
    end

    it "embeds EN16931 guideline URI" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931).to_xml
      xml_str.should contain("en16931")
    end

    it "includes VAT tax breakdown" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931).to_xml
      xml_str.should contain("ApplicableTradeTax")
      xml_str.should contain("19.00")
    end

    it "includes payment means with IBAN" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931).to_xml
      xml_str.should contain("DE89370400440532013000")
    end
  end

  describe "invoice type code" do
    it "defaults to 380 (commercial invoice)" do
      xml_str = SpecHelper.minimal_invoice.to_xml
      xml_str.should contain("<ram:TypeCode>380</ram:TypeCode>")
    end
  end

  describe "VAT category code" do
    it "renders S (standard rate) correctly" do
      xml_str = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931).to_xml
      xml_str.should contain("<ram:CategoryCode>S</ram:CategoryCode>")
    end
  end

  describe "writer parity" do
    it "emits payee_name as ram:AccountName" do
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
      xml_str = invoice.to_xml
      xml_str.should contain("<ram:AccountName>Max Mustermann</ram:AccountName>")
    end

    it "emits PayeePartyCreditorFinancialAccount when only payee_name is set" do
      s = SpecHelper.minimal_invoice.settlement
      settlement = Zugpferd::TradeSettlement.new(
        currency_code: s.currency_code,
        taxes: s.taxes,
        line_total_amount: s.line_total_amount,
        tax_basis_total_amount: s.tax_basis_total_amount,
        tax_total_amount: s.tax_total_amount,
        grand_total_amount: s.grand_total_amount,
        due_payable_amount: s.due_payable_amount,
        payee_name: "Max Mustermann"
      )
      # BASIC_WL+ is required — MINIMUM profile suppresses payment means
      invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::BASIC_WL)
      invoice.settlement = settlement
      xml_str = invoice.to_xml
      xml_str.should contain("PayeePartyCreditorFinancialAccount")
      xml_str.should contain("<ram:AccountName>Max Mustermann</ram:AccountName>")
    end

    it "emits line-item allowance charges inside GrossPriceProductTradePrice" do
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
      xml_str = invoice.to_xml
      xml_str.should contain("GrossPriceProductTradePrice")
      xml_str.should contain("AppliedTradeAllowanceCharge")
      xml_str.should contain("Discount")
    end
  end
end
