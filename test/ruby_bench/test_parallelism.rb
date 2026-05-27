# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchParallelismTest < Minitest::Test
  def test_measure_returns_sample_per_thread_count
    result = RubyBench::Parallelism.measure(total: 20_000, thread_counts: [1, 2], warmup: 1, repeats: 1)

    assert_equal([1, 2], result[:samples].map { |s| s[:threads] })
  end

  def test_baseline_speedup_is_one
    result = RubyBench::Parallelism.measure(total: 20_000, thread_counts: [1, 2], warmup: 1, repeats: 1)
    first = result[:samples].first

    assert_in_delta(1.0, first[:speedup])
  end

  def test_samples_have_positive_wall_time
    result = RubyBench::Parallelism.measure(total: 20_000, thread_counts: [1, 2], warmup: 1, repeats: 1)

    result[:samples].each { |s| assert_operator(s[:wall_s], :>, 0.0) }
  end

  def test_best_wall_returns_positive
    assert_operator(RubyBench::Parallelism.best_wall(10_000, 1, 1), :>, 0.0)
  end
end
