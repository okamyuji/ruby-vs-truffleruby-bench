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

  def test_render_uses_single_column_vertical_layout
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(/flex-direction:\s*column/, html, "charts セクションは縦並びレイアウト")
  end

  def test_render_increases_chartjs_default_font_size
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(/Chart\.defaults\.font\.size\s*=\s*1[4-9]/, html, "Chart.js のデフォルトフォントサイズを 14+ に引き上げる")
  end

  def test_render_includes_wall_time_annotation
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(/benchmark-ips の計測ウィンドウ/, html, "wall_time_s の注釈で benchmark-ips の挙動を説明")
  end

  def test_render_includes_alloc_uninstrumented_note
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(/TruffleRuby は ObjectSpace 計装非対応/, html, "alloc セクションで TruffleRuby 計装非対応を明示")
  end

  def test_render_nulls_out_allocations_total_for_truffleruby
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render
    json_match = html.match(%r{<script id="payloads-json"[^>]*>(.*?)</script>}m)

    refute_nil(json_match, "payloads-json タグが存在する")
    payload = JSON.parse(json_match[1])

    assert_equal(200, payload["values"]["allocations_total"]["mri"]["fibonacci"], "MRI の allocations_total は数値を保持")
    assert_nil(payload["values"]["allocations_total"]["truffleruby"]["fibonacci"], "TruffleRuby の allocations_total は null")
  end

  def test_render_includes_summary_table_structure
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(/<table class="summary">/, html, "数値テーブルを含む")
    assert_match(/fibonacci/, html, "アルゴリズム行を含む")
  end

  def test_render_summary_table_columns_and_na_marker
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(%r{<th>ips</th>}, html, "ips 列を含む")
    assert_match(%r{<th>RSS\(MB\)</th>}, html, "RSS(MB) 列を含む")
    assert_match(%r{<td class="na">N/A</td>}, html, "TruffleRuby の alloc セルは N/A")
  end

  def test_render_chart_canvases_have_explicit_height
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render

    assert_match(/\.chart-wrap\s*\{[^}]*height:\s*46[0-9]px/, html, "chart-wrap で高さを 460px+ 明示")
    assert_match(/maintainAspectRatio:\s*false/, html, "縦圧縮を防ぐため maintainAspectRatio: false")
  end
end
