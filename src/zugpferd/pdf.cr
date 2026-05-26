require "hpdf"
require "../zugpferd"

module Zugpferd
  # Embeds a ZUGFeRD/Factur-X CII XML into a PDF/A-3b document.
  #
  # The entire PDF is generated in one libharu session with proper PDF/A-3b
  # conformance: XMP metadata, an sRGB `/OutputIntents` entry, the Factur-X
  # XMP extension namespace, and the XML attached as `factur-x.xml`.
  #
  # ```
  # xml = invoice.to_xml
  # Zugpferd::PdfEmbed.create(xml, "invoice.pdf") do |doc|
  #   page = doc.add_page
  #   # draw invoice layout on page...
  # end
  # ```
  module PdfEmbed
    # Filename required by the Factur-X specification for the embedded XML.
    XML_FILENAME = "factur-x.xml"

    # Path to the bundled sRGB ICC profile used for the PDF/A `/OutputIntents`.
    ICC_PROFILE = File.join(__DIR__, "assets", "device_rgb.icc")

    # Creates a conformant PDF/A-3b file at *out_path* with *xml* embedded
    # as `factur-x.xml`.
    #
    # Yields an `Hpdf::Doc` so the caller can draw invoice content before
    # the document is saved. At least one page must be added inside the block.
    def self.create(xml : String, out_path : String, &) : Nil
      xml_tmp = File.tempfile("zugferd", ".xml", &.print(xml))
      begin
        doc = Hpdf::Doc.new

        yield doc

        # A non-empty Creator info attribute is required for libharu to emit the
        # /Metadata XMP stream that PDF/A-3b mandates.
        LibHaru.set_info_attr(doc, Hpdf::InfoType::Creator.value.to_u32, "zugpferd")

        # PDF/A-3b conformance must be set after pages are added (libharu requirement)
        LibHaru.set_pdfa_conformance(doc, LibHaru::PDFAType::PDFA_3B)

        # Required sRGB output intent (PDF/A mandates an /OutputIntents entry)
        icc = LibHaru.load_icc_profile_from_file(doc, ICC_PROFILE, 3)
        LibHaru.append_output_intents(doc, "sRGB", icc)

        # Factur-X XMP extension: schema declaration + invoice metadata
        LibHaru.add_pdfa_xmp_extension(doc, facturx_schema_xmp)
        LibHaru.add_pdfa_xmp_extension(doc, facturx_data_xmp)

        # Attach the ZUGFeRD XML with AFRelationship=Alternative (spec requirement)
        ef = LibHaru.attach_file(doc, xml_tmp.path)
        LibHaru.embedded_file_set_name(ef, XML_FILENAME)
        LibHaru.embedded_file_set_subtype(ef, "text/xml")
        LibHaru.embedded_file_set_af_relationship(ef, LibHaru::AFRelationship::Alternative)

        doc.save_to_file(out_path)
      ensure
        xml_tmp.delete
      end
    end

    # Factur-X PDF/A extension schema declaration block (required by PDF/A-3b spec).
    private def self.facturx_schema_xmp : String
      "<rdf:Description xmlns:pdfaExtension=\"http://www.aiim.org/pdfa/ns/extension/\" xmlns:pdfaSchema=\"http://www.aiim.org/pdfa/ns/schema#\" xmlns:pdfaProperty=\"http://www.aiim.org/pdfa/ns/property#\" rdf:about=\"\">" \
      "  <pdfaExtension:schemas>" \
      "    <rdf:Bag>" \
      "      <rdf:li rdf:parseType=\"Resource\">" \
      "        <pdfaSchema:schema>Factur-X PDFA Extension Schema</pdfaSchema:schema>" \
      "        <pdfaSchema:namespaceURI>urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#</pdfaSchema:namespaceURI>" \
      "        <pdfaSchema:prefix>fx</pdfaSchema:prefix>" \
      "        <pdfaSchema:property>" \
      "          <rdf:Seq>" \
      "            <rdf:li rdf:parseType=\"Resource\">" \
      "              <pdfaProperty:name>DocumentFileName</pdfaProperty:name>" \
      "              <pdfaProperty:valueType>Text</pdfaProperty:valueType>" \
      "              <pdfaProperty:category>external</pdfaProperty:category>" \
      "              <pdfaProperty:description>The name of the embedded XML document</pdfaProperty:description>" \
      "            </rdf:li>" \
      "            <rdf:li rdf:parseType=\"Resource\">" \
      "              <pdfaProperty:name>DocumentType</pdfaProperty:name>" \
      "              <pdfaProperty:valueType>Text</pdfaProperty:valueType>" \
      "              <pdfaProperty:category>external</pdfaProperty:category>" \
      "              <pdfaProperty:description>The type of the hybrid document in capital letters, e.g. INVOICE or ORDER</pdfaProperty:description>" \
      "            </rdf:li>" \
      "            <rdf:li rdf:parseType=\"Resource\">" \
      "              <pdfaProperty:name>Version</pdfaProperty:name>" \
      "              <pdfaProperty:valueType>Text</pdfaProperty:valueType>" \
      "              <pdfaProperty:category>external</pdfaProperty:category>" \
      "              <pdfaProperty:description>The actual version of the standard applying to the embedded XML document</pdfaProperty:description>" \
      "            </rdf:li>" \
      "            <rdf:li rdf:parseType=\"Resource\">" \
      "              <pdfaProperty:name>ConformanceLevel</pdfaProperty:name>" \
      "              <pdfaProperty:valueType>Text</pdfaProperty:valueType>" \
      "              <pdfaProperty:category>external</pdfaProperty:category>" \
      "              <pdfaProperty:description>The conformance level of the embedded XML document</pdfaProperty:description>" \
      "            </rdf:li>" \
      "          </rdf:Seq>" \
      "        </pdfaSchema:property>" \
      "      </rdf:li>" \
      "    </rdf:Bag>" \
      "  </pdfaExtension:schemas>" \
      "</rdf:Description>"
    end

    # Factur-X XMP invoice metadata block.
    private def self.facturx_data_xmp : String
      "<rdf:Description xmlns:fx=\"urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#\" rdf:about=\"\">" \
      "  <fx:DocumentType>INVOICE</fx:DocumentType>" \
      "  <fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>" \
      "  <fx:Version>1.0</fx:Version>" \
      "  <fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>" \
      "</rdf:Description>"
    end
  end
end
