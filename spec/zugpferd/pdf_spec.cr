require "../spec_helper"
require "../../src/zugpferd/pdf"

{% if LibHaru.has_constant?("OutputIntent") %}
  describe Zugpferd::PdfEmbed do
    it "creates a PDF/A-3b file with the ZUGFeRD XML embedded" do
      xml = SpecHelper.minimal_invoice(Zugpferd::Profile::EN16931).to_xml
      tmp = File.tempfile("zugferd-embed-spec", ".pdf")
      begin
        Zugpferd::PdfEmbed.create(xml, tmp.path, &.add_page)
        bytes = File.read(tmp.path)
        bytes[0, 4].should eq("%PDF")
        bytes.should contain("factur-x.xml")
      ensure
        tmp.delete
      end
    end
  end
{% end %}
