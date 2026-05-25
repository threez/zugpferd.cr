module Zugpferd
  # A tax registration identifier for a trade party (BT-31/32 for seller, BT-63/64 for buyer).
  struct TaxRegistration
    # Scheme identifying the type of tax registration number.
    # `VA` = VAT identification number (USt-IdNr, e.g. "DE123456789") — BT-31/63.
    # `FC` = Local tax number (Steuernummer, e.g. "123/456/78901") — BT-32/64.
    enum SchemeID
      VA
      FC
    end

    # The scheme type for this registration (see `SchemeID`).
    property scheme_id : SchemeID

    # The registration number, e.g. "DE123456789" for a German VAT ID.
    property id : String

    def initialize(@scheme_id : SchemeID, @id : String)
    end
  end
end
