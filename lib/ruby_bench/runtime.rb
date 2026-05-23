# typed: true
# frozen_string_literal: true

require "rbconfig"

module RubyBench
  module Runtime
    extend T::Sig

    sig { returns(String) }
    def self.id
      defined?(::TruffleRuby) ? "truffleruby" : "mri"
    end

    sig { returns(String) }
    def self.label
      case id
      when "truffleruby"
        "TruffleRuby #{engine_version} (Ruby #{RUBY_VERSION})"
      else
        "MRI Ruby #{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
      end
    end

    sig { returns(String) }
    def self.engine_version
      # RUBY_ENGINE_VERSION は MRI でも TruffleRuby でも提供される実装本体のバージョン (例 MRI: 3.4.1, TruffleRuby: 24.1.1)
      defined?(RUBY_ENGINE_VERSION) ? RUBY_ENGINE_VERSION : RUBY_VERSION
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def self.metadata
      {
        id: id,
        engine: defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby",
        engine_version: engine_version,
        ruby_version: RUBY_VERSION,
        platform: RUBY_PLATFORM,
        pid: Process.pid
      }
    end
  end
end
