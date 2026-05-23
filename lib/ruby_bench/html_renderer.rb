# typed: true
# frozen_string_literal: true

require "json"
require "cgi"
require "fileutils"

module RubyBench
  class HtmlRenderer
    extend T::Sig

    class IOFailure < StandardError
    end

    CHARTJS_CDN = "https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.min.js"
    # CHARTJS_SRI は chart.js@4.5.1/dist/chart.umd.min.js の SHA-384 ハッシュ。
    # 検証手順: curl -sL <CHARTJS_CDN> | openssl dgst -sha384 -binary | openssl base64 -A
    CHARTJS_SRI = "sha384-jb8JQMbMoBUzgWatfe6COACi2ljcDdZQ2OxczGA3bGNeWe+6DChMTBJemed7ZnvJ"

    sig { params(payloads: T::Array[T::Hash[Symbol, T.untyped]]).void }
    def initialize(payloads)
      @payloads = payloads
    end

    sig { returns(String) }
    def render
      # </script> 文字列分割で script 終端注入を防ぎ、生 JSON は別の application/json タグに格納する
      data_json = JSON.generate(@payloads).gsub("</", "<\\/")
      pretty = CGI.escapeHTML(JSON.pretty_generate(@payloads))
      <<~HTML
        <!doctype html>
        <html lang="ja">
        <head>
          <meta charset="utf-8" />
          <title>Ruby 3.4 vs TruffleRuby 3.4 ベンチマークレポート</title>
          <script src="#{CHARTJS_CDN}" integrity="#{CHARTJS_SRI}" crossorigin="anonymous"></script>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; margin: 24px; color: #1f2937; }
            h1 { font-size: 22px; }
            h2 { font-size: 18px; margin-top: 32px; }
            section { margin-bottom: 48px; }
            .chart-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
            canvas { width: 100% !important; height: 320px !important; }
            details { margin-top: 24px; }
            pre { background: #f9fafb; padding: 12px; overflow: auto; font-size: 12px; }
          </style>
        </head>
        <body>
          <h1>Ruby 3.4 vs TruffleRuby 3.4 ベンチマークレポート</h1>
          <h2>主要指標</h2>
          <div class="chart-grid">
            <canvas id="ips"></canvas>
            <canvas id="wall"></canvas>
            <canvas id="rss"></canvas>
            <canvas id="gc"></canvas>
            <canvas id="cpu"></canvas>
            <canvas id="alloc"></canvas>
          </div>
          <details>
            <summary>収集データ(クリックで展開)</summary>
            <pre id="raw-data">#{pretty}</pre>
          </details>
          <script id="payloads-json" type="application/json">#{data_json}</script>
          <script>
            const payloads = JSON.parse(document.getElementById("payloads-json").textContent);
            const algorithms = Array.from(new Set(payloads.flatMap(p => p.measurements.map(m => m.algorithm))));
            const palette = { mri: "#ef4444", truffleruby: "#3b82f6" };
            const datasetsFor = (metric) => payloads.map(p => ({
              label: p.runtime_metadata.id,
              data: algorithms.map(a => {
                const m = p.measurements.find(x => x.algorithm === a);
                return m ? m[metric] : 0;
              }),
              backgroundColor: palette[p.runtime_metadata.id] || "#6b7280",
            }));
            const makeChart = (id, metric, title) => new Chart(document.getElementById(id), {
              type: "bar",
              data: { labels: algorithms, datasets: datasetsFor(metric) },
              options: { responsive: true, plugins: { title: { display: true, text: title } } },
            });
            makeChart("ips", "iterations_per_second", "Iterations per second (高いほど速い)");
            makeChart("wall", "wall_time_s", "Wall time seconds (低いほど速い)");
            makeChart("rss", "rss_bytes_peak", "Peak RSS bytes");
            makeChart("gc", "gc_time_ms_delta", "GC time ms delta");
            makeChart("cpu", "cpu_user_s", "CPU user seconds");
            makeChart("alloc", "allocations_total", "Total allocations");
          </script>
        </body>
        </html>
      HTML
    end

    sig { params(path: String).void }
    def write(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, render)
    rescue SystemCallError => e
      raise IOFailure, "HTML レポートの書き込みに失敗しました path=#{path} cause=#{e.class}: #{e.message}"
    end
  end
end
