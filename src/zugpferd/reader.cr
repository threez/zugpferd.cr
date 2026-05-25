module Zugpferd
  # Parses a ZUGFeRD 2.x CII XML string into an `Invoice`.
  # Does not run the validator — call `Validator.new(invoice).validate!` separately
  # if EN 16931 business-rule validation is needed after parsing.
  class Reader
    # ── Public API ────────────────────────────────────────────────────────────

    # Parses a ZUGFeRD CII XML string and returns an `Invoice`.
    # Raises `ParseError` on structural problems (missing required elements, unknown enum values).
    def self.from_xml(xml : String) : Invoice
      new(xml).read
    end

    # Maps a ZUGFeRD guideline URI to a `Profile` enum member.
    # Handles both canonical URIs (from our Generator) and short-form URIs
    # used by real-world documents (e.g. "urn:cen.eu:en16931:2017").
    def self.parse_profile(uri : String) : Profile
      # Exact match first — covers generator round-trips
      Profile.each { |prof| return prof if prof.guideline_id == uri }
      # Substring fallback for non-canonical URIs in the wild
      case uri
      when .includes?("minimum")   then Profile::MINIMUM
      when .includes?("basicwl")   then Profile::BASIC_WL
      when .includes?("basic")     then Profile::BASIC
      when .includes?("en16931")   then Profile::EN16931
      when .includes?("extended")  then Profile::EXTENDED
      when .includes?("xrechnung") then Profile::XRECHNUNG
      else                              raise ParseError.new("Unknown ZUGFeRD profile URI: #{uri}", field: "ram:ID")
      end
    end

    # ── Constructor (internal) ────────────────────────────────────────────────

    def initialize(@xml : String)
    end

    # ── Orchestration ─────────────────────────────────────────────────────────

    def read : Invoice
      doc = XML.parse(@xml)
      root = doc.first_element_child ||
             raise ParseError.new("XML document has no root element")

      # Profile
      ctx = require_child(root, "ExchangedDocumentContext")
      guideline = require_child(ctx, "GuidelineSpecifiedDocumentContextParameter")
      profile = Reader.parse_profile(require_child_text(guideline, "ID"))

      # ExchangedDocument (buyer_reference added below after reading agreement)
      exch_doc_node = require_child(root, "ExchangedDocument")
      document = parse_exchanged_document(exch_doc_node)

      # SupplyChainTradeTransaction
      txn = require_child(root, "SupplyChainTradeTransaction")

      # Line items
      line_items = [] of SupplyChainTradeLineItem
      each_child(txn, "IncludedSupplyChainTradeLineItem") do |li_node|
        line_items << parse_line_item(li_node)
      end

      # ApplicableHeaderTradeAgreement
      agreement = require_child(txn, "ApplicableHeaderTradeAgreement")
      buyer_reference = child_text(agreement, "BuyerReference")
      if buyer_reference
        document = ExchangedDocument.new(
          id: document.id,
          issue_date: document.issue_date,
          type_code: document.type_code,
          notes: document.notes,
          buyer_reference: buyer_reference
        )
      end
      seller = parse_trade_party(require_child(agreement, "SellerTradeParty"))
      buyer = parse_trade_party(require_child(agreement, "BuyerTradeParty"))

      buyer_order_ref = nil
      if bor = find_child(agreement, "BuyerOrderReferencedDocument")
        buyer_order_ref = child_text(bor, "IssuerAssignedID")
      end

      contract_ref = nil
      if cr = find_child(agreement, "ContractReferencedDocument")
        contract_ref = child_text(cr, "IssuerAssignedID")
      end

      # ApplicableHeaderTradeDelivery (may be self-closing)
      delivery_date = nil
      despatch_ref = nil
      if delivery = find_child(txn, "ApplicableHeaderTradeDelivery")
        if event = find_child(delivery, "ActualDeliverySupplyChainEvent")
          delivery_date = parse_date_from(event, "OccurrenceDateTime")
        end
        if dar = find_child(delivery, "DespatchAdviceReferencedDocument")
          despatch_ref = child_text(dar, "IssuerAssignedID")
        end
      end

      # ApplicableHeaderTradeSettlement
      settlement_node = require_child(txn, "ApplicableHeaderTradeSettlement")
      settlement = parse_settlement(settlement_node)

      Invoice.new(
        profile: profile,
        document: document,
        seller: seller,
        buyer: buyer,
        settlement: settlement,
        line_items: line_items,
        buyer_order_reference: buyer_order_ref,
        contract_reference: contract_ref,
        despatch_advice_reference: despatch_ref,
        delivery_date: delivery_date
      )
    end

    # ── Section Parsers ───────────────────────────────────────────────────────

    private def parse_exchanged_document(node : XML::Node) : ExchangedDocument
      id = require_child_text(node, "ID")
      type_code = child_text(node, "TypeCode") || ExchangedDocument::INVOICE_TYPE_CODE
      issue_date = parse_date_from(node, "IssueDateTime") ||
                   raise ParseError.new("Missing required element: ram:IssueDateTime")

      notes = [] of String
      each_child(node, "IncludedNote") do |note_node|
        if content = child_text(note_node, "Content")
          notes << content
        end
      end

      ExchangedDocument.new(
        id: id,
        issue_date: issue_date,
        type_code: type_code,
        notes: notes
      )
    end

    private def parse_trade_party(node : XML::Node) : TradeParty
      name = require_child_text(node, "Name")

      global_id = nil
      global_id_scheme = nil
      if gid_node = find_child(node, "GlobalID")
        t = gid_node.content.strip
        unless t.empty?
          global_id = t
          global_id_scheme = gid_node["schemeID"]?
        end
      end

      tax_regs = [] of TaxRegistration
      each_child(node, "SpecifiedTaxRegistration") do |reg_node|
        id_node = find_child(reg_node, "ID")
        next if id_node.nil?
        scheme_str = id_node["schemeID"]? || "VA"
        scheme = TaxRegistration::SchemeID.parse?(scheme_str) ||
                 raise ParseError.new("Unknown TaxRegistration schemeID: #{scheme_str}",
                   field: "ram:ID@schemeID")
        id_text = id_node.content.strip
        tax_regs << TaxRegistration.new(scheme, id_text) unless id_text.empty?
      end

      address = parse_trade_address(find_child(node, "PostalTradeAddress"))

      electronic_address = nil
      electronic_address_scheme = nil
      if uri_node = find_child(node, "URIUniversalCommunication")
        if uriid = find_child(uri_node, "URIID")
          t = uriid.content.strip
          unless t.empty?
            electronic_address = t
            electronic_address_scheme = uriid["schemeID"]?
          end
        end
      end

      contact_name = nil
      contact_phone = nil
      contact_email = nil
      if contact_node = find_child(node, "DefinedTradeContact")
        contact_name = child_text(contact_node, "PersonName")
        if phone_node = find_child(contact_node, "TelephoneUniversalCommunication")
          contact_phone = child_text(phone_node, "CompleteNumber")
        end
        if email_node = find_child(contact_node, "EmailURIUniversalCommunication")
          contact_email = child_text(email_node, "URIID")
        end
      end

      TradeParty.new(
        name,
        address: address,
        tax_registrations: tax_regs,
        global_id: global_id,
        global_id_scheme: global_id_scheme,
        electronic_address: electronic_address,
        electronic_address_scheme: electronic_address_scheme,
        contact_name: contact_name,
        contact_phone: contact_phone,
        contact_email: contact_email
      )
    end

    private def parse_trade_address(node : XML::Node?) : TradeAddress?
      return nil if node.nil?
      city = child_text(node, "CityName") || ""
      country_id = child_text(node, "CountryID") || ""
      TradeAddress.new(
        city, country_id,
        line_one: child_text(node, "LineOne"),
        line_two: child_text(node, "LineTwo"),
        postcode: child_text(node, "PostcodeCode")
      )
    end

    private def parse_trade_tax(node : XML::Node) : ApplicableTradeTax
      calculated = require_child_amount(node, "CalculatedAmount")
      basis = require_child_amount(node, "BasisAmount")
      cat_str = require_child_text(node, "CategoryCode")
      category = ApplicableTradeTax::CategoryCode.parse?(cat_str) ||
                 raise ParseError.new("Unknown VAT CategoryCode: #{cat_str}",
                   field: "ram:CategoryCode")
      type_code = child_text(node, "TypeCode") || "VAT"
      rate = child_amount(node, "RateApplicablePercent")
      exemption_reason = child_text(node, "ExemptionReason")
      exemption_reason_code = child_text(node, "ExemptionReasonCode")

      ApplicableTradeTax.new(
        calculated_amount: calculated,
        basis_amount: basis,
        category_code: category,
        type_code: type_code,
        rate_applicable_percent: rate,
        exemption_reason: exemption_reason,
        exemption_reason_code: exemption_reason_code
      )
    end

    private def parse_allowance_charge(node : XML::Node) : SpecifiedTradeAllowanceCharge
      charge = false
      if ci = find_child(node, "ChargeIndicator")
        if ind = find_child(ci, "Indicator")
          charge = ind.content.strip == "true"
        end
      end

      actual_amount = require_child_amount(node, "ActualAmount")
      reason = child_text(node, "Reason")
      reason_code = child_text(node, "ReasonCode")

      cat_code = ApplicableTradeTax::CategoryCode::S
      rate = nil
      if cat_tax = find_child(node, "CategoryTradeTax")
        cat_str = child_text(cat_tax, "CategoryCode") || "S"
        cat_code = ApplicableTradeTax::CategoryCode.parse?(cat_str) ||
                   raise ParseError.new("Unknown AllowanceCharge CategoryCode: #{cat_str}",
                     field: "ram:CategoryCode")
        rate = child_amount(cat_tax, "RateApplicablePercent")
      end

      SpecifiedTradeAllowanceCharge.new(
        charge, actual_amount, cat_code,
        reason: reason,
        reason_code: reason_code,
        tax_rate_percent: rate
      )
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_line_item(node : XML::Node) : SupplyChainTradeLineItem
      # AssociatedDocumentLineDocument
      assoc = require_child(node, "AssociatedDocumentLineDocument")
      position = require_child_text(assoc, "LineID").to_i
      line_note = nil
      if note_node = find_child(assoc, "IncludedNote")
        line_note = child_text(note_node, "Content")
      end

      # SpecifiedTradeProduct
      product = require_child(node, "SpecifiedTradeProduct")
      name = require_child_text(product, "Name")
      description = presence(child_text(product, "Description"))
      seller_id = child_text(product, "SellerAssignedID")
      buyer_id = child_text(product, "BuyerAssignedID")

      # SpecifiedLineTradeAgreement
      gross_price = nil
      net_price = BigDecimal.new(0)
      line_allowance_charges = [] of SpecifiedTradeAllowanceCharge
      if agreement = find_child(node, "SpecifiedLineTradeAgreement")
        if gp = find_child(agreement, "GrossPriceProductTradePrice")
          gross_price = child_amount(gp, "ChargeAmount")
          each_child(gp, "AppliedTradeAllowanceCharge") do |ac_node|
            line_allowance_charges << parse_allowance_charge(ac_node)
          end
        end
        if np = find_child(agreement, "NetPriceProductTradePrice")
          net_price = child_amount(np, "ChargeAmount") || BigDecimal.new(0)
        end
      end

      # SpecifiedLineTradeDelivery
      billed_qty = BigDecimal.new(0)
      unit_code = "C62"
      if delivery = find_child(node, "SpecifiedLineTradeDelivery")
        if bq = find_child(delivery, "BilledQuantity")
          billed_qty = BigDecimal.new(bq.content.strip)
          unit_code = bq["unitCode"]? || "C62"
        end
      end

      # SpecifiedLineTradeSettlement
      tax_category = ApplicableTradeTax::CategoryCode::S
      tax_rate = nil
      if settlement = find_child(node, "SpecifiedLineTradeSettlement")
        if tax_node = find_child(settlement, "ApplicableTradeTax")
          cat_str = child_text(tax_node, "CategoryCode") || "S"
          tax_category = ApplicableTradeTax::CategoryCode.parse?(cat_str) ||
                         raise ParseError.new("Unknown line item CategoryCode: #{cat_str}",
                           field: "ram:CategoryCode")
          tax_rate = child_amount(tax_node, "RateApplicablePercent")
        end
      end

      # line_total is auto-calculated in SupplyChainTradeLineItem#initialize
      SupplyChainTradeLineItem.new(
        position: position,
        name: name,
        billed_quantity: billed_qty,
        unit_code: unit_code,
        net_price: net_price,
        tax_category_code: tax_category,
        description: description,
        seller_assigned_id: seller_id,
        buyer_assigned_id: buyer_id,
        gross_price: gross_price,
        tax_rate_percent: tax_rate,
        note: line_note,
        allowance_charges: line_allowance_charges
      )
    end

    private def parse_settlement(node : XML::Node) : TradeSettlement
      currency_code = require_child_text(node, "InvoiceCurrencyCode")
      payment_reference = child_text(node, "PaymentReference")

      payment_means_code = nil
      payee_iban = nil
      payee_bic = nil
      payee_name = nil
      if pm = find_child(node, "SpecifiedTradeSettlementPaymentMeans")
        payment_means_code = child_text(pm, "TypeCode")
        if acct = find_child(pm, "PayeePartyCreditorFinancialAccount")
          payee_iban = child_text(acct, "IBANID")
          payee_name = child_text(acct, "AccountName")
        end
        if inst = find_child(pm, "PayeeSpecifiedCreditorFinancialInstitution")
          payee_bic = child_text(inst, "BICID")
        end
      end

      taxes = [] of ApplicableTradeTax
      each_child(node, "ApplicableTradeTax") do |tax_node|
        taxes << parse_trade_tax(tax_node)
      end

      allowance_charges = [] of SpecifiedTradeAllowanceCharge
      each_child(node, "SpecifiedTradeAllowanceCharge") do |ac_node|
        allowance_charges << parse_allowance_charge(ac_node)
      end

      payment_terms_note = nil
      due_date = nil
      if terms = find_child(node, "SpecifiedTradePaymentTerms")
        payment_terms_note = child_text(terms, "Description")
        due_date = parse_date_from(terms, "DueDateDateTime")
      end

      summation = require_child(node, "SpecifiedTradeSettlementHeaderMonetarySummation")
      line_total = child_amount(summation, "LineTotalAmount") || BigDecimal.new(0)
      charge_total = child_amount(summation, "ChargeTotalAmount") || BigDecimal.new(0)
      allow_total = child_amount(summation, "AllowanceTotalAmount") || BigDecimal.new(0)
      tax_basis = require_child_amount(summation, "TaxBasisTotalAmount")
      tax_total = require_child_amount(summation, "TaxTotalAmount")
      grand_total = require_child_amount(summation, "GrandTotalAmount")
      prepaid = child_amount(summation, "TotalPrepaidAmount") || BigDecimal.new(0)
      due_payable = require_child_amount(summation, "DuePayableAmount")

      TradeSettlement.new(
        currency_code: currency_code,
        taxes: taxes,
        line_total_amount: line_total,
        tax_basis_total_amount: tax_basis,
        tax_total_amount: tax_total,
        grand_total_amount: grand_total,
        due_payable_amount: due_payable,
        payment_reference: payment_reference,
        payment_means_code: payment_means_code,
        payee_iban: payee_iban,
        payee_bic: payee_bic,
        payee_name: payee_name,
        due_date: due_date,
        payment_terms_note: payment_terms_note,
        allowance_charges: allowance_charges,
        allowance_total_amount: allow_total,
        charge_total_amount: charge_total,
        prepaid_amount: prepaid
      )
    end

    # ── Node traversal helpers ─────────────────────────────────────────────────

    private def local_name(node : XML::Node) : String
      n = node.name
      idx = n.index(':')
      idx ? n[(idx + 1)..] : n
    end

    private def find_child(parent : XML::Node, local : String) : XML::Node?
      parent.children.find { |child| child.element? && local_name(child) == local }
    end

    private def each_child(parent : XML::Node, local : String, &) : Nil
      parent.children.each { |child| yield child if child.element? && local_name(child) == local }
    end

    private def require_child(parent : XML::Node, local : String) : XML::Node
      find_child(parent, local) ||
        raise ParseError.new(
          "Required element <#{local}> not found inside <#{local_name(parent)}>",
          field: local
        )
    end

    private def child_text(parent : XML::Node, local : String) : String?
      node = find_child(parent, local) || return nil
      t = node.content.strip
      t.empty? ? nil : t
    end

    private def require_child_text(parent : XML::Node, local : String) : String
      node = require_child(parent, local)
      t = node.content.strip
      raise ParseError.new("Element <#{local}> is empty", field: local) if t.empty?
      t
    end

    private def child_amount(parent : XML::Node, local : String) : MonetaryAmount?
      txt = child_text(parent, local) || return nil
      BigDecimal.new(txt)
    end

    private def require_child_amount(parent : XML::Node, local : String) : MonetaryAmount
      BigDecimal.new(require_child_text(parent, local))
    end

    # Parses a <udt:DateTimeString format="102">YYYYMMDD</udt:DateTimeString>
    # from a wrapper element. Returns nil if wrapper or DateTimeString is absent.
    private def parse_date_from(parent : XML::Node, wrapper_local : String) : Time?
      wrapper = find_child(parent, wrapper_local) || return nil
      dts = find_child(wrapper, "DateTimeString") || return nil
      t = dts.content.strip
      return nil if t.empty?
      Time.parse(t, "%Y%m%d", Time::Location::UTC)
    end

    private def presence(s : String?) : String?
      s.nil? || s.empty? ? nil : s
    end
  end
end
