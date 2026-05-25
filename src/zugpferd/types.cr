module Zugpferd
  alias MonetaryAmount = BigDecimal

  # Format a BigDecimal as a fixed-decimal string for XML content.
  # ZUGFeRD requires exactly `decimals` decimal places (default 2, quantity 4).
  def self.format_amount(amount : BigDecimal, decimals : Int32 = 2) : String
    amount.format(decimal_places: decimals, only_significant: false)
  end
end
