module Zugpferd
  # Postal address for a trade party (BG-5 for seller, BG-8 for buyer).
  # Only `country_id` is emitted for MINIMUM profile; all fields are available for BASIC_WL and above.
  struct TradeAddress
    # First address line, e.g. street and house number (BT-35 seller / BT-50 buyer).
    property line_one : String?

    # Second address line for additional information (BT-36 seller / BT-51 buyer).
    property line_two : String?

    # Postal/ZIP code (BT-38 seller / BT-53 buyer).
    property postcode : String?

    # City or municipality name (BT-37 seller / BT-52 buyer).
    property city : String

    # ISO 3166-1 alpha-2 country code (BT-40 seller / BT-55 buyer), e.g. "DE", "FR", "AT".
    property country_id : String

    def initialize(@city : String, @country_id : String, *,
                   @line_one : String? = nil,
                   @line_two : String? = nil,
                   @postcode : String? = nil)
    end
  end
end
