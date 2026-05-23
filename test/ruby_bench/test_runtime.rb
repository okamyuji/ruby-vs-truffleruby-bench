# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchRuntimeTest < Minitest::Test
  def test_id_is_mri_or_truffleruby
    assert_includes(%w[mri truffleruby], RubyBench::Runtime.id)
  end

  def test_label_includes_engine_and_version
    label = RubyBench::Runtime.label
    assert_match(/(MRI|TruffleRuby)/, label)
    assert_match(/3\.4/, label)
  end

  def test_metadata_contains_required_keys
    meta = RubyBench::Runtime.metadata
    %i[id engine engine_version ruby_version platform pid].each do |k|
      assert(meta.key?(k), "metadata に #{k} が必要")
    end
  end
end
