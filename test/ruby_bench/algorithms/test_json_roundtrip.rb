# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsJsonRoundtripTest < Minitest::Test
  def test_run_returns_decoded_count
    assert_equal(100, RubyBench::Algorithms::JsonRoundtrip.run(100))
  end

  def test_run_with_zero_returns_zero
    assert_equal(0, RubyBench::Algorithms::JsonRoundtrip.run(0))
  end

  def test_build_record_is_roundtrip_safe
    record = RubyBench::Algorithms::JsonRoundtrip.build_record(3)
    decoded = JSON.parse(JSON.generate(record))

    assert_equal("user_3", decoded["name"])
    assert_equal("user_3@example.com", decoded.dig("profile", "email"))
  end
end
