require "./spec_helper"

# Example case yaml inputs to be parsed by this kyaml shard are stored in spec/fixtures/compatibility/v0.3.x/x.input.yaml
# Example case kyaml expected outputs are stored in spec/fixtures/compatibility/v0.3.x/x.output.kyaml
# Inline fixtures in this spec are the expected post-parsing but pre-emission internal kyaml structure.
describe "KYAML 0.3.x compatibility" do
  describe "baseline functionality" do
    fixture_dir = File.join(__DIR__, "fixtures", "compatibility", "v0.3.x")

    fixtures = [
      {
        name: "mapping-comments",
        root: KYAML::Any.new({
          "apiVersion" => KYAML::Any.new("v1"),
          "metadata"   => KYAML::Any.new({
            "name"   => KYAML::Any.new("demo"),
            "labels" => KYAML::Any.new({
              "app" => KYAML::Any.new("demo"),
            }),
          }),
          "replicas" => KYAML::Any.new(2),
        }),
        comments: [
          KYAML::Comment.new(" service settings", 1, 1),
          KYAML::Comment.new(" API version", 3, 1),
          KYAML::Comment.new(" stable API", 4, 16),
          KYAML::Comment.new(" service identity", 6, 3),
          KYAML::Comment.new(" display name", 7, 14),
          KYAML::Comment.new(" labels tail", 10, 5),
          KYAML::Comment.new(" metadata tail", 11, 3),
          KYAML::Comment.new(" next sibling", 12, 1),
          KYAML::Comment.new(" mapping tail", 14, 1),
        ],
      },
      {
        name:     "empty-mapping",
        root:     KYAML::Any.new({} of String => KYAML::Any),
        comments: [] of KYAML::Comment,
      },
      {
        name:     "empty-sequence",
        root:     KYAML::Any.new([] of KYAML::Any),
        comments: [] of KYAML::Comment,
      },
    ]

    fixtures.each do |fixture|
      name = fixture[:name]

      it "parses #{name} input fixture into matching inline fixture values and comments" do
        input = File.read(File.join(fixture_dir, "#{name}.input.yaml"))

        KYAML.parse(input).should eq(fixture[:root])

        [
          KYAML.parse_doc(input),
          KYAML.parse_doc(IO::Memory.new(input)),
        ].each do |doc|
          doc.root.should eq(fixture[:root])
          doc.comments.should eq(fixture[:comments])
        end
      end

      it "multiple #{name} input fixture parse-emision trips match baseline output fixtures" do
        input = File.read(File.join(fixture_dir, "#{name}.input.yaml"))
        expected_output = File.read(File.join(fixture_dir, "#{name}.output.kyaml"))
        doc = KYAML.parse_doc(input)

        3.times do
          KYAML.emit_doc(doc).should eq(expected_output)
          doc.to_kyaml.should eq(expected_output)

          emitted = IO::Memory.new
          KYAML.emit_doc(doc, emitted)
          emitted.to_s.should eq(expected_output)

          converted = IO::Memory.new
          doc.to_kyaml(converted)
          converted.to_s.should eq(expected_output)

          doc.root.should eq(fixture[:root])
          doc.comments.should eq(fixture[:comments])
        end
      end

      it "roundtrip reparsing #{name} matches expected root, comments, and emitted output" do
        input = File.read(File.join(fixture_dir, "#{name}.input.yaml"))
        expected_output = File.read(File.join(fixture_dir, "#{name}.output.kyaml"))
        original = KYAML.parse_doc(input)
        reparsed = KYAML.parse_doc(KYAML.emit_doc(original))

        reparsed.root.should eq(fixture[:root])
        reparsed.comments.map(&.text).should eq(fixture[:comments].map(&.text))
        KYAML.emit_doc(reparsed).should eq(expected_output)
      end
    end

    it "keeps root and nested mapping order consistent across roundtrips" do
      input = File.read(File.join(fixture_dir, "mapping-comments.input.yaml"))
      original = KYAML.parse_doc(input)
      reparsed = KYAML.parse_doc(KYAML.emit_doc(original))

      [original, reparsed].each do |doc|
        root = doc.root
        root.as_h.keys.should eq(["apiVersion", "metadata", "replicas"])
        root["metadata"].as_h.keys.should eq(["name", "labels"])
        root["metadata"]["labels"].as_h.keys.should eq(["app"])
      end
    end

    it "raises on the malformed fixture for both #parse and #parse_doc" do
      input = File.read(File.join(fixture_dir, "malformed.input.yaml"))

      expect_raises(KYAML::ParseError) { KYAML.parse(input) }
      expect_raises(KYAML::ParseError) { KYAML.parse(IO::Memory.new(input)) }
      expect_raises(KYAML::ParseError) { KYAML.parse_doc(input) }
      expect_raises(KYAML::ParseError) { KYAML.parse_doc(IO::Memory.new(input)) }
    end
  end

  describe "duplicate key handling" do
    fixture_dir = File.join(__DIR__, "fixtures", "compatibility", "v0.3.x")

    scalar_root = KYAML::Any.new({
      "target" => KYAML::Any.new("new"),
      "keep"   => KYAML::Any.new(true),
    })

    subtree_root = KYAML::Any.new({
      "target" => KYAML::Any.new({
        "new" => KYAML::Any.new(2),
      }),
      "keep" => KYAML::Any.new(true),
    })

    colliding_root = KYAML::Any.new({
      "1"    => KYAML::Any.new("new"),
      "keep" => KYAML::Any.new(true),
    })

    fixtures = [
      {
        name:                 "duplicate-keys",
        root:                 scalar_root,
        source_comments:      [] of KYAML::Comment,
        emitted_comment_text: [] of String,
      },
      {
        name:            "duplicate-commented-key",
        root:            scalar_root,
        source_comments: [
          KYAML::Comment.new(" discarded", 1, 13),
          KYAML::Comment.new(" keep", 2, 12),
          KYAML::Comment.new(" winning dupe", 3, 13),
        ],
        emitted_comment_text: [
          " discarded",
          " keep",
        ],
      },
      {
        name:                 "duplicate-subtree",
        root:                 subtree_root,
        source_comments:      [] of KYAML::Comment,
        emitted_comment_text: [] of String,
      },
      {
        name:            "duplicate-commented-subtree",
        root:            subtree_root,
        source_comments: [
          KYAML::Comment.new(" discarded subtree", 2, 3),
          KYAML::Comment.new(" winning subtree", 6, 3),
        ],
        emitted_comment_text: [" discarded subtree"],
      },
      {
        name:                 "colliding-scalar-keys",
        root:                 colliding_root,
        source_comments:      [] of KYAML::Comment,
        emitted_comment_text: [] of String,
      },
      {
        name:            "colliding-commented-scalar-keys",
        root:            colliding_root,
        source_comments: [
          KYAML::Comment.new(" discarded", 1, 8),
          KYAML::Comment.new(" winning", 3, 11),
        ],
        emitted_comment_text: [" discarded"],
      },
    ]

    fixtures.each do |fixture|
      name = fixture[:name]

      it "parsed #{name} input fixtures match the inline intermediate fixture" do
        input = File.read(File.join(fixture_dir, "#{name}.input.yaml"))

        KYAML.parse(input).should eq(fixture[:root])

        [
          KYAML.parse_doc(input),
          KYAML.parse_doc(IO::Memory.new(input)),
        ].each do |doc|
          root = doc.root
          root.should eq(fixture[:root])
          root.as_h.keys.should eq(fixture[:root].as_h.keys)
          doc.comments.should eq(fixture[:source_comments])
        end
      end

      it "repeated roundtrip #{name} emission matches the output baseline" do
        input = File.read(File.join(fixture_dir, "#{name}.input.yaml"))
        expected_output = File.read(File.join(fixture_dir, "#{name}.output.kyaml"))
        doc = KYAML.parse_doc(input)

        3.times do
          KYAML.emit_doc(doc).should eq(expected_output)
          doc.to_kyaml.should eq(expected_output)

          emitted = IO::Memory.new
          KYAML.emit_doc(doc, emitted)
          emitted.to_s.should eq(expected_output)

          converted = IO::Memory.new
          doc.to_kyaml(converted)
          converted.to_s.should eq(expected_output)

          root = doc.root
          root.should eq(fixture[:root])
          root.as_h.keys.should eq(fixture[:root].as_h.keys)
          doc.comments.should eq(fixture[:source_comments])
        end
      end

      it "roundtrip reparsing #{name} matches expected root, keys, comments, and emitted output" do
        input = File.read(File.join(fixture_dir, "#{name}.input.yaml"))
        expected_output = File.read(File.join(fixture_dir, "#{name}.output.kyaml"))
        original = KYAML.parse_doc(input)
        reparsed = KYAML.parse_doc(KYAML.emit_doc(original))

        root = reparsed.root
        root.should eq(fixture[:root])
        root.as_h.keys.should eq(fixture[:root].as_h.keys)
        reparsed.comments.map(&.text).should eq(fixture[:emitted_comment_text])
        KYAML.emit_doc(reparsed).should eq(expected_output)
      end
    end

    it "rejects a non-scalar key through value and doc parsing" do
      input = File.read(File.join(fixture_dir, "non-scalar-key.input.yaml"))

      expect_raises(KYAML::NonStringKeyError) { KYAML.parse(input) }
      expect_raises(KYAML::NonStringKeyError) { KYAML.parse(IO::Memory.new(input)) }
      expect_raises(KYAML::NonStringKeyError) { KYAML.parse_doc(input) }
      expect_raises(KYAML::NonStringKeyError) { KYAML.parse_doc(IO::Memory.new(input)) }
    end
  end
end
