# typed: false
# frozen_string_literal: true

require "test_helper"
require "json"

class RubyBenchMeasurementTest < Minitest::Test
  def sample
    RubyBench::Measurement.new(
      algorithm: "fibonacci",
      input_label: "n=30",
      runtime: "mri",
      wall_time_s: 1.5,
      iterations_per_second: 6.66,
      iterations_per_second_error: 0.1,
      rss_bytes_peak: 50_000_000,
      cpu_user_s: 1.4,
      cpu_sys_s: 0.05,
      gc_count_delta: 12,
      gc_time_ms_delta: 25,
      allocations_total: 3000,
      allocations_retained: 100
    )
  end

  def test_to_h_returns_all_fields_as_symbols
    h = sample.to_h

    %i[
      algorithm
      input_label
      runtime
      wall_time_s
      iterations_per_second
      iterations_per_second_error
      rss_bytes_peak
      cpu_user_s
      cpu_sys_s
      gc_count_delta
      gc_time_ms_delta
      allocations_total
      allocations_retained
    ].each { |k| assert(h.key?(k), "#{k} が to_h に含まれる") }
  end

  def test_immutable_returns_new_copy_via_with
    other = sample.with(runtime: "truffleruby")

    assert_equal("mri", sample.runtime)
    assert_equal("truffleruby", other.runtime)
  end

  def test_to_json_round_trip
    json = sample.to_h.to_json
    parsed = JSON.parse(json, symbolize_names: true)

    assert_equal("fibonacci", parsed[:algorithm])
    assert_in_delta(6.66, parsed[:iterations_per_second])
  end
end
