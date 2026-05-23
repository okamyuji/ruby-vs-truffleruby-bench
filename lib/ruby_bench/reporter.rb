# typed: true
# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module RubyBench
  class Reporter
    extend T::Sig

    class IOFailure < StandardError
    end

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
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, JSON.pretty_generate(payload))
    rescue SystemCallError => e
      raise IOFailure, "結果 JSON の書き込みに失敗しました path=#{path} cause=#{e.class}: #{e.message}"
    end

    sig { params(path: String).returns(T::Hash[Symbol, T.untyped]) }
    def self.load(path)
      JSON.parse(File.binread(path), symbolize_names: true)
    rescue SystemCallError => e
      raise IOFailure, "結果 JSON の読み込みに失敗しました path=#{path} cause=#{e.class}: #{e.message}"
    rescue JSON::ParserError => e
      raise IOFailure, "結果 JSON のパースに失敗しました path=#{path} cause=#{e.class}: #{e.message}"
    end
  end
end
