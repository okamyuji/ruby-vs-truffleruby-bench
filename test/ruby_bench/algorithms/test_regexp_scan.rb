# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsRegexpScanTest < Minitest::Test
  def test_build_line_matches_pattern
    line = RubyBench::Algorithms::RegexpScan.build_line(0)

    assert_match(RubyBench::Algorithms::RegexpScan::LINE_PATTERN, line)
  end

  def test_run_counts_server_errors
    # index % 5 == 4 のときステータス 500 になる。0..9 では index=4,9 の 2 件。
    assert_equal(2, RubyBench::Algorithms::RegexpScan.run(10))
  end

  def test_run_with_zero_returns_zero
    assert_equal(0, RubyBench::Algorithms::RegexpScan.run(0))
  end
end
