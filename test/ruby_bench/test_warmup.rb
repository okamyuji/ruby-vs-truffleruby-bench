# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchWarmupTest < Minitest::Test
  def test_measure_returns_one_sample_per_run
    samples = RubyBench::Warmup.measure(runs: 5) { 1 + 1 }

    assert_equal(5, samples.size)
  end

  def test_samples_are_non_negative_floats
    samples = RubyBench::Warmup.measure(runs: 3) { 1 + 1 }

    samples.each do |s|
      assert_kind_of(Float, s)
      assert_operator(s, :>=, 0.0)
    end
  end

  def test_block_is_called_once_per_run
    calls = 0
    RubyBench::Warmup.measure(runs: 4) { calls += 1 }

    assert_equal(4, calls)
  end
end
