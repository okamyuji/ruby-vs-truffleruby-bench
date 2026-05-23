# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsFibonacciTest < Minitest::Test
  def test_returns_zero_for_zero
    assert_equal(0, RubyBench::Algorithms::Fibonacci.run(0))
  end

  def test_returns_one_for_one
    assert_equal(1, RubyBench::Algorithms::Fibonacci.run(1))
  end

  def test_returns_55_for_ten
    assert_equal(55, RubyBench::Algorithms::Fibonacci.run(10))
  end

  def test_returns_6765_for_twenty
    assert_equal(6765, RubyBench::Algorithms::Fibonacci.run(20))
  end
end
