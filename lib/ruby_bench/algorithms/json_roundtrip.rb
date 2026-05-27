# typed: true
# frozen_string_literal: true

require "json"

module RubyBench
  module Algorithms
    # JsonRoundtrip Web API が毎リクエストで通る JSON 生成とパースの往復を模した処理。
    # 数値計算のホットループとは異なり、文字列構築とハッシュ操作とアロケーションが支配的になる。
    module JsonRoundtrip
      # build_record Web レスポンス1件分を模したネスト構造の Hash を返す。
      def self.build_record(index)
        {
          id: index,
          name: "user_#{index}",
          active: index.even?,
          score: index * 1.5,
          tags: ["t#{index % 7}", "t#{index % 13}", "t#{index % 29}"],
          profile: {
            email: "user_#{index}@example.com",
            age: 20 + (index % 40),
            address: {
              city: "city_#{index % 100}",
              zip: format("%05d", index % 100_000)
            }
          }
        }
      end

      # run count 件のレコードを JSON 文字列へ変換してから再度パースし、復元できた件数を返す。
      def self.run(count)
        records = Array.new(count) { |i| build_record(i) }
        encoded = JSON.generate(records)
        decoded = JSON.parse(encoded)
        decoded.size
      end
    end
  end
end
