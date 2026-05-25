module Zugpferd
  # A VAT breakdown entry (BG-23) in the settlement, describing the tax applicable to one VAT category.
  # Also used on `SupplyChainTradeLineItem` to indicate the VAT category for that line.
  struct ApplicableTradeTax
    # UNTDID 5305 duty/tax/fee category codes used in EN 16931.
    enum CategoryCode
      S  # Standard rate
      Z  # Zero rated
      E  # Exempt
      AE # VAT Reverse Charge
      K  # Intra-community supply (VAT exempt)
      G  # Free export (VAT exempt)
      O  # Services outside scope of tax
      L  # IGIC (Canary Islands)
      M  # IPSI (Ceuta/Melilla)
    end

    # The VAT amount calculated for this category (BT-117).
    property calculated_amount : MonetaryAmount

    # Tax type code — always "VAT" in EN 16931; no other value is valid in ZUGFeRD.
    property type_code : String

    # Free-text reason when the category does not apply standard VAT (BT-120).
    # Required for categories E, AE, K, G, O when `exemption_reason_code` is absent.
    property exemption_reason : String?

    # Coded exemption reason (BT-121). VATEX code list (e.g. "VATEX-EU-AE" = reverse charge,
    # "VATEX-EU-IC" = intra-community supply). Required when `exemption_reason` is absent.
    property exemption_reason_code : String?

    # Taxable base amount for this VAT category (BT-116).
    property basis_amount : MonetaryAmount

    # VAT category code (BT-118). See `CategoryCode` for valid values.
    property category_code : CategoryCode

    # VAT rate percentage (BT-119). Nil for categories E, AE, K, G, O where no rate applies.
    property rate_applicable_percent : MonetaryAmount?

    def initialize(@calculated_amount : MonetaryAmount,
                   @basis_amount : MonetaryAmount,
                   @category_code : CategoryCode, *,
                   @type_code : String = "VAT",
                   @rate_applicable_percent : MonetaryAmount? = nil,
                   @exemption_reason : String? = nil,
                   @exemption_reason_code : String? = nil)
    end
  end
end
