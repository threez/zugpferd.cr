require "../spec_helper"

describe Zugpferd::TradeParty do
  it "requires only a name" do
    party = Zugpferd::TradeParty.new("ACME Corp")
    party.name.should eq("ACME Corp")
    party.address.should be_nil
    party.tax_registrations.should be_empty
  end

  it "accepts multiple tax registrations" do
    regs = [
      Zugpferd::TaxRegistration.new(Zugpferd::TaxRegistration::SchemeID::VA, "DE123456789"),
      Zugpferd::TaxRegistration.new(Zugpferd::TaxRegistration::SchemeID::FC, "123/456/78901"),
    ]
    party = Zugpferd::TradeParty.new("ACME Corp", tax_registrations: regs)
    party.tax_registrations.size.should eq(2)
    party.tax_registrations.first.scheme_id.should eq(Zugpferd::TaxRegistration::SchemeID::VA)
  end
end
