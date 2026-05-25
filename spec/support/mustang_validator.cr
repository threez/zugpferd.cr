module MustangValidator
  MUSTANG_JAR = ENV["MUSTANG_JAR"]?

  record Result, valid : Bool, errors : Array(String)

  def self.available? : Bool
    return false unless jar = MUSTANG_JAR
    File.exists?(jar) && system("java -version > /dev/null 2>&1")
  end

  def self.validate(xml_string : String) : Result
    jar = MUSTANG_JAR || raise "MUSTANG_JAR not set"
    file = File.tempfile("zugpferd-validate", ".xml") do |tmp|
      tmp.print(xml_string)
    end
    begin
      output = IO::Memory.new
      status = Process.run("java", ["-jar", jar, "--action=validate", "--source=#{file.path}"],
        output: output, error: Process::Redirect::Close)
      parse_report(output.to_s, status.exit_code)
    ensure
      file.delete
    end
  end

  private def self.parse_report(raw : String, exit_code : Int32) : Result
    # Find start of XML (Mustang may emit log lines before the XML)
    xml_start = raw.index("<validation") || raw.index("<?xml")
    unless xml_start
      return Result.new(valid: false, errors: ["No XML report produced: #{raw.strip}"])
    end
    doc = XML.parse(raw[xml_start..])
    summary = doc.xpath_node("//summary")
    is_valid = summary.try(&.["status"]?) == "valid" && exit_code == 0
    errors = doc.xpath_nodes("//error").map(&.content.strip)
    Result.new(valid: is_valid, errors: errors)
  rescue XML::Error
    Result.new(valid: false, errors: ["Failed to parse Mustang report: #{raw.strip[0, 200]}"])
  end
end
