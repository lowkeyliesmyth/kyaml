require "./spec_helper"

describe "KYAML integration" do
  describe "round trip (parse -> emit -> parse)" do
    it "preserves a nested structure of mixed scalar types" do
      input = <<-KYAML
        {
          name: "svc",
          replicas: 3,
          ratio: 1.5,
          enabled: true,
          note: null,
          ports: [80, 443],
          meta: {
            tier: "backend",
          },
        }
        KYAML
      first = KYAML.parse(input)
      second = KYAML.parse(KYAML.emit(first.raw))
      second.should eq(first)
    end
  end

  describe "Norway-bug and ambiguous scalar quoting" do
    it "emits ambiguous string values qyoted so they round-trip as strings" do
      %w[NO no N YES yes Y On Off].each do |word|
        emitted = KYAML.emit(word)
        emitted.should eq(%("#{word}"))
        KYAML.parse(emitted).raw.should eq(word)
      end
    end

    it "emits time sexagesimal strings as quoted" do
      KYAML.emit("11:00").should eq(%("11:00"))
      KYAML.parse(KYAML.emit("11:00")).raw.should eq("11:00")
    end

    it "emits timestamp-like strings as quoted" do
      KYAML.emit("2026-01-01").should eq(%("2026-01-01"))
      KYAML.parse(KYAML.emit("2026-01-01")).raw.should eq("2026-01-01")
    end
  end

  describe "comment round trip (parse -> emit -> parse)" do
    it "preserves a leading comment" do
      input = <<-YAML
        ---
        # leading
        foo: 1

        YAML
      rt = KYAML.parse_doc(KYAML.parse_doc(input).to_kyaml)
      rt.comments.map(&.text).should eq([" leading"])
    end

    it "preserves a trailing/inline comment" do
      input = <<-YAML
        foo: 1 # trailing

        YAML
      rt = KYAML.parse_doc(KYAML.parse_doc(input).to_kyaml)
      rt.comments.map(&.text).should eq([" trailing"])
    end

    it "preserves a standalone comment between siblings" do
      input = <<-YAML
        outer:
          foo: 1
          bar: 2
          # tail

        YAML
      rt = KYAML.parse_doc(KYAML.parse_doc(input).to_kyaml)
      rt.comments.map(&.text).should eq([" tail"])
    end

    it "preserves a doc-header comment" do
      input = <<-YAML
        ---
        # header
        foo: 1

        YAML
      rt = KYAML.parse_doc(KYAML.parse_doc(input).to_kyaml)
      rt.comments.map(&.text).should eq([" header"])
    end

    it "preserves per-doc comments across a multi-doc stream" do
      input = <<-YAML
        # doc one
        ---
        a: 1
        ---
        # doc two
        b: 2
        YAML
      docs = KYAML.parse_all_docs(input)
      rt = KYAML.parse_all_docs(KYAML.emit_all_docs(docs))
      rt.map { |doc| doc.comments.map(&.text) }.should eq([[" doc one"], [" doc two"]])
    end

    it "preserves comments at every nesting depth of a doc" do
      input = <<-YAML
        # header comment
        ---
        # leading on apiVersion
        apiVersion: v1
        kind: Service
        metadata:
          # leading on name
          name: my-service # trailing on name
          spec:
            ports:
            - port: 80 # trailing on port
              # tail on port
        YAML
      doc = KYAML.parse_doc(input)
      rt = KYAML.parse_doc(doc.to_kyaml)
      rt.comments.map(&.text).should eq(doc.comments.map(&.text))
    end
  end
end
