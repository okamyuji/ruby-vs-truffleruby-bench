# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
T::Configuration.default_checked_level = :never

require_relative "ruby_bench/version"
require_relative "ruby_bench/runtime"
require_relative "ruby_bench/measurement"
require_relative "ruby_bench/harness"
require_relative "ruby_bench/warmup"
require_relative "ruby_bench/startup"
require_relative "ruby_bench/reporter"
require_relative "ruby_bench/html_renderer"
require_relative "ruby_bench/algorithms/fibonacci"
require_relative "ruby_bench/algorithms/mandelbrot"
require_relative "ruby_bench/algorithms/nbody"
require_relative "ruby_bench/algorithms/sieve"
require_relative "ruby_bench/algorithms/json_roundtrip"
require_relative "ruby_bench/algorithms/regexp_scan"
require_relative "ruby_bench/algorithms/parallel_cpu"
require_relative "ruby_bench/parallelism"
require_relative "ruby_bench/runner"

module RubyBench
end
