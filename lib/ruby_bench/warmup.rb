# typed: true
# frozen_string_literal: true

module RubyBench
  # Warmup 同一ブロックを連続実行し、各回の所要時間 (ms) を時系列で記録する。
  # TruffleRuby のような JIT 実装は最初の数回が遅く、回を重ねるごとにピーク性能へ近づく。
  # この曲線を取ることで「短命プロセスでは温まり切らず不利」「常駐プロセスでは温まって有利」
  # というクラウド上での向き不向きを、平均値ひとつでは見えない形で可視化できる。
  class Warmup
    extend T::Sig

    # measure block を runs 回連続で実行し、各回の壁時計時間 (ミリ秒) の配列を返す。
    # 計測開始前に1度だけ GC を走らせ、初期状態のばらつきを抑える。
    sig { params(runs: Integer, block: T.proc.returns(T.untyped)).returns(T::Array[Float]) }
    def self.measure(runs:, &block)
      GC.start
      Array.new(runs) do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        block.call
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        elapsed * 1000.0
      end
    end
  end
end
