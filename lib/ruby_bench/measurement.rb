# typed: true
# frozen_string_literal: true

require "json"

module RubyBench
  class Measurement
    extend T::Sig

    FIELDS = %i[
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
    ].freeze

    sig { returns(String) }
    attr_reader :algorithm

    sig { returns(String) }
    attr_reader :input_label

    sig { returns(String) }
    attr_reader :runtime

    sig { returns(Float) }
    attr_reader :wall_time_s

    sig { returns(Float) }
    attr_reader :iterations_per_second

    sig { returns(Float) }
    attr_reader :iterations_per_second_error

    sig { returns(Float) }
    attr_reader :cpu_user_s

    sig { returns(Float) }
    attr_reader :cpu_sys_s

    sig { returns(Integer) }
    attr_reader :rss_bytes_peak

    sig { returns(Integer) }
    attr_reader :gc_count_delta

    sig { returns(Integer) }
    attr_reader :gc_time_ms_delta

    sig { returns(Integer) }
    attr_reader :allocations_total

    sig { returns(Integer) }
    attr_reader :allocations_retained

    sig do
      params(
        algorithm: String,
        input_label: String,
        runtime: String,
        wall_time_s: Float,
        iterations_per_second: Float,
        iterations_per_second_error: Float,
        rss_bytes_peak: Integer,
        cpu_user_s: Float,
        cpu_sys_s: Float,
        gc_count_delta: Integer,
        gc_time_ms_delta: Integer,
        allocations_total: Integer,
        allocations_retained: Integer
      ).void
    end
    def initialize(
      algorithm:,
      input_label:,
      runtime:,
      wall_time_s:,
      iterations_per_second:,
      iterations_per_second_error:,
      rss_bytes_peak:,
      cpu_user_s:,
      cpu_sys_s:,
      gc_count_delta:,
      gc_time_ms_delta:,
      allocations_total:,
      allocations_retained:
    )
      @algorithm = algorithm
      @input_label = input_label
      @runtime = runtime
      @wall_time_s = wall_time_s
      @iterations_per_second = iterations_per_second
      @iterations_per_second_error = iterations_per_second_error
      @rss_bytes_peak = rss_bytes_peak
      @cpu_user_s = cpu_user_s
      @cpu_sys_s = cpu_sys_s
      @gc_count_delta = gc_count_delta
      @gc_time_ms_delta = gc_time_ms_delta
      @allocations_total = allocations_total
      @allocations_retained = allocations_retained
      freeze
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def to_h
      FIELDS.each_with_object({}) { |k, acc| acc[k] = public_send(k) }
    end

    sig { params(overrides: T.untyped).returns(Measurement) }
    def with(**overrides)
      T.unsafe(Measurement).new(**to_h.merge(overrides))
    end
  end
end
