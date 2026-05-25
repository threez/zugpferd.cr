module Zugpferd
  # ZUGFeRD 2.x / Factur-X compliance profile, ordered from least to most permissive.
  # The integer backing value enables the `at_least?` comparison used throughout the
  # generator and validator to gate optional and profile-specific fields.
  #
  # - `MINIMUM`    — Only mandatory identification fields: invoice number, date, seller/buyer
  #                  names and country, currency, and the monetary summation. No line items.
  # - `BASIC_WL`   — Adds postal address, tax registrations, payment means, taxes, and
  #                  payment terms. No line items ("Without Lines").
  # - `BASIC`      — Adds line items (`IncludedSupplyChainTradeLineItem`).
  #                  Delivery date is required (BR-FX-EN-04).
  # - `EN16931`    — Full EN 16931 Comfort profile. Adds electronic addresses, buyer address
  #                  detail, and full payment term descriptions.
  # - `EXTENDED`   — All EN 16931 fields plus additional elements not in the core standard.
  # - `XRECHNUNG`  — German public-sector e-invoicing standard (XRechnung 3.0).
  #                  Requires Leitweg-ID in `buyer_reference` (BT-10) and seller contact.
  enum Profile
    MINIMUM   # urn:factur-x.eu:1p0:minimum
    BASIC_WL  # urn:factur-x.eu:1p0:basicwl
    BASIC     # urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic
    EN16931   # urn:cen.eu:en16931:2017 (also called COMFORT)
    EXTENDED  # urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended
    XRECHNUNG # urn:cen.eu:en16931:2017#compliant#urn:xoev-de:kosit:standard:xrechnung_3.0

    # Returns `true` if this profile is at least as permissive as *other*.
    # Used throughout the generator and validator to gate optional fields;
    # e.g. `profile.at_least?(Profile::BASIC_WL)` guards payment means output.
    def at_least?(other : Profile) : Bool
      value >= other.value
    end

    # Returns `true` for `EN16931`. Alias for the Factur-X "Comfort" terminology.
    def comfort? : Bool
      self == EN16931
    end

    # Returns the canonical guideline URI for this profile (BT-24).
    # Embedded in the XML as `GuidelineSpecifiedDocumentContextParameter/ID`.
    def guideline_id : String
      case self
      in MINIMUM   then "urn:factur-x.eu:1p0:minimum"
      in BASIC_WL  then "urn:factur-x.eu:1p0:basicwl"
      in BASIC     then "urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic"
      in EN16931   then "urn:cen.eu:en16931:2017"
      in EXTENDED  then "urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended"
      in XRECHNUNG then "urn:cen.eu:en16931:2017#compliant#urn:xoev-de:kosit:standard:xrechnung_3.0"
      end
    end
  end
end
