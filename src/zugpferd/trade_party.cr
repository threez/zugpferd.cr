module Zugpferd
  # Represents a trade party — either the seller (BG-4) or the buyer (BG-7).
  # Used for both `SellerTradeParty` and `BuyerTradeParty` in the CII XML.
  struct TradeParty
    # Legal or trading name of the party (BT-27 for seller, BT-44 for buyer).
    property name : String

    # Postal address (BG-5 for seller, BG-8 for buyer).
    # Required for BASIC_WL and above; only `country_id` is emitted for MINIMUM.
    property address : TradeAddress?

    # VAT and tax number registrations (BT-31/32 for seller, BT-63/64 for buyer).
    # At least one entry with scheme `VA` (VAT ID) is required for BASIC and above.
    property tax_registrations : Array(TaxRegistration)

    # Contact person name (BT-41). Only emitted for BASIC_WL and above.
    property contact_name : String?

    # Contact telephone number (BT-42). Only emitted for BASIC_WL and above.
    property contact_phone : String?

    # Contact e-mail address (BT-43). Only emitted for BASIC_WL and above.
    property contact_email : String?

    # Global identifier for the party (BT-29 for seller, BT-46 for buyer).
    # Common scheme codes: "0088" = GS1 GLN, "0060" = DUNS.
    property global_id : String?

    # Scheme identifier for `global_id` (BT-29-1 / BT-46-1), e.g. "0088".
    property global_id_scheme : String?

    # Electronic address used for routing (BT-34 for seller, BT-49 for buyer).
    # Scheme "EM" = e-mail; "9930" = DE:VAT (used in PEPPOL). Only emitted for BASIC_WL and above.
    property electronic_address : String?

    # Scheme identifier for `electronic_address` (BT-34-1 / BT-49-1); defaults to "EM".
    property electronic_address_scheme : String?

    def initialize(@name : String, *,
                   @address : TradeAddress? = nil,
                   @tax_registrations : Array(TaxRegistration) = [] of TaxRegistration,
                   @contact_name : String? = nil,
                   @contact_phone : String? = nil,
                   @contact_email : String? = nil,
                   @global_id : String? = nil,
                   @global_id_scheme : String? = nil,
                   @electronic_address : String? = nil,
                   @electronic_address_scheme : String? = nil)
    end
  end
end
