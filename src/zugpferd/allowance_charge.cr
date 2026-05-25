module Zugpferd
  # A document-level or line-level allowance or charge.
  #
  # At document level: BG-20 (charge) or BG-21 (allowance), held in `TradeSettlement#allowance_charges`.
  # At line level: BG-27 (allowance) or BG-28 (charge), held in `SupplyChainTradeLineItem#allowance_charges`.
  struct SpecifiedTradeAllowanceCharge
    # Whether this entry is a surcharge (`true`, BG-20/28) or an allowance/discount (`false`, BG-21/27).
    property? charge : Bool

    # The monetary amount of the allowance or charge (BT-92 doc-allowance / BT-99 doc-charge /
    # BT-136 line-allowance / BT-141 line-charge).
    property actual_amount : MonetaryAmount

    # Free-text reason for the allowance or charge (BT-97/104/139/144). Optional but recommended.
    property reason : String?

    # Coded reason using UNTDID 4465 (BT-98/105/140/145).
    # Examples: "64" = special agreement, "95" = discount, "SAA" = settlement allowance.
    property reason_code : String?

    # VAT category that applies to this allowance or charge (BT-95/102/151).
    # Required at document level; not used for line-level entries.
    property tax_category_code : ApplicableTradeTax::CategoryCode

    # VAT rate percentage for this allowance or charge (BT-96/103/152).
    # Nil for exempt or zero-rate categories.
    property tax_rate_percent : MonetaryAmount?

    def initialize(@charge : Bool,
                   @actual_amount : MonetaryAmount,
                   @tax_category_code : ApplicableTradeTax::CategoryCode, *,
                   @reason : String? = nil,
                   @reason_code : String? = nil,
                   @tax_rate_percent : MonetaryAmount? = nil)
    end
  end
end
