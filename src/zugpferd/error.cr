module Zugpferd
  # Raised by `Validator#validate!` (and `Invoice#to_xml`) when EN 16931 business rules are violated.
  # `violations` lists every failed rule so callers can report all errors at once.
  class ValidationError < Exception
    getter violations : Array(String)

    def initialize(@violations : Array(String))
      super("ZUGFeRD validation failed:\n" + violations.map { |v| "  - #{v}" }.join("\n"))
    end
  end

  # Raised by `Invoice::Builder#build` when a required field (document, seller, buyer, or settlement)
  # has not been assigned before the build block exits.
  class GenerationError < Exception
  end

  # Raised by `Reader.from_xml` or `Reader.parse_profile` when the XML is structurally invalid
  # or a required element is missing. `field` names the offending XML element where known.
  class ParseError < Exception
    getter field : String?

    def initialize(message : String, @field : String? = nil)
      super(message)
    end
  end
end
