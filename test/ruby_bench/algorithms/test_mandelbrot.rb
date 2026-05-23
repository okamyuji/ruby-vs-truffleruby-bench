# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsMandelbrotTest < Minitest::Test
  def test_run_returns_positive_integer_total_iterations
    total = RubyBench::Algorithms::Mandelbrot.run(4)

    assert_operator(total, :>, 0, "全ピクセル合計の反復回数は正の整数になるはず")
    assert_kind_of(Integer, total)
  end

  def test_inside_set_value
    inside = RubyBench::Algorithms::Mandelbrot.iterations_at(-0.5, 0.0)

    assert_equal(RubyBench::Algorithms::Mandelbrot::MAX_ITER, inside)
  end

  def test_outside_set_value
    outside = RubyBench::Algorithms::Mandelbrot.iterations_at(2.0, 2.0)

    assert_operator(outside, :<, RubyBench::Algorithms::Mandelbrot::MAX_ITER)
  end
end
