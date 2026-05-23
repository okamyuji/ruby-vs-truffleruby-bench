# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsNbodyTest < Minitest::Test
  def test_returns_initial_and_final_energy_hash
    result = RubyBench::Algorithms::Nbody.run(10)

    assert_kind_of(Hash, result)
    assert_includes(result.keys, :initial_energy)
    assert_includes(result.keys, :final_energy)
  end

  def test_energy_is_finite_number
    result = RubyBench::Algorithms::Nbody.run(10)

    assert_predicate(result[:initial_energy], :finite?, "initial_energy が有限実数であること")
    assert_predicate(result[:final_energy], :finite?, "final_energy が有限実数であること")
  end

  def test_energy_changes_after_simulation
    result = RubyBench::Algorithms::Nbody.run(1000)

    refute_equal(result[:initial_energy], result[:final_energy])
  end
end
