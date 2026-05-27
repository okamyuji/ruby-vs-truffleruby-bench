# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    # ParallelCpu CPU バウンドな整数演算を複数スレッドへ分担させる処理。
    # 1反復あたりのコストが値の大きさに依存しない 32bit 線形合同法 (LCG) を使うため、
    # 総仕事量をスレッドへ分割しても各反復のコストは一定で、スレッド数による計測の交絡が起きない。
    # MRI は GVL により CPU バウンド処理を直列化するため複数スレッドでも速くならない
    # (YJIT 有効時はロック競合でむしろ遅くなる) 一方、GVL を持たない TruffleRuby は真の並列で
    # スケールする。強スケーリング (総量固定でスレッドを増やしたときの wall 時間短縮) で差が見える。
    module ParallelCpu
      MASK = 0xffffffff
      LCG_A = 1_664_525
      LCG_C = 1_013_904_223

      # work_chunk seed から count 回 LCG を回した最終状態を返す。1反復のコストは値に依存しない。
      def self.work_chunk(seed, count)
        acc = seed & MASK
        i = 0
        while i < count
          acc = ((LCG_A * acc) + LCG_C) & MASK
          i += 1
        end
        acc
      end

      # run 総仕事量 total を threads 本のスレッドへ均等分割して並列実行し、各スレッドの最終状態の和を返す。
      def self.run(total:, threads:)
        per = total / threads
        results = Array.new(threads, 0)
        workers = (0...threads).map { |idx| Thread.new(idx) { |t| results[t] = work_chunk(t + 1, per) } }
        workers.each(&:join)
        results.sum & MASK
      end
    end
  end
end
