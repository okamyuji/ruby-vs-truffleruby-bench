# typed: true
# frozen_string_literal: true

require "cgi"
require "json"

module RubyBench
  class HtmlRenderer
    # Extras 起動時間・ウォームアップ曲線・イメージサイズという、ホットループのスループット以外の
    # 比較軸を描画するためのデータ整形と HTML/JS 生成。HtmlRenderer 本体の ClassLength を
    # 抑えるためにモジュールへ外出ししている。データが無い payload では各セクションを描画しない。
    module Extras
      module_function

      # runtime_ids payload 群からランタイム id を出現順で重複なく返す。
      def runtime_ids(payloads)
        payloads.filter_map { |p| (p[:runtime_metadata] || {})[:id] }.uniq
      end

      def payload_for(payloads, rid)
        payloads.find { |p| (p[:runtime_metadata] || {})[:id] == rid }
      end

      def startup?(payloads)
        payloads.any? { |p| p[:startup] }
      end

      def warmup?(payloads)
        payloads.any? { |p| p[:warmup] }
      end

      def parallelism?(payloads)
        payloads.any? { |p| p[:parallelism] }
      end

      # startup_data → { scenarios:, runtimes:, values: {scenario => {runtime => median_ms}} }
      def startup_data(payloads)
        runtimes = runtime_ids(payloads)
        scenarios = payloads.flat_map { |p| ((p[:startup] || {})[:scenarios] || []).map { |s| s[:scenario] } }.uniq
        values =
          scenarios.each_with_object({}) do |scenario, acc|
            acc[scenario] = runtimes.each_with_object({}) { |rid, by| by[rid] = startup_median(payloads, rid, scenario) }
          end
        { scenarios: scenarios, runtimes: runtimes, values: values }
      end

      def startup_median(payloads, rid, scenario)
        payload = payload_for(payloads, rid)
        return nil unless payload

        entry = ((payload[:startup] || {})[:scenarios] || []).find { |s| s[:scenario] == scenario }
        entry && entry[:median_ms]
      end

      # warmup_data → { labels: [1..N], runtimes:, series: {runtime => [ms,...]}, algorithm: }
      def warmup_data(payloads)
        runtimes = runtime_ids(payloads)
        series =
          runtimes.each_with_object({}) do |rid, acc|
            payload = payload_for(payloads, rid)
            acc[rid] = payload ? ((payload[:warmup] || {})[:wall_ms] || []) : []
          end
        max_len = series.values.map(&:size).max || 0
        algo = payloads.filter_map { |p| (p[:warmup] || {})[:algorithm] }.first
        { labels: (1..max_len).to_a, runtimes: runtimes, series: series, algorithm: algo }
      end

      # parallelism_data → { thread_counts: [1,2,..], runtimes:, values: {threads => {runtime => speedup}} }
      def parallelism_data(payloads)
        runtimes = runtime_ids(payloads)
        thread_counts = payloads.flat_map { |p| ((p[:parallelism] || {})[:samples] || []).map { |s| s[:threads] } }.uniq.sort
        values =
          thread_counts.each_with_object({}) do |threads, acc|
            acc[threads] = runtimes.each_with_object({}) { |rid, by| by[rid] = parallel_speedup(payloads, rid, threads) }
          end
        { thread_counts: thread_counts, runtimes: runtimes, values: values }
      end

      def parallel_speedup(payloads, rid, threads)
        payload = payload_for(payloads, rid)
        return nil unless payload

        entry = ((payload[:parallelism] || {})[:samples] || []).find { |s| s[:threads] == threads }
        entry && entry[:speedup]
      end

      # image_size_rows image_sizes (シンボルキー) から payload に存在するランタイムぶんの行を作る。
      def image_size_rows(image_sizes, payloads)
        return [] unless image_sizes

        images = image_sizes[:images] || {}
        runtime_ids(payloads).filter_map do |rid|
          info = images[rid.to_sym]
          next unless info

          { runtime: rid, image: info[:image], mb: bytes_to_mb(info[:size_bytes]) }
        end
      end

      def bytes_to_mb(bytes)
        bytes.nil? ? nil : (bytes.to_f / 1024.0 / 1024.0)
      end

      # any? いずれかの追加セクションを描画する余地があるか。
      def any?(payloads, image_sizes)
        startup?(payloads) || warmup?(payloads) || parallelism?(payloads) || !image_size_rows(image_sizes, payloads).empty?
      end

      # sections_html 起動・ウォームアップ・並列・イメージサイズの各セクション HTML を結合して返す。
      def sections_html(payloads, image_sizes)
        parts = []
        parts << startup_section_html if startup?(payloads)
        parts << warmup_section_html(payloads) if warmup?(payloads)
        parts << parallelism_section_html if parallelism?(payloads)
        rows = image_size_rows(image_sizes, payloads)
        parts << image_size_section_html(rows) unless rows.empty?
        parts.join("\n")
      end

      def parallelism_section_html
        <<~CARD
          <div class="chart-card">
            <h3>並列スケーリング (高いほど良い・1スレッド比の速度)</h3>
            <p class="subtitle">総仕事量を固定しスレッド数を増やしたときの wall 時間の speedup。MRI は GVL により CPU バウンド処理が直列化されスケールしません (YJIT 有効時はロック競合で 1 倍を下回ることもあります)。GVL を持たない TruffleRuby はコア数まで真の並列でスケールします。</p>
            <div class="chart-wrap"><canvas id="parallelism-chart"></canvas></div>
          </div>
        CARD
      end

      def startup_section_html
        <<~CARD
          <div class="chart-card">
            <h3>起動時間 (低いほど速い・コールドスタート相当)</h3>
            <p class="subtitle">サブプロセス起動の中央値 (ms)。bare は素のインタプリタ起動、stdlib_require は標準ライブラリ require 込み。サーバーレスやオートスケールの起動コストの代理指標です。</p>
            <div class="chart-wrap"><canvas id="startup-chart"></canvas></div>
          </div>
        CARD
      end

      def warmup_section_html(payloads)
        algo = CGI.escapeHTML((warmup_data(payloads)[:algorithm] || "代表アルゴリズム").to_s)
        <<~CARD
          <div class="chart-card">
            <h3>ウォームアップ曲線 (#{algo}・低いほど速い)</h3>
            <p class="subtitle">同一処理を連続実行したときの1回あたり所要時間 (ms) の推移。JIT 実装は最初が遅く、回を重ねると速くなります。短命プロセスでは温まり切らない点に注意してください。</p>
            <div class="chart-wrap"><canvas id="warmup-chart"></canvas></div>
          </div>
        CARD
      end

      def image_size_section_html(rows)
        body =
          rows
            .map do |row|
              mb = row[:mb].nil? ? "N/A" : Kernel.format("%.0f", row[:mb])
              image = CGI.escapeHTML(row[:image].to_s)
              %(<tr><td class="runtime-#{CGI.escapeHTML(row[:runtime])}">#{CGI.escapeHTML(row[:runtime])}</td><td>#{image}</td><td>#{mb}</td></tr>)
            end
            .join("\n")
        <<~TABLE
          <div class="chart-card">
            <h3>Docker イメージサイズ (低いほど省コスト)</h3>
            <p class="subtitle">ECR からの pull 時間・ストレージ・転送コストに直結します。mri と mri-yjit は同一イメージを共有します。</p>
            <table class="summary">
              <thead><tr><th>ランタイム</th><th>イメージ</th><th>サイズ(MB)</th></tr></thead>
              <tbody>#{body}</tbody>
            </table>
          </div>
        TABLE
      end

      # extras_json startup / warmup / parallelism のグラフ用データを JSON 文字列で返す (script タグ埋め込み用)。
      def extras_json(payloads)
        data = {}
        data[:startup] = startup_data(payloads) if startup?(payloads)
        data[:warmup] = warmup_data(payloads) if warmup?(payloads)
        data[:parallelism] = parallelism_data(payloads) if parallelism?(payloads)
        JSON.generate(data).gsub("</", "<\\/")
      end
    end
  end
end
