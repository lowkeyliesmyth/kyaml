require "./spec_helper"

describe KYAML::MutationOperation do
  it "defines the supported managed operations" do
    KYAML::MutationOperation.names.sort.should eq([
      "Delete",
      "Rename",
      "Set",
    ])
  end
end

describe KYAML::UnsupportedDocReason do
  it "defines the explicit unsupported-doc reasons" do
    KYAML::UnsupportedDocReason.names.sort.should eq([
      "AmbiguousCommentOwner",
      "MissingCommentSource",
      "UnsupportedCommentPlacement",
    ])
  end
end

describe KYAML::MutationError do
  it "copies its path independent of later caller changes" do
    path = ["metadata", "a.b", "a/b", "", "Name"]
    error = KYAML::MutationError.new(
      KYAML::MutationOperation::Set,
      path,
      "mutation failed"
    )

    error.operation.should eq(KYAML::MutationOperation::Set)
    error.path.should eq(path)
    error.path.should_not be(path)

    path[0] = "changed"
    path << "later"

    error.path.should eq(["metadata", "a.b", "a/b", "", "Name"])
  end

  it "accepts an Indexable type path more than just Arrays" do
    error = KYAML::MutationError.new(
      KYAML::MutationOperation::Rename,
      {"spec", "name"},
      "mutation failed"
    )

    error.path.should eq(["spec", "name"])
  end

  it "path remains separate from caller even if it's empty" do
    path = [] of String
    error = KYAML::MutationError.new(
      KYAML::MutationOperation::Delete,
      path,
      "mutation failed"
    )

    path << "later"

    error.path.should be_empty
    error.path.should_not be(path)
  end

  it "preserves the originating exception and can be rescued as a KYAML error, not the original error" do
    cause = Exception.new("originating failure point")
    error = KYAML::MutationError.new(
      KYAML::MutationOperation::Set,
      ["name"],
      "mutation failed",
      cause
    )

    raised = expect_raises(KYAML::Error) do
      raise error
    end

    raised.should be(error)
    error.cause.should be(cause)
    error.message.should eq("mutation failed")
  end

  it "allows a failure without an originating exception" do
    error = KYAML::MutationError.new(
      KYAML::MutationOperation::Delete,
      ["name"],
      "mutation failed"
    )

    error.cause.should be_nil
  end
end

describe KYAML::UnsupportedDocError do
  it "records the op, path, reason, and source diagnostic coordinates" do
    error = KYAML::UnsupportedDocError.new(
      KYAML::MutationOperation::Rename,
      ["spec", "name"],
      KYAML::UnsupportedDocReason::MissingCommentSource,
      source_line: 4,
      source_column: 20,
    )

    error.operation.should eq(KYAML::MutationOperation::Rename)
    error.path.should eq(["spec", "name"])
    error.reason.should be_a(KYAML::UnsupportedDocReason)
    error.reason.should eq(KYAML::UnsupportedDocReason::MissingCommentSource)
    error.source_line.should eq(4)
    error.source_column.should eq(20)
  end

  it "allows missing diagnostic coordinates" do
    error = KYAML::UnsupportedDocError.new(
      KYAML::MutationOperation::Set,
      ["name"],
      KYAML::UnsupportedDocReason::AmbiguousCommentOwner
    )

    error.source_line.should be_nil
    error.source_column.should be_nil
  end

  it "copies its path independent of later caller changes" do
    path = ["name", "foobar"]
    error = KYAML::UnsupportedDocError.new(
      KYAML::MutationOperation::Delete,
      path,
      KYAML::UnsupportedDocReason::UnsupportedCommentPlacement,
    )

    path.clear

    error.path.should eq(["name", "foobar"])
    error.path.should_not be(path)
  end

  it "can be rescued through shared mutation-error contract" do
    error = KYAML::UnsupportedDocError.new(
      KYAML::MutationOperation::Delete,
      ["name"],
      KYAML::UnsupportedDocReason::UnsupportedCommentPlacement,
    )

    raised = expect_raises(KYAML::MutationError) do
      raise error
    end

    raised.should be(error)
    raised.operation.should eq(KYAML::MutationOperation::Delete)
    raised.path.should eq(["name"])
  end
end
