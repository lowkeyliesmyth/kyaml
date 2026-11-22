require "./spec_helper"

describe KYAML::MutationOperation do
  it "lists the supported managed operations" do
    KYAML::MutationOperation.names.sort.should eq([
      "Delete",
      "Rename",
      "Set",
    ])
  end
end

describe KYAML::UnsupportedDocReason do
  it "names the three reasons a doc can be unsupported" do
    KYAML::UnsupportedDocReason.names.sort.should eq([
      "AmbiguousCommentOwner",
      "MissingCommentSource",
      "UnsupportedCommentPlacement",
    ])
  end
end

describe KYAML::MutationError do
  it "keeps its own copy of the path when the caller changes the original" do
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

  it "accepts an Indexable type path over just Arrays" do
    error = KYAML::MutationError.new(
      KYAML::MutationOperation::Rename,
      {"spec", "name"},
      "mutation failed"
    )

    error.path.should eq(["spec", "name"])
  end

  it "keeps an empty path separate from the caller's list" do
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

  it "keeps the original exception as the cause and is caught as a KYAML error" do
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

  it "has no cause when no original exception is given" do
    error = KYAML::MutationError.new(
      KYAML::MutationOperation::Delete,
      ["name"],
      "mutation failed"
    )

    error.cause.should be_nil
  end
end

describe KYAML::UnsupportedDocError do
  it "keeps the operation, path, reason, and source line and column it was given" do
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

  it "leaves the source line and column empty when they are not given" do
    error = KYAML::UnsupportedDocError.new(
      KYAML::MutationOperation::Set,
      ["name"],
      KYAML::UnsupportedDocReason::AmbiguousCommentOwner
    )

    error.source_line.should be_nil
    error.source_column.should be_nil
  end

  it "keeps its own copy of the path when the caller clears the original" do
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

  it "can be caught as a MutationError" do
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
