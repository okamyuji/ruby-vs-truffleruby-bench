# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchRunnerTest < Minitest::Test
  def test_smoke_runs_all_algorithms_once_with_small_inputs
    runner = RubyBench::Runner.new(smoke: true)
    runner.run_all
    algos = runner.harness.measurements.map(&:algorithm).sort
    assert_equal(%w[fibonacci mandelbrot nbody sieve], algos)
  end

  def test_smoke_inputs_finish_under_a_minute
    runner = RubyBench::Runner.new(smoke: true)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    runner.run_all
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator(elapsed, :<, 60.0, "スモーク実行は十分短時間で終わること")
  end
end
