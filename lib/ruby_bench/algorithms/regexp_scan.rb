# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    # RegexpScan Web サーバーのアクセスログ解析を模した正規表現マッチ主体の処理。
    # 正規表現エンジンと文字列操作の効率が支配的で、数値計算とは別系統の負荷をかける。
    module RegexpScan
      LINE_PATTERN =
        /
        \A
        (?<ip>\d{1,3}(?:\.\d{1,3}){3})
        \s\S+\s\S+\s
        \[(?<time>[^\]]+)\]
        \s"(?<method>GET|POST|PUT|DELETE)\s(?<path>\S+)\s[^"]+"
        \s(?<status>\d{3})
        \s(?<bytes>\d+)
      /x

      # HTTP_METHODS / STATUS_CODES build_line がホットループで毎回配列を確保しないよう定数化する。
      HTTP_METHODS = %w[GET POST PUT DELETE].freeze
      STATUS_CODES = [200, 201, 301, 404, 500].freeze

      # build_line index 番目の合成アクセスログ行を返す。
      def self.build_line(index)
        ip = "#{index % 256}.#{(index / 256) % 256}.0.1"
        method = HTTP_METHODS[index % 4]
        path = "/api/v1/resource/#{index % 1000}?page=#{index % 50}"
        status = STATUS_CODES[index % 5]
        bytes = (index * 17) % 9000
        seconds = format("%02d", index % 60)
        %(#{ip} - - [10/Oct/2026:13:55:#{seconds} +0900] "#{method} #{path} HTTP/1.1" #{status} #{bytes})
      end

      # run lines 行の合成ログを生成し、正規表現でステータス 5xx の行数を数えて返す。
      def self.run(lines)
        server_errors = 0
        i = 0
        while i < lines
          md = LINE_PATTERN.match(build_line(i))
          server_errors += 1 if md && md[:status].to_i >= 500
          i += 1
        end
        server_errors
      end
    end
  end
end
