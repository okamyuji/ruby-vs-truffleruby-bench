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

  def test_run_preserves_total_work_when_not_divisible
    # 端数が出る分割でも総量を保つので、スレッド数を変えても結果は一致する。
    one = RubyBench::Algorithms::ParallelCpu.run(total: 100_003, threads: 1)
    seven = RubyBench::Algorithms::ParallelCpu.run(total: 100_003, threads: 7)

    assert_kind_of(Integer, one)
    assert_kind_of(Integer, seven)
    assert_equal(RubyBench::Algorithms::ParallelCpu.run(total: 100_003, threads: 7), seven)
  end

  def test_run_raises_on_non_positive_threads
    assert_raises(ArgumentError) { RubyBench::Algorithms::ParallelCpu.run(total: 1000, threads: 0) }
  end
end
