module Zugpferd
  # Payment details and all monetary totals for the invoice (BG-17 payment means, BG-22 document totals).
  # Holds currency, VAT breakdown, optional payment means, and the full summation block.
  struct TradeSettlement
    # Invoice currency (BT-5). ISO 4217 alpha-3 code, e.g. "EUR", "USD", "GBP".
    property currency_code : String

    # Remittance information / payment reference the buyer should quote (BT-83).
    # Emitted only for BASIC_WL and above.
    property payment_reference : String?

    # Payment means code (BT-81). UNTDID 4461 code list.
    # Common values: "58" = SEPA credit transfer, "30" = credit transfer, "48" = bank card.
    # Emitted only for BASIC_WL and above.
    property payment_means_code : String?

    # IBAN of the payee's bank account (BT-84). Emitted only for BASIC_WL and above.
    property payee_iban : String?

    # BIC/SWIFT code of the payee's bank (BT-85). Emitted only for BASIC_WL and above.
    property payee_bic : String?

    # Name on the payee's bank account (BT-86), if different from the seller name.
    # Emitted only for BASIC_WL and above.
    property payee_name : String?

    # Payment due date (BT-9). Required when `payment_terms_note` is absent (BR-CO-25).
    # Emitted only for BASIC_WL and above.
    property due_date : Time?

    # Free-text payment terms description (BT-20). Use when structured due date is insufficient.
    # Emitted only for BASIC_WL and above.
    property payment_terms_note : String?

    # VAT breakdown entries (BG-23). At least one entry is required for BASIC and above.
    # Emitted only for BASIC_WL and above.
    property taxes : Array(ApplicableTradeTax)

    # Document-level allowances and charges (BG-20 charges / BG-21 allowances).
    # Distinct from line-level `allowance_charges` on `SupplyChainTradeLineItem`.
    # Emitted only for BASIC_WL and above.
    property allowance_charges : Array(SpecifiedTradeAllowanceCharge)

    # Sum of all line net amounts (BT-106). Required for BASIC_WL and above.
    property line_total_amount : MonetaryAmount

    # Sum of all document-level allowance amounts (BT-107). Zero if none.
    property allowance_total_amount : MonetaryAmount

    # Sum of all document-level charge amounts (BT-108). Zero if none.
    property charge_total_amount : MonetaryAmount

    # Tax-exclusive invoice total: line_total − allowances + charges (BT-109).
    property tax_basis_total_amount : MonetaryAmount

    # Total VAT amount for the invoice (BT-110).
    property tax_total_amount : MonetaryAmount

    # Invoice total inclusive of VAT (BT-112).
    property grand_total_amount : MonetaryAmount

    # Amount already paid before this invoice (BT-113). Zero if nothing is prepaid.
    property prepaid_amount : MonetaryAmount

    # Amount the buyer still owes: grand_total − prepaid (BT-115).
    property due_payable_amount : MonetaryAmount

    def initialize(@currency_code : String,
                   @taxes : Array(ApplicableTradeTax),
                   @line_total_amount : MonetaryAmount,
                   @tax_basis_total_amount : MonetaryAmount,
                   @tax_total_amount : MonetaryAmount,
                   @grand_total_amount : MonetaryAmount,
                   @due_payable_amount : MonetaryAmount, *,
                   @payment_reference : String? = nil,
                   @payment_means_code : String? = nil,
                   @payee_iban : String? = nil,
                   @payee_bic : String? = nil,
                   @payee_name : String? = nil,
                   @due_date : Time? = nil,
                   @payment_terms_note : String? = nil,
                   @allowance_charges : Array(SpecifiedTradeAllowanceCharge) = [] of SpecifiedTradeAllowanceCharge,
                   @allowance_total_amount : MonetaryAmount = BigDecimal.new(0),
                   @charge_total_amount : MonetaryAmount = BigDecimal.new(0),
                   @prepaid_amount : MonetaryAmount = BigDecimal.new(0))
    end
  end
end
