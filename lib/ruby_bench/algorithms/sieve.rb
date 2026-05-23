# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    module Sieve
      # run limit 以下の素数の個数をエラトステネスのふるいで数えます。
      def self.run(limit)
        return 0 if limit < 2

        sieve = Array.new(limit + 1, true)
        sieve[0] = false
        sieve[1] = false

        i = 2
        while i * i <= limit
          if sieve[i]
            j = i * i
            while j <= limit
              sieve[j] = false
              j += i
            end
          end
          i += 1
        end

        count = 0
        k = 0
        n = sieve.length
        while k < n
          count += 1 if sieve[k]
          k += 1
        end
        count
      end
    end
  end
end
