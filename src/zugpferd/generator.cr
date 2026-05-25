module Zugpferd
  # Generates a ZUGFeRD 2.x CII XML document from a validated Invoice.
  # Call Invoice#to_xml instead of using this class directly.
  class Generator
    RSM = "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"
    RAM = "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"
    UDT = "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"
    QDT = "urn:un:unece:uncefact:data:standard:QualifiedDataType:100"
    XSI = "http://www.w3.org/2001/XMLSchema-instance"

    def initialize(@invoice : Invoice)
    end

    def generate(indent : String = "  ") : String
      XML.build(encoding: "UTF-8", indent: indent) do |xml|
        xml.element("rsm:CrossIndustryInvoice",
          "xmlns:rsm": RSM,
          "xmlns:ram": RAM,
          "xmlns:udt": UDT,
          "xmlns:qdt": QDT,
          "xmlns:xsi": XSI) do
          emit_exchanged_document_context(xml)
          emit_exchanged_document(xml)
          emit_supply_chain_trade_transaction(xml)
        end
      end
    end

    # ── ExchangedDocumentContext ───────────────────────────────────────────────

    private def emit_exchanged_document_context(xml : XML::Builder)
      xml.element("rsm:ExchangedDocumentContext") do
        xml.element("ram:GuidelineSpecifiedDocumentContextParameter") do
          xml.element("ram:ID") { xml.text @invoice.profile.guideline_id }
        end
      end
    end

    # ── ExchangedDocument ─────────────────────────────────────────────────────

    private def emit_exchanged_document(xml : XML::Builder)
      doc = @invoice.document
      xml.element("rsm:ExchangedDocument") do
        xml.element("ram:ID") { xml.text doc.id }
        xml.element("ram:TypeCode") { xml.text doc.type_code }
        xml.element("ram:IssueDateTime") { udt_date(xml, doc.issue_date) }
        doc.notes.each do |note|
          xml.element("ram:IncludedNote") do
            xml.element("ram:Content") { xml.text note }
          end
        end
      end
    end

    # ── SupplyChainTradeTransaction ───────────────────────────────────────────

    private def emit_supply_chain_trade_transaction(xml : XML::Builder)
      xml.element("rsm:SupplyChainTradeTransaction") do
        emit_line_items(xml)
        emit_header_trade_agreement(xml)
        emit_header_trade_delivery(xml)
        emit_header_trade_settlement(xml)
      end
    end

    # ── Line Items ────────────────────────────────────────────────────────────

    private def emit_line_items(xml : XML::Builder)
      @invoice.line_items.each do |item|
        xml.element("ram:IncludedSupplyChainTradeLineItem") do
          xml.element("ram:AssociatedDocumentLineDocument") do
            xml.element("ram:LineID") { xml.text item.position.to_s }
            if note = item.note
              xml.element("ram:IncludedNote") do
                xml.element("ram:Content") { xml.text note }
              end
            end
          end

          xml.element("ram:SpecifiedTradeProduct") do
            ram_text(xml, "ram:SellerAssignedID", item.seller_assigned_id)
            ram_text(xml, "ram:BuyerAssignedID", item.buyer_assigned_id)
            xml.element("ram:Name") { xml.text item.name }
            ram_text(xml, "ram:Description", item.description)
          end

          xml.element("ram:SpecifiedLineTradeAgreement") do
            if item.gross_price || !item.allowance_charges.empty?
              xml.element("ram:GrossPriceProductTradePrice") do
                udt_amount(xml, "ram:ChargeAmount", item.gross_price || item.net_price)
                item.allowance_charges.each { |allowance_charge| emit_line_allowance_charge(xml, allowance_charge) }
              end
            end
            xml.element("ram:NetPriceProductTradePrice") do
              udt_amount(xml, "ram:ChargeAmount", item.net_price)
            end
          end

          xml.element("ram:SpecifiedLineTradeDelivery") do
            xml.element("ram:BilledQuantity", unitCode: item.unit_code) do
              xml.text Zugpferd.format_amount(item.billed_quantity, 4)
            end
          end

          xml.element("ram:SpecifiedLineTradeSettlement") do
            xml.element("ram:ApplicableTradeTax") do
              xml.element("ram:TypeCode") { xml.text "VAT" }
              xml.element("ram:CategoryCode") { xml.text item.tax_category_code.to_s }
              if rate = item.tax_rate_percent
                xml.element("ram:RateApplicablePercent") { xml.text Zugpferd.format_amount(rate) }
              end
            end
            xml.element("ram:SpecifiedTradeSettlementLineMonetarySummation") do
              udt_amount(xml, "ram:LineTotalAmount", item.line_total)
            end
          end
        end
      end
    end

    # ── Header Trade Agreement ─────────────────────────────────────────────────

    private def emit_header_trade_agreement(xml : XML::Builder)
      inv = @invoice
      xml.element("ram:ApplicableHeaderTradeAgreement") do
        if ref = inv.document.buyer_reference
          xml.element("ram:BuyerReference") { xml.text ref }
        end
        emit_trade_party(xml, "ram:SellerTradeParty", inv.seller)
        emit_trade_party(xml, "ram:BuyerTradeParty", inv.buyer)
        if por = inv.buyer_order_reference
          xml.element("ram:BuyerOrderReferencedDocument") do
            xml.element("ram:IssuerAssignedID") { xml.text por }
          end
        end
        if cr = inv.contract_reference
          xml.element("ram:ContractReferencedDocument") do
            xml.element("ram:IssuerAssignedID") { xml.text cr }
          end
        end
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def emit_trade_party(xml : XML::Builder, element : String, party : TradeParty)
      xml.element(element) do
        if gid = party.global_id
          if scheme = party.global_id_scheme
            xml.element("ram:GlobalID", schemeID: scheme) { xml.text gid }
          else
            xml.element("ram:GlobalID") { xml.text gid }
          end
        end
        xml.element("ram:Name") { xml.text party.name }

        # CII XSD sequence varies by profile:
        #   MINIMUM:   Name → PostalTradeAddress? → SpecifiedTaxRegistration*
        #   BASIC_WL+: Name → DefinedTradeContact? → PostalTradeAddress? →
        #              URIUniversalCommunication? → SpecifiedTaxRegistration*
        if @invoice.profile.at_least?(Profile::BASIC_WL)
          if party.contact_name || party.contact_phone || party.contact_email
            xml.element("ram:DefinedTradeContact") do
              ram_text(xml, "ram:PersonName", party.contact_name)
              if phone = party.contact_phone
                xml.element("ram:TelephoneUniversalCommunication") do
                  xml.element("ram:CompleteNumber") { xml.text phone }
                end
              end
              if email = party.contact_email
                xml.element("ram:EmailURIUniversalCommunication") do
                  xml.element("ram:URIID") { xml.text email }
                end
              end
            end
          end
        end

        if addr = party.address
          xml.element("ram:PostalTradeAddress") do
            # MINIMUM XSD only allows CountryID; sub-fields require BASIC_WL+
            if @invoice.profile.at_least?(Profile::BASIC_WL)
              ram_text(xml, "ram:PostcodeCode", addr.postcode)
              ram_text(xml, "ram:LineOne", addr.line_one)
              ram_text(xml, "ram:LineTwo", addr.line_two)
              ram_text(xml, "ram:CityName", addr.city)
            end
            xml.element("ram:CountryID") { xml.text addr.country_id }
          end
        end

        if @invoice.profile.at_least?(Profile::BASIC_WL)
          if ea = party.electronic_address
            scheme = party.electronic_address_scheme || "EM"
            xml.element("ram:URIUniversalCommunication") do
              xml.element("ram:URIID", schemeID: scheme) { xml.text ea }
            end
          end
        end

        unless party.tax_registrations.empty?
          party.tax_registrations.each do |reg|
            xml.element("ram:SpecifiedTaxRegistration") do
              xml.element("ram:ID", schemeID: reg.scheme_id.to_s) { xml.text reg.id }
            end
          end
        end
      end
    end

    # ── Header Trade Delivery ──────────────────────────────────────────────────

    private def emit_header_trade_delivery(xml : XML::Builder)
      xml.element("ram:ApplicableHeaderTradeDelivery") do
        if dd = @invoice.delivery_date
          xml.element("ram:ActualDeliverySupplyChainEvent") do
            xml.element("ram:OccurrenceDateTime") { udt_date(xml, dd) }
          end
        end
        if dar = @invoice.despatch_advice_reference
          xml.element("ram:DespatchAdviceReferencedDocument") do
            xml.element("ram:IssuerAssignedID") { xml.text dar }
          end
        end
      end
    end

    # ── Header Trade Settlement ────────────────────────────────────────────────

    # ameba:disable Metrics/CyclomaticComplexity
    private def emit_header_trade_settlement(xml : XML::Builder)
      s = @invoice.settlement
      minimum = !@invoice.profile.at_least?(Profile::BASIC_WL)
      xml.element("ram:ApplicableHeaderTradeSettlement") do
        # MINIMUM XSD: InvoiceCurrencyCode → SpecifiedTradeSettlementHeaderMonetarySummation only
        unless minimum
          ram_text(xml, "ram:PaymentReference", s.payment_reference)
        end
        xml.element("ram:InvoiceCurrencyCode") { xml.text s.currency_code }

        unless minimum
          if s.payment_means_code || s.payee_iban || s.payee_bic || s.payee_name
            xml.element("ram:SpecifiedTradeSettlementPaymentMeans") do
              if code = s.payment_means_code
                xml.element("ram:TypeCode") { xml.text code }
              end
              if s.payee_iban || s.payee_bic || s.payee_name
                xml.element("ram:PayeePartyCreditorFinancialAccount") do
                  ram_text(xml, "ram:IBANID", s.payee_iban)
                  ram_text(xml, "ram:AccountName", s.payee_name)
                end
                if bic = s.payee_bic
                  xml.element("ram:PayeeSpecifiedCreditorFinancialInstitution") do
                    xml.element("ram:BICID") { xml.text bic }
                  end
                end
              end
            end
          end

          s.taxes.each { |tax| emit_trade_tax(xml, tax) }

          s.allowance_charges.each { |allowance_charge| emit_allowance_charge(xml, allowance_charge, s.currency_code) }

          if terms = s.payment_terms_note
            xml.element("ram:SpecifiedTradePaymentTerms") do
              xml.element("ram:Description") { xml.text terms }
              if dd = s.due_date
                xml.element("ram:DueDateDateTime") { udt_date(xml, dd) }
              end
            end
          elsif dd = s.due_date
            xml.element("ram:SpecifiedTradePaymentTerms") do
              xml.element("ram:DueDateDateTime") { udt_date(xml, dd) }
            end
          end
        end

        xml.element("ram:SpecifiedTradeSettlementHeaderMonetarySummation") do
          unless minimum
            udt_amount(xml, "ram:LineTotalAmount", s.line_total_amount)
            udt_amount(xml, "ram:ChargeTotalAmount", s.charge_total_amount)
            udt_amount(xml, "ram:AllowanceTotalAmount", s.allowance_total_amount)
          end
          udt_amount(xml, "ram:TaxBasisTotalAmount", s.tax_basis_total_amount)
          xml.element("ram:TaxTotalAmount", currencyID: s.currency_code) do
            xml.text Zugpferd.format_amount(s.tax_total_amount)
          end
          udt_amount(xml, "ram:GrandTotalAmount", s.grand_total_amount)
          unless minimum
            udt_amount(xml, "ram:TotalPrepaidAmount", s.prepaid_amount)
          end
          udt_amount(xml, "ram:DuePayableAmount", s.due_payable_amount)
        end
      end
    end

    private def emit_trade_tax(xml : XML::Builder, tax : ApplicableTradeTax)
      xml.element("ram:ApplicableTradeTax") do
        udt_amount(xml, "ram:CalculatedAmount", tax.calculated_amount)
        xml.element("ram:TypeCode") { xml.text tax.type_code }
        ram_text(xml, "ram:ExemptionReason", tax.exemption_reason)
        udt_amount(xml, "ram:BasisAmount", tax.basis_amount)
        xml.element("ram:CategoryCode") { xml.text tax.category_code.to_s }
        ram_text(xml, "ram:ExemptionReasonCode", tax.exemption_reason_code)
        if rate = tax.rate_applicable_percent
          xml.element("ram:RateApplicablePercent") { xml.text Zugpferd.format_amount(rate) }
        end
      end
    end

    private def emit_allowance_charge(xml : XML::Builder, ac : SpecifiedTradeAllowanceCharge, currency : String)
      xml.element("ram:SpecifiedTradeAllowanceCharge") do
        xml.element("ram:ChargeIndicator") do
          xml.element("udt:Indicator") { xml.text ac.charge?.to_s }
        end
        ram_text(xml, "ram:ReasonCode", ac.reason_code)
        ram_text(xml, "ram:Reason", ac.reason)
        udt_amount(xml, "ram:ActualAmount", ac.actual_amount)
        xml.element("ram:CategoryTradeTax") do
          xml.element("ram:TypeCode") { xml.text "VAT" }
          xml.element("ram:CategoryCode") { xml.text ac.tax_category_code.to_s }
          if rate = ac.tax_rate_percent
            xml.element("ram:RateApplicablePercent") { xml.text Zugpferd.format_amount(rate) }
          end
        end
      end
    end

    private def emit_line_allowance_charge(xml : XML::Builder, ac : SpecifiedTradeAllowanceCharge) : Nil
      xml.element("ram:AppliedTradeAllowanceCharge") do
        xml.element("ram:ChargeIndicator") do
          xml.element("udt:Indicator") { xml.text ac.charge?.to_s }
        end
        ram_text(xml, "ram:ReasonCode", ac.reason_code)
        ram_text(xml, "ram:Reason", ac.reason)
        udt_amount(xml, "ram:ActualAmount", ac.actual_amount)
      end
    end

    # ── XML helpers ───────────────────────────────────────────────────────────

    private def ram_text(xml : XML::Builder, element : String, value : String?) : Nil
      return if value.nil? || value.empty?
      xml.element(element) { xml.text value }
    end

    private def udt_date(xml : XML::Builder, date : Time) : Nil
      xml.element("udt:DateTimeString", format: "102") do
        xml.text date.to_s("%Y%m%d")
      end
    end

    private def udt_amount(xml : XML::Builder, element : String, amount : MonetaryAmount) : Nil
      xml.element(element) { xml.text Zugpferd.format_amount(amount) }
    end
  end
end
