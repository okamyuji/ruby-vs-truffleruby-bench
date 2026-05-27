# typed: true
# frozen_string_literal: true

module RubyBench
  class HtmlRenderer
    # HTML レポートに埋め込む静的アセット (CSS / JS テンプレート)。
    # HtmlRenderer 本体の Metrics/ClassLength を避けるためモジュール定数に外出ししている。
    module Assets
      STYLESHEET = <<~CSS
        :root { color-scheme: light; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", "Hiragino Sans", sans-serif;
          margin: 0;
          padding: 32px 48px;
          color: #111827;
          background: #f9fafb;
          line-height: 1.55;
        }
        header { max-width: 1080px; margin: 0 auto 24px; }
        main { max-width: 1080px; margin: 0 auto; }
        h1 { font-size: 28px; margin: 0 0 8px; }
        h2 { font-size: 22px; margin: 40px 0 16px; border-bottom: 2px solid #d1d5db; padding-bottom: 4px; }
        h3 { font-size: 17px; margin: 0 0 6px; }
        .meta { color: #4b5563; font-size: 14px; }
        section.charts { display: flex; flex-direction: column; gap: 24px; }
        .chart-card {
          background: #ffffff;
          border: 1px solid #e5e7eb;
          border-radius: 10px;
          padding: 20px 24px 24px;
          box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
        }
        .chart-card p.subtitle { color: #6b7280; font-size: 13px; margin: 0 0 12px; }
        .chart-card .chart-wrap { position: relative; height: 460px; }
        .chart-card canvas { width: 100% !important; height: 100% !important; }
        table.summary {
          border-collapse: collapse;
          width: 100%;
          font-size: 14px;
          background: #fff;
          border-radius: 8px;
          overflow: hidden;
          box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
        }
        table.summary th, table.summary td {
          border-bottom: 1px solid #e5e7eb;
          padding: 8px 12px;
          text-align: right;
          white-space: nowrap;
        }
        table.summary th { background: #f3f4f6; font-weight: 600; }
        table.summary th:first-child, table.summary td:first-child,
        table.summary th:nth-child(2), table.summary td:nth-child(2) { text-align: left; }
        table.summary td.runtime-mri { color: #b91c1c; }
        table.summary td.runtime-mri-yjit { color: #b45309; }
        table.summary td.runtime-truffleruby { color: #1d4ed8; }
        table.summary td.na { color: #9ca3af; font-style: italic; }
        details { margin-top: 32px; }
        details summary { cursor: pointer; font-weight: 600; padding: 8px 0; }
        pre { background: #111827; color: #f9fafb; padding: 16px; overflow: auto; font-size: 12px; border-radius: 8px; }
      CSS

      # CHART_SCRIPT_TEMPLATE は %CHARTS_CONFIG% を実行時に sub で差し替えて使う。
      # 本テンプレ内に Ruby の #{...} 補間は含めない (含めるとここでは意図しない展開になる)。
      CHART_SCRIPT_TEMPLATE = <<~JS
        (function () {
          const data = JSON.parse(document.getElementById("payloads-json").textContent);
          if (typeof Chart === "undefined") return;
          Chart.defaults.font.family = '-apple-system, BlinkMacSystemFont, "Helvetica Neue", "Hiragino Sans", sans-serif';
          Chart.defaults.font.size = 14;
          Chart.defaults.color = "#111827";
          const palette = { mri: "#ef4444", "mri-yjit": "#f59e0b", truffleruby: "#3b82f6" };
          const charts = %CHARTS_CONFIG%;
          charts.forEach(function (c) {
            const ds = data.runtimes.map(function (rt) {
              return {
                label: rt,
                data: data.algorithms.map(function (a) { return data.values[c.metric][rt][a]; }),
                backgroundColor: palette[rt] || "#6b7280",
                borderRadius: 4,
                maxBarThickness: 64
              };
            });
            new Chart(document.getElementById(c.id), {
              type: "bar",
              data: { labels: data.algorithms, datasets: ds },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                  title: { display: true, text: c.title, font: { size: 16, weight: "600" }, padding: { top: 4, bottom: 12 } },
                  legend: { position: "top", labels: { font: { size: 14 }, padding: 16 } },
                  tooltip: { titleFont: { size: 14 }, bodyFont: { size: 14 } }
                },
                scales: {
                  x: { ticks: { font: { size: 13 } } },
                  y: { ticks: { font: { size: 13 } }, beginAtZero: true }
                }
              }
            });
          });
        })();
      JS

      # EXTRAS_SCRIPT は起動時間 (棒)・ウォームアップ曲線 (折れ線)・並列スケーリング (棒) を描画する。
      # extras-json タグが無い、または Chart 未ロードのときは何もしない。
      EXTRAS_SCRIPT = <<~JS
        (function () {
          if (typeof Chart === "undefined") return;
          const el = document.getElementById("extras-json");
          if (!el) return;
          const extras = JSON.parse(el.textContent);
          const palette = { mri: "#ef4444", "mri-yjit": "#f59e0b", truffleruby: "#3b82f6" };
          const colorOf = function (rt) { return palette[rt] || "#6b7280"; };

          if (extras.startup) {
            const s = extras.startup;
            const ds = s.runtimes.map(function (rt) {
              return {
                label: rt,
                data: s.scenarios.map(function (sc) { return s.values[sc][rt]; }),
                backgroundColor: colorOf(rt),
                borderRadius: 4,
                maxBarThickness: 64
              };
            });
            new Chart(document.getElementById("startup-chart"), {
              type: "bar",
              data: { labels: s.scenarios, datasets: ds },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { position: "top", labels: { font: { size: 14 }, padding: 16 } } },
                scales: {
                  x: { ticks: { font: { size: 13 } } },
                  y: { beginAtZero: true, ticks: { font: { size: 13 } }, title: { display: true, text: "median ms" } }
                }
              }
            });
          }

          if (extras.warmup) {
            const w = extras.warmup;
            const ds = w.runtimes.map(function (rt) {
              return {
                label: rt,
                data: w.series[rt],
                borderColor: colorOf(rt),
                backgroundColor: colorOf(rt),
                fill: false,
                tension: 0.2,
                pointRadius: 2,
                borderWidth: 2
              };
            });
            new Chart(document.getElementById("warmup-chart"), {
              type: "line",
              data: { labels: w.labels, datasets: ds },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { position: "top", labels: { font: { size: 14 }, padding: 16 } } },
                scales: {
                  x: { ticks: { font: { size: 13 } }, title: { display: true, text: "実行回数 (回目)" } },
                  y: { beginAtZero: true, ticks: { font: { size: 13 } }, title: { display: true, text: "wall ms / 回" } }
                }
              }
            });
          }

          if (extras.parallelism) {
            const p = extras.parallelism;
            const labels = p.thread_counts.map(function (t) { return t + " thread"; });
            const ds = p.runtimes.map(function (rt) {
              return {
                label: rt,
                data: p.thread_counts.map(function (t) { return p.values[t][rt]; }),
                backgroundColor: colorOf(rt),
                borderRadius: 4,
                maxBarThickness: 64
              };
            });
            new Chart(document.getElementById("parallelism-chart"), {
              type: "bar",
              data: { labels: labels, datasets: ds },
              options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { position: "top", labels: { font: { size: 14 }, padding: 16 } } },
                scales: {
                  x: { ticks: { font: { size: 13 } } },
                  y: { beginAtZero: true, ticks: { font: { size: 13 } }, title: { display: true, text: "speedup (1スレッド比)" } }
                }
              }
            });
          }
        })();
      JS
    end
  end
end
