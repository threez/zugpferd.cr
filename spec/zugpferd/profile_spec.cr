require "../spec_helper"

describe Zugpferd::Profile do
  describe "#at_least?" do
    it "is always true for self" do
      Zugpferd::Profile.each do |profile|
        profile.at_least?(profile).should be_true
      end
    end

    it "MINIMUM is the lowest" do
      Zugpferd::Profile::MINIMUM.at_least?(Zugpferd::Profile::MINIMUM).should be_true
      Zugpferd::Profile::BASIC.at_least?(Zugpferd::Profile::MINIMUM).should be_true
      Zugpferd::Profile::MINIMUM.at_least?(Zugpferd::Profile::BASIC).should be_false
    end

    it "XRECHNUNG is the highest" do
      Zugpferd::Profile::XRECHNUNG.at_least?(Zugpferd::Profile::EXTENDED).should be_true
      Zugpferd::Profile::EXTENDED.at_least?(Zugpferd::Profile::XRECHNUNG).should be_false
    end
  end

  describe "#comfort?" do
    it "is only true for EN16931" do
      Zugpferd::Profile::EN16931.comfort?.should be_true
      Zugpferd::Profile::EXTENDED.comfort?.should be_false
    end
  end

  describe "#guideline_id" do
    it "returns correct URN for each profile" do
      Zugpferd::Profile::MINIMUM.guideline_id.should eq("urn:factur-x.eu:1p0:minimum")
      Zugpferd::Profile::EN16931.guideline_id.should contain("en16931")
      Zugpferd::Profile::XRECHNUNG.guideline_id.should contain("xrechnung")
    end
  end
end
