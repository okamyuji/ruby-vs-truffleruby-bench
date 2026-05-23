# typed: true
# frozen_string_literal: true

require "benchmark/ips"
require "memory_profiler"
require "get_process_mem"

module RubyBench
  class Harness
    extend T::Sig

    DEFAULT_WARMUP = 1.0
    DEFAULT_TIME = 3.0

    sig { returns(T::Array[Measurement]) }
    attr_reader :measurements

    sig { params(warmup_seconds: Float, time_seconds: Float).void }
    def initialize(warmup_seconds: DEFAULT_WARMUP, time_seconds: DEFAULT_TIME)
      @warmup_seconds = warmup_seconds
      @time_seconds = time_seconds
      @measurements = []
    end

    # measure 与えられた純粋関数ブロックを4種の独立フェーズで計測します。前提として block は引数を取らず
    # 外部状態を変更しない冪等なブロックでなければなりません(各フェーズで複数回呼び出されるため)。
    sig { params(algorithm: String, input_label: String, block: T.proc.returns(T.untyped)).returns(Measurement) }
    def measure(algorithm:, input_label:, &block)
      ips_result = isolate { run_ips(&block) }
      memory_result = isolate { run_memory(&block) }
      rss_peak = isolate { run_rss(&block) }
      cpu_user, cpu_sys, gc_count_delta, gc_time_delta = isolate { run_cpu_and_gc(&block) }

      m =
        Measurement.new(
          algorithm: algorithm,
          input_label: input_label,
          runtime: Runtime.id,
          wall_time_s: ips_result.fetch(:wall_time).to_f,
          iterations_per_second: ips_result.fetch(:ips).to_f,
          iterations_per_second_error: ips_result.fetch(:ips_error).to_f,
          rss_bytes_peak: rss_peak.to_i,
          cpu_user_s: cpu_user.to_f,
          cpu_sys_s: cpu_sys.to_f,
          gc_count_delta: gc_count_delta.to_i,
          gc_time_ms_delta: gc_time_delta.to_i,
          allocations_total: memory_result.fetch(:total).to_i,
          allocations_retained: memory_result.fetch(:retained).to_i
        )
      @measurements << m
      m
    end

    private

    # isolate 各計測フェーズの直前に GC を1度走らせて初期状態を揃え、計測間の干渉を最小化します。
    sig { type_parameters(:R).params(block: T.proc.returns(T.type_parameter(:R))).returns(T.type_parameter(:R)) }
    def isolate(&block)
      GC.start
      block.call
    end

    sig { params(block: T.proc.returns(T.untyped)).returns(T::Hash[Symbol, T.untyped]) }
    def run_ips(&block)
      report =
        T
          .unsafe(::Benchmark)
          .ips do |x|
            x.config(time: @time_seconds, warmup: @warmup_seconds, quiet: true)
            x.report("target", &block)
          end
      entry = report.entries.first
      ips = entry.ips.to_f
      iterations = entry.iterations.to_f
      wall = ips.positive? ? (iterations / ips) : 0.0
      ips_error = entry.respond_to?(:ips_sd) ? entry.ips_sd.to_f : 0.0
      { wall_time: wall, ips: ips, ips_error: ips_error }
    end

    sig { params(block: T.proc.returns(T.untyped)).returns(T::Hash[Symbol, Integer]) }
    def run_memory(&block)
      report = T.unsafe(Object.const_get(:MemoryProfiler)).report(&block)
      { total: report.total_allocated.to_i, retained: report.total_retained.to_i }
    end

    sig { params(block: T.proc.returns(T.untyped)).returns(Integer) }
    def run_rss(&block)
      mem = T.unsafe(Object.const_get(:GetProcessMem)).new
      before = mem.bytes.to_i
      block.call
      after = mem.bytes.to_i
      [before, after].max
    end

    sig { params(block: T.proc.returns(T.untyped)).returns([Float, Float, Integer, Integer]) }
    def run_cpu_and_gc(&block)
      gc_before = GC.stat
      cpu_before = Process.times
      block.call
      cpu_after = Process.times
      gc_after = GC.stat
      [
        cpu_after.utime - cpu_before.utime,
        cpu_after.stime - cpu_before.stime,
        ((gc_after[:count] || 0) - (gc_before[:count] || 0)).to_i,
        ((gc_after[:total_time] || 0) - (gc_before[:total_time] || 0)).to_i
      ]
    end
  end
end
