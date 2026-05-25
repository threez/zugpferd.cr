require "../spec_helper"

# Integration tests that shell out to the Mustang CLI validator.
# Set MUSTANG_JAR=/path/to/Mustang-CLI-X.Y.Z.jar to enable.
# Run via: make test-integration
describe "Mustang external validation" do
  describe "generated invoices" do
    Zugpferd::Profile.each do |profile|
      next if profile == Zugpferd::Profile::XRECHNUNG # no minimal fixture yet
      it "#{profile} minimal invoice passes Mustang validation" do
        pending! "MUSTANG_JAR not set or java not available" unless MustangValidator.available?
        xml = SpecHelper.minimal_invoice(profile).to_xml
        result = MustangValidator.validate(xml)
        result.errors.each { |e| fail e } unless result.valid
        result.valid.should be_true
      end
    end
  end

  describe "fixture files" do
    {% for profile_dir in ["minimum", "basic_wl", "basic", "en16931", "extended"] %}
      SpecHelper.fixture_files({{profile_dir}}).each do |path|
        it "fixture #{File.basename(path)} (#{{{profile_dir}}}) passes Mustang validation" do
          pending! "MUSTANG_JAR not set or java not available" unless MustangValidator.available?
          result = MustangValidator.validate(File.read(path))
          result.errors.each { |e| fail e } unless result.valid
          result.valid.should be_true
        end
      end
    {% end %}
  end
end
