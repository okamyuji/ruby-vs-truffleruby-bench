# typed: true
# frozen_string_literal: true

module RubyBench
  # Parallelism CPU バウンド処理の強スケーリング (総仕事量を固定したままスレッドを増やしたときの
  # wall 時間短縮) を計測する。GVL を持つ MRI は CPU バウンド処理を直列化するためスレッドを
  # 増やしても速くならず、YJIT 有効時はロック競合でむしろ遅くなる。GVL を持たない TruffleRuby は
  # コア数まで真の並列でスケールする。マルチコアを活かせるかどうかはクラウドのコスト効率に直結する。
  #
  # 指標として cpu/wall 比ではなく wall 時間の speedup を使うのは、TruffleRuby が JIT コンパイルを
  # バックグラウンドスレッドで行い cpu 時間が application スレッド数と一致しないためである。
  class Parallelism
    extend T::Sig

    # measure thread_counts の各スレッド数で総量 total を分割実行し、最良 wall 時間と
    # 1 スレポイント比の speedup を返す。warmup 回だけ事前実行して JIT を温めてから計測する。
    sig do
      params(total: Integer, thread_counts: T::Array[Integer], warmup: Integer, repeats: Integer).returns(
        T::Hash[Symbol, T.untyped]
      )
    end
    def self.measure(total:, thread_counts:, warmup: 3, repeats: 2)
      raise ArgumentError, "total は1以上である必要があります" if total < 1
      raise ArgumentError, "thread_counts は空にできません" if thread_counts.empty?
      raise ArgumentError, "thread_counts はすべて1以上である必要があります" unless thread_counts.all?(&:positive?)
      raise ArgumentError, "warmup は0以上である必要があります" if warmup.negative?
      raise ArgumentError, "repeats は1以上である必要があります" if repeats < 1

      max_threads = thread_counts.max || 1
      warmup.times { Algorithms::ParallelCpu.run(total: total, threads: max_threads) }

      baseline = T.let(nil, T.nilable(Float))
      samples =
        thread_counts.map do |threads|
          best = best_wall(total, threads, repeats)
          # 最初に計測した best を基準値にする (thread_counts の重複や順序に左右されない)。
          baseline ||= best
          { threads: threads, wall_s: best, speedup: speedup(baseline, best) }
        end
      { total: total, samples: samples }
    end

    # speedup 基準 wall 時間に対する best の速度比を返す。基準が未確定や非正のときは 0.0。
    sig { params(baseline: T.nilable(Float), best: Float).returns(Float) }
    def self.speedup(baseline, best)
      return 0.0 if baseline.nil? || !baseline.positive? || !best.positive?

      baseline / best
    end

    # best_wall total を threads 本で分割実行し、repeats 回のうち最良 (最小) の wall 時間 (秒) を返す。
    sig { params(total: Integer, threads: Integer, repeats: Integer).returns(Float) }
    def self.best_wall(total, threads, repeats)
      best = T.let(Float::INFINITY, Float)
      repeats.times do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Algorithms::ParallelCpu.run(total: total, threads: threads)
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to_f
        best = elapsed if elapsed < best
      end
      best
    end
  end
end
