# typed: false
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsParallelCpuTest < Minitest::Test
  def test_work_chunk_is_deterministic
    a = RubyBench::Algorithms::ParallelCpu.work_chunk(1, 1000)
    b = RubyBench::Algorithms::ParallelCpu.work_chunk(1, 1000)

    assert_equal(a, b)
  end

  def test_work_chunk_stays_within_32bit_mask
    value = RubyBench::Algorithms::ParallelCpu.work_chunk(1, 10_000)

    assert_operator(value, :>=, 0)
    assert_operator(value, :<=, RubyBench::Algorithms::ParallelCpu::MASK)
  end

  def test_run_is_deterministic
    a = RubyBench::Algorithms::ParallelCpu.run(total: 100_000, threads: 4)
    b = RubyBench::Algorithms::ParallelCpu.run(total: 100_000, threads: 4)

    assert_equal(a, b)
  end

  def test_run_single_thread_matches_work_chunk
    # 1 スレッドのとき seed=1 で per=total の work_chunk と一致する。
    total = 50_000
    expected = RubyBench::Algorithms::ParallelCpu.work_chunk(1, total) & RubyBench::Algorithms::ParallelCpu::MASK

    assert_equal(expected, RubyBench::Algorithms::ParallelCpu.run(total: total, threads: 1))
  end
end
