# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchRunnerTest < Minitest::Test
  def test_smoke_runs_all_algorithms_once_with_small_inputs
    runner = RubyBench::Runner.new(smoke: true)
    runner.run_all
    algos = runner.harness.measurements.map(&:algorithm).sort

    assert_equal(%w[fibonacci json mandelbrot nbody regexp sieve], algos)
  end

  def test_smoke_inputs_finish_under_configured_timeout
    runner = RubyBench::Runner.new(smoke: true)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    runner.run_all
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    max_seconds = ENV.fetch("RUBY_BENCH_SMOKE_MAX_SECONDS", "120").to_f

    assert_operator(elapsed, :<, max_seconds, "スモーク実行は #{max_seconds} 秒未満で完了すること")
  end
end
