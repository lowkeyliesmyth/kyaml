require "benchmark"
require "../src/kyaml"
require "./workloads"

{% unless flag?(:release) %}
  abort "Build this benchmark with --release"
{% end %}

small_input = KYAMLBench::Workloads::SMALL
deployment_input = KYAMLBench::Workloads::DEPLOYMENT
stream_input = KYAMLBench::Workloads.deployment_stream

doc = KYAML.parse_doc(deployment_input)
root = doc.root
comments = doc.comments

small_doc = KYAML.parse_doc(small_input)
deployment_doc = doc
stream_docs = [] of KYAML::Doc
emitted_output = ""
read_root = root
read_comments = comments
duplicated_root = root
cloned_root = root
duplicated_comments = comments

warmup = 1.second
calculation = 3.seconds

puts <<-INTRO
  ===DETAILS===
  crystal_version=#{Crystal::VERSION}
  build_flags=--release
  warmup_seconds_per_operation=#{warmup.total_seconds}
  calculation_seconds_per_operation=#{calculation.total_seconds}
  small_input_bytes=#{small_input.bytesize}
  deployment_input_bytes=#{deployment_input.bytesize}
  stream_input_bytes=#{stream_input.bytesize}
  stream_doc_count=#{KYAMLBench::Workloads::STREAM_DOC_COUNT}
  deployment_comment_count=#{comments.size}


  ===RESULTS===
  INTRO

Benchmark.ips(
  warmup: warmup,
  calculation: calculation,
  interactive: false
) do |bench|
  bench.report("parse_doc small") do
    small_doc = KYAML.parse_doc(small_input)
  end

  bench.report("parse_doc deployment") do
    deployment_doc = KYAML.parse_doc(deployment_input)
  end

  bench.report("parse_all_docs #{KYAMLBench::Workloads::STREAM_DOC_COUNT} deployments") do
    stream_docs = KYAML.parse_all_docs(stream_input)
  end

  bench.report("emit_doc deployment") do
    emitted_output = KYAML.emit_doc(doc)
  end

  bench.report("root live read") do
    read_root = doc.root
  end

  bench.report("comments live read") do
    read_comments = doc.comments
  end

  bench.report("Any#dup shallow root copy") do
    duplicated_root = root.dup
  end

  bench.report("Any#clone deep value copy") do
    cloned_root = root.clone
  end

  bench.report("comments Array#dup") do
    duplicated_comments = comments.dup
  end
end

raise "Small parse result mismatch" unless small_doc.root == KYAML.parse(small_input)
raise "Deployment parse result mismatch" unless deployment_doc.root == root

unless stream_docs.size == KYAMLBench::Workloads::STREAM_DOC_COUNT
  raise "Stream document count mismatch"
end

unless stream_docs.all? { |item| item.root == root && item.comments.map(&.text) == comments.map(&.text) }
  raise "Stream values or comments mismatch"
end

reparsed = KYAML.parse_doc(emitted_output)
raise "Emission value mismatch" unless reparsed.root == root
raise "Emission comment mismatch" unless reparsed.comments.map(&.text) == comments.map(&.text)

raise "Root read mismatch" unless read_root == root
raise "Comment read mismatch" unless read_comments == comments
raise "Shallow copy value mismatch" unless duplicated_root == root
raise "Shallow copy shares root mapping" if duplicated_root.as_h.same?(root.as_h)
raise "Deep copy value mismatch" unless cloned_root == root
raise "Deep copy shares nested mapping" if cloned_root["metadata"].as_h.same?(root["metadata"].as_h)
raise "Comment copy value mismatch" unless duplicated_comments == comments
raise "Comment copy shares array" if duplicated_comments.same?(comments)

puts "result_checks=passed"
