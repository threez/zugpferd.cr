require "../spec_helper"

# Compliance tests parse official/reference ZUGFeRD fixture XML files and
# verify structural correctness. These are read-only parse tests; round-trip
# generation tests are in generator_spec.cr.
describe "ZUGFeRD fixture compliance" do
  {% for profile_dir in ["minimum", "basic_wl", "basic", "en16931", "extended"] %}
    describe {{profile_dir}} do
      fixtures = SpecHelper.fixture_files({{profile_dir}})

      if fixtures.empty?
        pending "no fixture files found in spec/fixtures/#{{{profile_dir}}}/"
      else
        fixtures.each do |fixture_path|
          it "parses #{File.basename(fixture_path)} as well-formed XML" do
            xml_str = File.read(fixture_path)
            doc = XML.parse(xml_str)
            root = doc.first_element_child
            root.should_not be_nil
            root.not_nil!.name.should eq("CrossIndustryInvoice")
          end

          it "#{File.basename(fixture_path)} contains a GuidelineSpecifiedDocumentContextParameter ID" do
            xml_str = File.read(fixture_path)
            xml_str.should contain("GuidelineSpecifiedDocumentContextParameter")
            has_profile_uri = xml_str.includes?("urn:factur-x.eu") || xml_str.includes?("urn:cen.eu:en16931") || xml_str.includes?("urn:xoev-de:kosit")
            has_profile_uri.should be_true
          end

          it "#{File.basename(fixture_path)} has invoice ID and TypeCode" do
            xml_str = File.read(fixture_path)
            xml_str.should contain("<ram:ID>")
            xml_str.should contain("<ram:TypeCode>380</ram:TypeCode>")
          end

          it "#{File.basename(fixture_path)} has a date in format 102" do
            xml_str = File.read(fixture_path)
            xml_str.should contain(%[format="102"])
          end

          it "#{File.basename(fixture_path)} has monetary summation" do
            xml_str = File.read(fixture_path)
            xml_str.should contain("SpecifiedTradeSettlementHeaderMonetarySummation")
          end
        end
      end
    end
  {% end %}
end
