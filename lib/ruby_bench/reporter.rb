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

    sig do
      params(
        measurements: T::Array[Measurement],
        warmup: T.nilable(T::Hash[Symbol, T.untyped]),
        startup: T.nilable(T::Hash[Symbol, T.untyped]),
        parallelism: T.nilable(T::Hash[Symbol, T.untyped])
      ).void
    end
    def initialize(measurements, warmup: nil, startup: nil, parallelism: nil)
      @measurements = measurements
      @warmup = warmup
      @startup = startup
      @parallelism = parallelism
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def payload
      base = {
        schema_version: 2,
        generated_at: Time.now.utc.iso8601,
        runtime_metadata: Runtime.metadata,
        measurements: @measurements.map(&:to_h)
      }
      base[:warmup] = @warmup unless @warmup.nil?
      base[:startup] = @startup unless @startup.nil?
      base[:parallelism] = @parallelism unless @parallelism.nil?
      base
    end

    sig { params(path: String).void }
    def dump(path)
      begin
        FileUtils.mkdir_p(File.dirname(path))
      rescue SystemCallError => e
        raise IOFailure, "結果 JSON 用ディレクトリの作成に失敗しました path=#{path} cause=#{e.class}: #{e.message}"
      end

      begin
        File.binwrite(path, JSON.pretty_generate(payload))
      rescue SystemCallError => e
        raise IOFailure, "結果 JSON の書き込みに失敗しました path=#{path} cause=#{e.class}: #{e.message}"
      end
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
