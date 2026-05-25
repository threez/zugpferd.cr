module Zugpferd
  # A ZUGFeRD 2.x invoice. Construct via `Invoice.build` and call `#to_xml` to validate and serialise.
  class Invoice
    # The compliance profile; controls which fields are required or forbidden during validation and generation.
    property profile : Profile

    # Invoice header metadata: number, date, type code, and notes (BG-1).
    property document : ExchangedDocument

    # Seller party (BG-4).
    property seller : TradeParty

    # Buyer party (BG-7).
    property buyer : TradeParty

    # Currency, VAT breakdown, payment means, and all monetary totals.
    property settlement : TradeSettlement

    # Invoice lines (BG-25). Required for BASIC and above; empty for MINIMUM and BASIC_WL.
    property line_items : Array(SupplyChainTradeLineItem)

    # Purchase order reference from the buyer (BT-13).
    property buyer_order_reference : String?

    # Contract reference (BT-12).
    property contract_reference : String?

    # Despatch advice document reference (BT-16).
    property despatch_advice_reference : String?

    # Actual delivery date (BT-72). Required for BASIC and above (BR-FX-EN-04).
    property delivery_date : Time?

    def initialize(@profile : Profile,
                   @document : ExchangedDocument,
                   @seller : TradeParty,
                   @buyer : TradeParty,
                   @settlement : TradeSettlement,
                   @line_items : Array(SupplyChainTradeLineItem) = [] of SupplyChainTradeLineItem, *,
                   @buyer_order_reference : String? = nil,
                   @contract_reference : String? = nil,
                   @despatch_advice_reference : String? = nil,
                   @delivery_date : Time? = nil)
    end

    # Validates the invoice against EN 16931 business rules, then serialises to CII XML.
    # Raises `ValidationError` if any business rule is violated.
    def to_xml(indent : String = "  ") : String
      Validator.new(self).validate!
      Generator.new(self).generate(indent: indent)
    end

    # Primary entry point for constructing invoices.
    # Yields a `Builder` and returns a fully constructed `Invoice` on block exit.
    # Raises `GenerationError` if document, seller, buyer, or settlement are not set.
    def self.build(profile : Profile = Profile::EN16931, &) : Invoice
      builder = Builder.new(profile)
      yield builder
      builder.build
    end

    # Mutable builder used inside the `Invoice.build` block.
    # Set `document`, `seller`, `buyer`, and `settlement` before the block exits.
    class Builder
      property profile : Profile
      property document : ExchangedDocument?
      property seller : TradeParty?
      property buyer : TradeParty?
      property settlement : TradeSettlement?
      property line_items : Array(SupplyChainTradeLineItem)
      property buyer_order_reference : String?
      property contract_reference : String?
      property despatch_advice_reference : String?
      property delivery_date : Time?

      def initialize(@profile : Profile)
        @line_items = [] of SupplyChainTradeLineItem
      end

      # Appends *item* to the line items and returns `self` for chaining.
      def add_line_item(item : SupplyChainTradeLineItem) : self
        @line_items << item
        self
      end

      # Constructs the `Invoice`. Raises `GenerationError` if document, seller, buyer,
      # or settlement have not been assigned.
      def build : Invoice
        doc = @document || raise GenerationError.new("Invoice document (ExchangedDocument) is required")
        sel = @seller || raise GenerationError.new("Seller (TradeParty) is required")
        buy = @buyer || raise GenerationError.new("Buyer (TradeParty) is required")
        set = @settlement || raise GenerationError.new("Settlement (TradeSettlement) is required")

        Invoice.new(
          profile: @profile,
          document: doc,
          seller: sel,
          buyer: buy,
          settlement: set,
          line_items: @line_items,
          buyer_order_reference: @buyer_order_reference,
          contract_reference: @contract_reference,
          despatch_advice_reference: @despatch_advice_reference,
          delivery_date: @delivery_date
        )
      end
    end
  end
end
