module Zugpferd
  # Profile-aware field validator. Accumulates all violations before raising,
  # so the caller sees the complete list of problems at once.
  #
  # Business Term (BT) references follow EN 16931-1:2017.
  class Validator
    def initialize(@invoice : Invoice)
      @violations = [] of String
    end

    def validate! : Nil
      validate_document
      validate_seller
      validate_buyer
      validate_settlement
      validate_line_items
      raise ValidationError.new(@violations) unless @violations.empty?
    end

    # ── Document ──────────────────────────────────────────────────────────────

    private def validate_document
      doc = @invoice.document
      require_field doc.id, "BT-1 Invoice number"
      require_field doc.type_code, "BT-3 Invoice type code"
      # BT-10: buyer reference mandatory for XRechnung
      if @invoice.profile == Profile::XRECHNUNG
        require_field doc.buyer_reference, "BT-10 Buyer reference (mandatory for XRechnung)"
      end
    end

    # ── Seller ────────────────────────────────────────────────────────────────

    private def validate_seller
      seller = @invoice.seller
      require_field seller.name, "BT-27 Seller name"

      # BASIC+ requires address and at least one tax registration
      if @invoice.profile.at_least?(Profile::BASIC)
        if addr = seller.address
          require_field addr.city, "BT-37 Seller city"
          require_field addr.country_id, "BT-40 Seller country"
        else
          @violations << "BT-35..BT-40 Seller postal address is required for #{@invoice.profile}"
        end

        if seller.tax_registrations.empty?
          @violations << "BT-31/BT-32 Seller tax registration is required for #{@invoice.profile}"
        end
      end

      # EN16931+: seller electronic address
      if @invoice.profile.at_least?(Profile::EN16931)
        require_field seller.electronic_address, "BT-34 Seller electronic address"
      end
    end

    # ── Buyer ─────────────────────────────────────────────────────────────────

    private def validate_buyer
      buyer = @invoice.buyer
      require_field buyer.name, "BT-44 Buyer name"

      if @invoice.profile.at_least?(Profile::EN16931)
        if addr = buyer.address
          require_field addr.country_id, "BT-55 Buyer country"
        else
          @violations << "BT-50..BT-55 Buyer postal address is required for #{@invoice.profile}"
        end

        require_field buyer.electronic_address, "BT-49 Buyer electronic address"
      end
    end

    # ── Settlement ────────────────────────────────────────────────────────────

    private def validate_settlement
      s = @invoice.settlement
      require_field s.currency_code, "BT-5 Invoice currency code"

      # Monetary summary totals always required
      @violations << "BT-106 Sum of line net amounts must be >= 0" if s.line_total_amount < BigDecimal.new(0)
      @violations << "BT-115 Amount due for payment cannot be negative" if s.due_payable_amount < BigDecimal.new(0)

      if s.taxes.empty?
        @violations << "BG-23 VAT breakdown is required (at least one ApplicableTradeTax)"
      end

      # EN16931+: payment means
      if @invoice.profile.at_least?(Profile::EN16931)
        require_field s.payment_means_code, "BT-81 Payment means type code"
      end
    end

    # ── Line items ────────────────────────────────────────────────────────────

    private def validate_line_items
      # BASIC_WL has no line items; BASIC+ requires at least one
      return unless @invoice.profile.at_least?(Profile::BASIC)

      if @invoice.line_items.empty?
        @violations << "BG-25 At least one invoice line is required for #{@invoice.profile}"
      end

      @invoice.line_items.each_with_index do |item, idx|
        prefix = "Line #{idx + 1} (pos #{item.position})"
        require_field item.name, "#{prefix} BT-153 item name"
        require_field item.unit_code, "#{prefix} BT-130 unit code"
        @violations << "#{prefix} BT-129 billed quantity must be > 0" if item.billed_quantity <= BigDecimal.new(0)
      end
    end

    # ── Helpers ───────────────────────────────────────────────────────────────

    private def require_field(value : String?, field_name : String) : Nil
      @violations << "#{field_name} is required" if value.nil? || value.empty?
    end

    private def require_field(value : Nil, field_name : String) : Nil
      @violations << "#{field_name} is required"
    end

    private def require_field(value : _, field_name : String) : Nil
      # non-nil, non-String values are always present
    end
  end
end
