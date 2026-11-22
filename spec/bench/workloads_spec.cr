require "../spec_helper"
require "../../bench/workloads"

describe KYAMLBench::Workloads do
  small_root = KYAML::Any.new({
    "name"     => KYAML::Any.new("demo"),
    "replicas" => KYAML::Any.new(2),
    "enabled"  => KYAML::Any.new(true),
  })

  deployment_root = KYAML.parse(<<-JSON)
    {
      "apiVersion": "apps/v1",
      "kind": "Deployment",
      "metadata": {
        "name": "benchmark-api",
        "namespace": "workloads",
        "labels": {"app": "benchmark-api"}
      },
      "spec": {
        "replicas": 3,
        "revisionHistoryLimit": 5,
        "selector": {
          "matchLabels": {"app": "benchmark-api"}
        },
        "template": {
          "metadata": {
            "labels": {"app": "benchmark-api"},
            "annotations": {
              "prometheus.io/scrape": "true",
              "prometheus.io/port": "8080"
            }
          },
          "spec": {
            "serviceAccountName": "benchmark-api",
            "terminationGracePeriodSeconds": 30,
            "containers": [{
              "name": "api",
              "image": "example.invalid/benchmark-api:1.0.0",
              "imagePullPolicy": "IfNotPresent",
              "ports": [{"name": "http", "containerPort": 8080}],
              "env": [
                {"name": "LOG_LEVEL", "value": "info"},
                {"name": "FEATURE_ENABLED", "value": "false"}
              ],
              "resources": {
                "requests": {"cpu": "100m", "memory": "128Mi"},
                "limits": {"cpu": "500m", "memory": "256Mi"}
              },
              "readinessProbe": {
                "httpGet": {"path": "/ready", "port": "http"},
                "initialDelaySeconds": 5,
                "periodSeconds": 10
              },
              "volumeMounts": [{
                "name": "config",
                "mountPath": "/etc/benchmark",
                "readOnly": true
              }]
            }],
            "volumes": [{
              "name": "config",
              "configMap": {"name": "benchmark-api"}
            }]
          }
        }
      }
    }
    JSON

  workloads = [
    {
      name:          "small mapping",
      input:         KYAMLBench::Workloads::SMALL,
      root:          small_root,
      comments_text: [" service identity", " desired count"],
    },
    {
      name:          "Deployment",
      input:         KYAMLBench::Workloads::DEPLOYMENT,
      root:          deployment_root,
      comments_text: [
        " benchmark deployment",
        " steady-state capacity",
        " application listener",
      ],
    },
  ]

  workloads.each do |wload|
    name = wload[:name]

    it "reads all expected values and comments from the #{name} workload" do
      doc = KYAML.parse_doc(wload[:input])

      doc.root.should eq(wload[:root])
      doc.comments.map(&.text).should eq(wload[:comments_text])
      KYAML.parse(wload[:input]).should eq(wload[:root])
    end

    it "writes the same output each time without changing the #{name} workload's values or comments" do
      doc = KYAML.parse_doc(wload[:input])
      original_comments = doc.comments.dup
      first_output = KYAML.emit_doc(doc)

      3.times do
        KYAML.emit_doc(doc).should eq(first_output)
        doc.root.should eq(wload[:root])
        doc.comments.should eq(original_comments)
      end

      reparsed = KYAML.parse_doc(first_output)
      reparsed.root.should eq(wload[:root])
      reparsed.comments.map(&.text).should eq(wload[:comments_text])
    end
  end

  it "passes each requested deployment document to the block when reading the stream" do
    stream = KYAMLBench::Workloads.deployment_stream(3)
    roots = [] of KYAML::Any

    KYAML.parse_all_docs(stream) { |doc| roots << doc.root }

    roots.should eq([deployment_root, deployment_root, deployment_root])
  end

  it "builds a single deployment document without adding an empty one" do
    stream = KYAMLBench::Workloads.deployment_stream(1)

    stream.should eq(KYAMLBench::Workloads::DEPLOYMENT)
    docs = KYAML.parse_all_docs(stream)
    docs.size.should eq(1)
    docs.first.root.should eq(deployment_root)
  end

  it "builds an empty stream with no documents when the requested count is zero" do
    stream = KYAMLBench::Workloads.deployment_stream(0)

    stream.should eq("")
    KYAML.parse_all_docs(stream).should be_empty

    yielded = 0
    KYAML.parse_all_docs(stream) { |_| yielded += 1 }
    yielded.should eq(0)
  end

  it "rejects a negative document count" do
    expect_raises(ArgumentError) do
      KYAMLBench::Workloads.deployment_stream(-1)
    end
  end

  it "rejects invalid YAML when reading one document or a stream of documents" do
    malformed = "{unclosed:"

    expect_raises(KYAML::ParseError) { KYAML.parse_doc(malformed) }
    expect_raises(KYAML::ParseError) { KYAML.parse_all_docs(malformed) }
    expect_raises(KYAML::ParseError) do
      KYAML.parse_all_docs(malformed) { |_| }
    end
  end
end
