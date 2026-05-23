# typed: false
# frozen_string_literal: true

require "test_helper"
require "tempfile"

class RubyBenchHtmlRendererTest < Minitest::Test
  def sample_payload(runtime)
    {
      schema_version: 1,
      generated_at: "2026-05-24T00:00:00Z",
      runtime_metadata: {
        id: runtime,
        engine: runtime,
        engine_version: "3.4",
        ruby_version: "3.4.1",
        platform: "x86_64-linux",
        pid: 1
      },
      measurements: [
        {
          algorithm: "fibonacci",
          input_label: "n=20",
          runtime: runtime,
          wall_time_s: 0.1,
          iterations_per_second: 50.0,
          iterations_per_second_error: 0.5,
          rss_bytes_peak: 1_000_000,
          cpu_user_s: 0.08,
          cpu_sys_s: 0.02,
          gc_count_delta: 2,
          gc_time_ms_delta: 10,
          allocations_total: 200,
          allocations_retained: 20
        }
      ]
    }
  end

  def test_render_returns_string_containing_chartjs_cdn
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(/cdn\.jsdelivr\.net.*chart\.js/m, html)
  end

  def test_render_includes_sri_integrity_attribute
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(%r{integrity="sha384-[A-Za-z0-9+/]+=*"}, html)
    assert_match(/crossorigin="anonymous"/, html)
  end

  def test_render_contains_both_runtime_labels
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_includes(html, "mri")
    assert_includes(html, "truffleruby")
  end

  def test_render_embeds_measurement_dataset_json
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_includes(html, "fibonacci")
    assert_match(/iterations_per_second/, html)
  end

  def test_write_outputs_html_file
    Tempfile.open(%w[report .html]) do |f|
      RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).write(f.path)

      assert_match(/<!doctype html>/i, File.read(f.path))
    end
  end
end
