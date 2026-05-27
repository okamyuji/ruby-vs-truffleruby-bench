# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchStartupTest < Minitest::Test
  def test_median_of_odd_length
    assert_in_delta(2.0, RubyBench::Startup.median([1.0, 2.0, 3.0]))
  end

  def test_median_of_even_length
    assert_in_delta(2.5, RubyBench::Startup.median([1.0, 2.0, 3.0, 4.0]))
  end

  def test_median_of_empty_is_zero
    assert_in_delta(0.0, RubyBench::Startup.median([]))
  end

  def test_run_samples_returns_positive_durations
    samples = RubyBench::Startup.run_samples("", 2)

    assert_equal(2, samples.size)
    samples.each { |s| assert_operator(s, :>, 0.0) }
  end

  def test_measure_covers_all_scenarios
    result = RubyBench::Startup.measure(runs: 2)

    assert_equal(RubyBench::Startup::SCENARIOS.size, result.size)
    result.each do |entry|
      assert_includes(entry.keys, :scenario)
      assert_operator(entry[:min_ms], :<=, entry[:max_ms])
    end
  end

  def test_measure_raises_on_non_positive_runs
    assert_raises(ArgumentError) { RubyBench::Startup.measure(runs: 0) }
  end
end
