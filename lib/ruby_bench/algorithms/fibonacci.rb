# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    module Fibonacci
      # run 再帰でフィボナッチ数列の n 番目の値を計算します。意図的にメモ化していません。
      def self.run(n)
        return n if n < 2

        run(n - 1) + run(n - 2)
      end
    end
  end
end
