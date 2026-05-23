# typed: false
# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "json"

class RubyBenchReporterTest < Minitest::Test
  def measurements
    [
      RubyBench::Measurement.new(
        algorithm: "fibonacci",
        input_label: "n=20",
        runtime: "mri",
        wall_time_s: 0.1,
        iterations_per_second: 10.0,
        iterations_per_second_error: 0.1,
        rss_bytes_peak: 1000,
        cpu_user_s: 0.09,
        cpu_sys_s: 0.01,
        gc_count_delta: 1,
        gc_time_ms_delta: 2,
        allocations_total: 10,
        allocations_retained: 1
      )
    ]
  end

  def test_to_json_payload_contains_runtime_metadata
    payload = RubyBench::Reporter.new(measurements).payload

    assert_includes(payload.keys, :runtime_metadata)
    assert_includes(payload.keys, :measurements)
  end

  def test_dump_writes_to_file
    Tempfile.open(%w[report .json]) do |f|
      RubyBench::Reporter.new(measurements).dump(f.path)
      parsed = JSON.parse(File.read(f.path), symbolize_names: true)

      assert_equal("fibonacci", parsed[:measurements].first[:algorithm])
    end
  end

  def test_load_reads_back_payload
    Tempfile.open(%w[report .json]) do |f|
      RubyBench::Reporter.new(measurements).dump(f.path)
      loaded = RubyBench::Reporter.load(f.path)

      assert_equal(1, loaded[:measurements].size)
      assert_includes(loaded.keys, :runtime_metadata)
    end
  end
end
