# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsMandelbrotTest < Minitest::Test
  def test_returns_total_pixel_count
    assert_equal(16, RubyBench::Algorithms::Mandelbrot.run(4))
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
