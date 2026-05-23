# typed: true
# frozen_string_literal: true

require "json"
require "time"

module RubyBench
  class Reporter
    extend T::Sig

    sig { params(measurements: T::Array[Measurement]).void }
    def initialize(measurements)
      @measurements = measurements
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def payload
      {
        schema_version: 1,
        generated_at: Time.now.utc.iso8601,
        runtime_metadata: Runtime.metadata,
        measurements: @measurements.map(&:to_h)
      }
    end

    sig { params(path: String).void }
    def dump(path)
      File.binwrite(path, JSON.pretty_generate(payload))
    end

    sig { params(path: String).returns(T::Hash[Symbol, T.untyped]) }
    def self.load(path)
      JSON.parse(File.read(path), symbolize_names: true)
    end
  end
end
