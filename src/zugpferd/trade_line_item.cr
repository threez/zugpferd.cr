module Zugpferd
  # One invoice line (BG-25). Each line describes a distinct product or service
  # with its quantity, unit price, VAT category, and the resulting line total.
  struct SupplyChainTradeLineItem
    # Sequential line number within the invoice (BT-126). Must be unique and positive.
    property position : Int32

    # Name of the product or service (BT-153).
    property name : String

    # Optional free-text description of the item (BT-154).
    property description : String?

    # Seller's own article or item identifier (BT-155).
    property seller_assigned_id : String?

    # Buyer's article or item identifier (BT-156).
    property buyer_assigned_id : String?

    # Unit of measure for `billed_quantity` (BT-130). UN/ECE Rec 20 code,
    # e.g. "C62" = piece, "HUR" = hour, "KGM" = kilogram, "DAY" = day.
    property unit_code : String

    # Number of units delivered or consumed (BT-129).
    property billed_quantity : MonetaryAmount

    # Net price per unit, exclusive of VAT (BT-131).
    # `line_total` is computed as `billed_quantity × net_price`.
    property net_price : MonetaryAmount

    # Gross (list) price per unit before any line-level discounts (BT-148).
    # Emit only when it differs from `net_price`; triggers a `GrossPriceProductTradePrice` block.
    property gross_price : MonetaryAmount?

    # VAT category code applicable to this line (BT-151).
    # Common values: `S` = standard rate, `Z` = zero rate, `E` = exempt, `AE` = reverse charge.
    property tax_category_code : ApplicableTradeTax::CategoryCode

    # VAT rate percentage for this line (BT-152). Nil for exempt/reverse-charge categories.
    property tax_rate_percent : MonetaryAmount?

    # Calculated line total: `billed_quantity × net_price` (BT-131 × BT-129).
    # Set automatically in the constructor; update manually if you override `net_price` after construction.
    property line_total : MonetaryAmount

    # Line-level allowances or charges (BG-27 allowances / BG-28 charges).
    # Emitted inside `GrossPriceProductTradePrice` as `AppliedTradeAllowanceCharge` elements.
    # Only meaningful when `gross_price` is set or these entries are non-empty.
    property allowance_charges : Array(SpecifiedTradeAllowanceCharge)

    # Optional free-text note for this line (BT-127).
    property note : String?

    def initialize(@position : Int32,
                   @name : String,
                   @billed_quantity : MonetaryAmount,
                   @unit_code : String,
                   @net_price : MonetaryAmount,
                   @tax_category_code : ApplicableTradeTax::CategoryCode, *,
                   @description : String? = nil,
                   @seller_assigned_id : String? = nil,
                   @buyer_assigned_id : String? = nil,
                   @gross_price : MonetaryAmount? = nil,
                   @tax_rate_percent : MonetaryAmount? = nil,
                   @allowance_charges : Array(SpecifiedTradeAllowanceCharge) = [] of SpecifiedTradeAllowanceCharge,
                   @note : String? = nil)
      @line_total = @billed_quantity * @net_price
    end
  end
end
