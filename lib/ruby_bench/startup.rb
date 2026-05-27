# typed: true
# frozen_string_literal: true

require "rbconfig"

module RubyBench
  # Startup プロセス起動から最初のコード実行までにかかる時間を、サブプロセスを繰り返し
  # 起動して計測する。サーバーレス (AWS Lambda 等) やオートスケールするコンテナの
  # コールドスタートに直結する指標で、ホットループのスループットだけを見ていては
  # 抜け落ちる「起動コスト」を埋める。同一インタプリタを RbConfig.ruby から spawn するため、
  # YJIT (RUBYOPT 経由) や TruffleRuby の起動コストもそのまま反映される。
  class Startup
    extend T::Sig

    # SCENARIOS 計測する起動シナリオ。いずれも標準ライブラリのみで両ランタイムで等価に動く。
    SCENARIOS = { bare: "", stdlib_require: %(require "json"; require "set"; require "benchmark"; require "digest") }.freeze

    class SubprocessFailure < StandardError
    end

    # measure 各シナリオを runs 回ずつ起動し、最小/中央/最大の起動時間 (ms) をまとめて返す。
    sig { params(runs: Integer).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
    def self.measure(runs:)
      raise ArgumentError, "runs は1以上である必要があります" if runs < 1

      SCENARIOS.map do |name, code|
        sorted = run_samples(code, runs).sort
        { scenario: name.to_s, runs: runs, min_ms: sorted.first, median_ms: median(sorted), max_ms: sorted.last }
      end
    end

    # run_samples code を runs 回サブプロセスとして起動し、各回の壁時計時間 (ms) を返す。
    sig { params(code: String, runs: Integer).returns(T::Array[Float]) }
    def self.run_samples(code, runs)
      ruby = RbConfig.ruby
      Array.new(runs) do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ok = system(ruby, "-e", code, out: File::NULL, err: File::NULL)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        raise SubprocessFailure, "起動計測のサブプロセスが失敗しました code=#{code.inspect}" unless ok

        elapsed * 1000.0
      end
    end

    # median ソート済み配列の中央値を返す。空配列は 0.0。
    sig { params(sorted: T::Array[Float]).returns(Float) }
    def self.median(sorted)
      n = sorted.size
      return 0.0 if n.zero?

      mid = n / 2
      n.odd? ? sorted.fetch(mid) : (sorted.fetch(mid - 1) + sorted.fetch(mid)) / 2.0
    end
  end
end
