require "hpdf"
require "../zugpferd"

module Zugpferd
  # Embeds a ZUGFeRD/Factur-X CII XML into a PDF/A-3b document.
  #
  # libharu is a write-only library, so the entire PDF must be generated within
  # a single session. Use `PdfEmbed.create` and draw all invoice pages inside
  # the block:
  #
  # ```
  # xml = invoice.to_xml
  # Zugpferd::PdfEmbed.create(xml, "invoice.pdf") do |doc|
  #   page = doc.add_page
  #   # draw invoice layout on page...
  # end
  # ```
  module PdfEmbed
    # Filename used for the embedded XML attachment (Factur-X specification requirement).
    XML_FILENAME = "factur-x.xml"
    XML_SUBTYPE  = "text/xml"

    # Creates a PDF/A-3b file at *out_path* with *xml* embedded as `factur-x.xml`.
    # Yields an `Hpdf::Doc` so the caller can draw invoice content before saving.
    def self.create(xml : String, out_path : String, &) : Nil
      tmp = File.tempfile("zugferd", ".xml", &.print(xml))
      begin
        doc = Hpdf::Doc.new
        doc.pdfa_conformance = Hpdf::PDFAConformance::PDFA_3B
        doc.add_xmp_extension(facturx_xmp)
        yield doc
        doc.attach_file(tmp.path,
          name: XML_FILENAME,
          subtype: XML_SUBTYPE,
          relationship: Hpdf::AFRelationship::Alternative,
          creation_date: Time.utc,
          modification_date: Time.utc)
        doc.save_to_file(out_path)
      ensure
        tmp.delete
      end
    end

    # Minimal Factur-X XMP extension namespace block required by the specification.
    private def self.facturx_xmp : String
      <<-XML
      <rdf:Description rdf:about=""
          xmlns:fx="urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#">
        <fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>
        <fx:DocumentType>INVOICE</fx:DocumentType>
        <fx:Version>1.0</fx:Version>
        <fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>
      </rdf:Description>
      XML
    end
  end
end
