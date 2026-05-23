# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    module Mandelbrot
      MAX_ITER = 50
      ESCAPE_SQ = 4.0

      # run 幅 width 高さ width の正方領域に対しマンデルブロ反復を実行し、全ピクセル合計の反復回数を返します。
      def self.run(width)
        height = width
        total_iterations = 0
        y = 0
        while y < height
          ci = (2.0 * y / height) - 1.0
          x = 0
          while x < width
            cr = (2.0 * x / width) - 1.5
            total_iterations += iterations_at(cr, ci)
            x += 1
          end
          y += 1
        end
        total_iterations
      end

      # iterations_at 与えられた複素座標で発散判定までの反復回数を返します。
      def self.iterations_at(cr, ci)
        zr = 0.0
        zi = 0.0
        iter = 0
        while iter < MAX_ITER
          new_zr = (zr * zr) - (zi * zi) + cr
          zi = (2.0 * zr * zi) + ci
          zr = new_zr
          break if (zr * zr) + (zi * zi) > ESCAPE_SQ

          iter += 1
        end
        iter
      end
    end
  end
end
