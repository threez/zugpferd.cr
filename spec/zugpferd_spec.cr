require "./spec_helper"

describe Zugpferd do
  it "has a version" do
    Zugpferd::VERSION.should eq("0.1.0")
  end

  it "builds and serializes a minimal invoice to XML" do
    invoice = SpecHelper.minimal_invoice(Zugpferd::Profile::MINIMUM)
    xml = invoice.to_xml
    xml.should contain("CrossIndustryInvoice")
    xml.should contain("INV-001")
    xml.should contain("Muster GmbH")
  end
end
