require "../spec_helper"

describe Zugpferd::TradeAddress do
  it "requires city and country_id" do
    addr = Zugpferd::TradeAddress.new("Berlin", "DE")
    addr.city.should eq("Berlin")
    addr.country_id.should eq("DE")
    addr.postcode.should be_nil
    addr.line_one.should be_nil
    addr.line_two.should be_nil
  end

  it "accepts optional address lines and postcode" do
    addr = Zugpferd::TradeAddress.new("Hamburg", "DE",
      postcode: "20095",
      line_one: "Mönckebergstr. 5",
      line_two: "Etage 3")
    addr.postcode.should eq("20095")
    addr.line_one.should eq("Mönckebergstr. 5")
    addr.line_two.should eq("Etage 3")
  end
end
