# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsSieveTest < Minitest::Test
  def test_returns_zero_when_limit_below_two
    assert_equal(0, RubyBench::Algorithms::Sieve.run(1))
  end

  def test_returns_count_of_primes_up_to_ten
    assert_equal(4, RubyBench::Algorithms::Sieve.run(10))
  end

  def test_returns_count_of_primes_up_to_thirty
    assert_equal(10, RubyBench::Algorithms::Sieve.run(30))
  end

  def test_returns_count_of_primes_up_to_one_million
    assert_equal(78_498, RubyBench::Algorithms::Sieve.run(1_000_000))
  end
end
