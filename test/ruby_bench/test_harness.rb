# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchHarnessTest < Minitest::Test
  def test_measure_returns_measurement
    harness = RubyBench::Harness.new(warmup_seconds: 0.01, time_seconds: 0.05)
    m = harness.measure(algorithm: "noop", input_label: "n=1") { 1 + 1 }

    assert_kind_of(RubyBench::Measurement, m)
    assert_equal("noop", m.algorithm)
    assert_equal("n=1", m.input_label)
  end

  def test_measure_records_positive_ips
    harness = RubyBench::Harness.new(warmup_seconds: 0.01, time_seconds: 0.05)
    m = harness.measure(algorithm: "noop", input_label: "n=1") { 1 + 1 }

    assert_operator(m.iterations_per_second, :>, 0.0)
  end

  def test_measure_captures_runtime_from_runtime_module
    harness = RubyBench::Harness.new(warmup_seconds: 0.01, time_seconds: 0.05)
    m = harness.measure(algorithm: "noop", input_label: "n=1") { 1 + 1 }

    assert_equal(RubyBench::Runtime.id, m.runtime)
  end

  def test_measurements_accumulates
    harness = RubyBench::Harness.new(warmup_seconds: 0.01, time_seconds: 0.05)
    harness.measure(algorithm: "a", input_label: "x") { 1 }
    harness.measure(algorithm: "b", input_label: "y") { 1 }

    assert_equal(2, harness.measurements.size)
  end
end
