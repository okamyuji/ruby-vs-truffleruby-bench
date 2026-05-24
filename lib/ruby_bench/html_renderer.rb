# typed: true
# frozen_string_literal: true

require "json"
require "cgi"
require "fileutils"
require_relative "html_renderer/assets"

module RubyBench
  class HtmlRenderer
    extend T::Sig

    class IOFailure < StandardError
    end

    CHARTJS_CDN = "https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.min.js"
    # CHARTJS_SRI は chart.js@4.5.1/dist/chart.umd.min.js の SHA-384 ハッシュ。
    # 検証手順: curl -sL <CHARTJS_CDN> | openssl dgst -sha384 -binary | openssl base64 -A
    CHARTJS_SRI = "sha384-jb8JQMbMoBUzgWatfe6COACi2ljcDdZQ2OxczGA3bGNeWe+6DChMTBJemed7ZnvJ"

    # alloc は TruffleRuby 側で ObjectSpace 計装が動かないため、TruffleRuby だけ
    # null にして「計装非対応」と明示する。MRI のみ参考値として表示する。
    UNINSTRUMENTED_RUNTIMES_FOR_ALLOC = %w[truffleruby].freeze

    CHARTS = [
      { id: "ips", metric: "iterations_per_second", title: "Iterations per second (高いほど速い・真の速度比較指標)", subtitle: nil },
      {
        id: "wall",
        metric: "wall_time_s",
        title: "Wall time seconds (低いほど速い)",
        subtitle: "※ benchmark-ips の計測ウィンドウ長 (warmup+measure)。 ほぼ一定になるのが正常で、速度比較は ips を参照してください。"
      },
      {
        id: "rss",
        metric: "rss_bytes_peak",
        title: "Peak RSS bytes",
        subtitle: "プロセス常駐メモリのピーク。TruffleRuby は GraalVM ランタイム常駐分を含みます。"
      },
      { id: "gc", metric: "gc_time_ms_delta", title: "GC time ms delta", subtitle: nil },
      { id: "cpu", metric: "cpu_user_s", title: "CPU user seconds", subtitle: nil },
      {
        id: "alloc",
        metric: "allocations_total",
        title: "Total allocations (MRI のみ)",
        subtitle: "TruffleRuby は ObjectSpace 計装非対応のため値を表示しません。"
      }
    ].freeze

    # 数値テーブル列定義。private より上に置くのは Lint/UselessConstantScoping 回避のため。
    SUMMARY_COLUMNS = [
      { key: "iterations_per_second", label: "ips", fmt: :float2 },
      { key: "wall_time_s", label: "wall(s)", fmt: :float3 },
      { key: "rss_bytes_peak", label: "RSS(MB)", fmt: :mb },
      { key: "gc_count_delta", label: "GC回数", fmt: :int },
      { key: "gc_time_ms_delta", label: "GC(ms)", fmt: :float1 },
      { key: "cpu_user_s", label: "CPU user(s)", fmt: :float3 },
      { key: "allocations_total", label: "alloc total", fmt: :int }
    ].freeze

    sig { params(payloads: T::Array[T::Hash[Symbol, T.untyped]]).void }
    def initialize(payloads)
      @payloads = payloads
    end

    sig { returns(String) }
    def render
      <<~HTML
        <!doctype html>
        <html lang="ja">
        #{head_html}
        #{body_html}
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

    private

    sig { returns(String) }
    def head_html
      <<~HEAD
        <head>
          <meta charset="utf-8" />
          <title>Ruby 3.4 vs TruffleRuby 3.4 ベンチマークレポート</title>
          <script src="#{CHARTJS_CDN}" integrity="#{CHARTJS_SRI}" crossorigin="anonymous"></script>
          <style>#{stylesheet}</style>
        </head>
      HEAD
    end

    sig { returns(String) }
    def stylesheet
      Assets::STYLESHEET
    end

    sig { returns(String) }
    def body_html
      pretty = CGI.escapeHTML(JSON.pretty_generate(@payloads))
      data_json = JSON.generate(charts_payload).gsub("</", "<\\/")
      <<~BODY
        <body>
          <header>
            <h1>Ruby 3.4 vs TruffleRuby 3.4 ベンチマークレポート</h1>
            <p class="meta">#{runtime_meta_line}</p>
          </header>
          <main>
            <h2>主要指標 (グラフ)</h2>
            <section class="charts">
              #{CHARTS.map { |c| chart_card_html(c) }.join("\n")}
            </section>

            <h2>主要指標 (数値テーブル)</h2>
            #{summary_table_html}

            <details>
              <summary>収集データ (生 JSON)</summary>
              <pre id="raw-data">#{pretty}</pre>
            </details>
          </main>

          <script id="payloads-json" type="application/json">#{data_json}</script>
          <script>#{chart_script}</script>
        </body>
      BODY
    end

    sig { returns(String) }
    def chart_script
      charts_config = JSON.generate(CHARTS.map { |c| { id: c[:id], metric: c[:metric], title: c[:title] } })
      Assets::CHART_SCRIPT_TEMPLATE.sub("%CHARTS_CONFIG%", charts_config)
    end

    sig { returns(T::Array[String]) }
    def algorithms
      @algorithms ||= @payloads.flat_map { |p| (p[:measurements] || []).map { |m| m[:algorithm] } }.compact.uniq
    end

    sig { returns(T::Array[String]) }
    def runtime_ids
      @runtime_ids ||= @payloads.filter_map { |p| (p[:runtime_metadata] || {})[:id] }.uniq
    end

    sig { returns(String) }
    def runtime_meta_line
      runtime_ids.filter_map { |rid| meta_description_for(rid) }.join(" / ")
    end

    sig { params(rid: String).returns(T.nilable(String)) }
    def meta_description_for(rid)
      payload = @payloads.find { |p| (p[:runtime_metadata] || {})[:id] == rid }
      return nil unless payload

      meta = payload[:runtime_metadata] || {}
      engine = CGI.escapeHTML(meta[:engine] || "?")
      engine_ver = CGI.escapeHTML(meta[:engine_version] || "?")
      ruby_ver = CGI.escapeHTML(meta[:ruby_version] || "?")
      platform = CGI.escapeHTML(meta[:platform] || "?")
      "#{CGI.escapeHTML(rid)}: #{engine} #{engine_ver} (ruby #{ruby_ver}, #{platform})"
    end

    # Chart 側に渡す pivot 化済みのデータ。
    # values[metric][runtime][algorithm] => Number or nil (null)
    sig { returns(T::Hash[Symbol, T.untyped]) }
    def charts_payload
      values =
        CHARTS.each_with_object({}) do |chart, acc|
          acc[chart[:metric]] = runtime_ids.each_with_object({}) do |rid, by_rt|
            by_rt[rid] = algorithms.each_with_object({}) do |algo, by_algo|
              by_algo[algo] = metric_value(rid, algo, chart[:metric])
            end
          end
        end
      { algorithms: algorithms, runtimes: runtime_ids, values: values }
    end

    sig { params(rid: String, algo: String, metric: String).returns(T.untyped) }
    def metric_value(rid, algo, metric)
      payload = @payloads.find { |p| (p[:runtime_metadata] || {})[:id] == rid }
      return nil unless payload

      m = (payload[:measurements] || []).find { |x| x[:algorithm] == algo }
      return nil unless m

      key = metric.to_sym
      return nil if metric == "allocations_total" && UNINSTRUMENTED_RUNTIMES_FOR_ALLOC.include?(rid)

      m[key]
    end

    sig { params(chart: T::Hash[Symbol, T.untyped]).returns(String) }
    def chart_card_html(chart)
      sub = chart[:subtitle] ? %(<p class="subtitle">#{CGI.escapeHTML(chart[:subtitle])}</p>) : ""
      <<~CARD
        <div class="chart-card">
          <h3>#{CGI.escapeHTML(chart[:title])}</h3>
          #{sub}
          <div class="chart-wrap"><canvas id="#{chart[:id]}"></canvas></div>
        </div>
      CARD
    end

    sig { returns(String) }
    def summary_table_html
      head_cells = +"<th>アルゴリズム</th><th>ランタイム</th>"
      SUMMARY_COLUMNS.each { |c| head_cells << "<th>#{CGI.escapeHTML(c[:label])}</th>" }
      body_rows =
        algorithms
          .flat_map do |algo|
            runtime_ids.map do |rid|
              cells = +""
              cells << %(<td class="runtime-#{CGI.escapeHTML(rid)}">#{CGI.escapeHTML(rid)}</td>)
              SUMMARY_COLUMNS.each do |col|
                raw = metric_value(rid, algo, col[:key])
                cells << (raw.nil? ? %(<td class="na">N/A</td>) : %(<td>#{format_value(raw, col[:fmt])}</td>))
              end
              %(<tr><td>#{CGI.escapeHTML(algo)}</td>#{cells}</tr>)
            end
          end
          .join("\n")

      <<~TABLE
        <table class="summary">
          <thead><tr>#{head_cells}</tr></thead>
          <tbody>
            #{body_rows}
          </tbody>
        </table>
      TABLE
    end

    sig { params(value: T.untyped, fmt: Symbol).returns(String) }
    def format_value(value, fmt)
      case fmt
      when :int
        value.to_i.to_s
      when :float1
        format("%.1f", value.to_f)
      when :float2
        format("%.2f", value.to_f)
      when :float3
        format("%.4f", value.to_f)
      when :mb
        format("%.1f", value.to_f / 1024.0 / 1024.0)
      else
        value.to_s
      end
    end
  end
end
