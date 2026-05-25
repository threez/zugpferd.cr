module Zugpferd
  # Invoice header metadata: number, date, document type, notes, and buyer reference.
  # Corresponds to the `ExchangedDocument` section of the CII XML.
  struct ExchangedDocument
    # UNTDID 1001 document type codes. Use as `type_code:` in the constructor.
    INVOICE_TYPE_CODE     = "380" # Commercial invoice (default)
    CREDIT_NOTE_TYPE_CODE = "381" # Credit note
    CORRECTION_TYPE_CODE  = "384" # Corrected invoice

    # Invoice number assigned by the seller (BT-1). Must be unique within the seller's system.
    property id : String

    # Document type code (BT-3). UNTDID 1001 value; use the constants above or a raw string.
    property type_code : String

    # Invoice issue date (BT-2). Formatted as YYYYMMDD with format code 102 in the XML.
    property issue_date : Time

    # Free-text notes attached to the invoice (BT-22). Multiple notes are supported.
    property notes : Array(String)

    # Buyer's routing reference (BT-10). Required for XRECHNUNG (Leitweg-ID);
    # also used as remittance advice reference in some buyer systems.
    property buyer_reference : String?

    def initialize(@id : String,
                   @issue_date : Time, *,
                   @type_code : String = INVOICE_TYPE_CODE,
                   @notes : Array(String) = [] of String,
                   @buyer_reference : String? = nil)
    end
  end
end
