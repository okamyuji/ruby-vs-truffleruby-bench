# ruby-vs-truffleruby-bench

MRI Ruby 3.4 と TruffleRuby 3.4 を Docker 上で並べて走らせ、Ruby が遅いとされる代表アルゴリズム4種について時間とメモリと CPU と GC 統計を比較するベンチマーク基盤です。

## 対象アルゴリズム

- 再帰フィボナッチ
- マンデルブロ集合
- N-body シミュレーション
- エラトステネスのふるい

## 計測指標

- 実行時間(wall_time_s と iterations_per_second)
- ピーク RSS バイト数
- CPU user と sys 秒
- GC 回数差分と GC 時間差分
- メモリアロケーション数(total と retained)

## クイックスタート

```bash
cd ruby-vs-truffleruby-bench
make build
make bench
open results/report.html
```

## 主要コマンド

- `make build` 両ランタイムの Docker イメージを構築
- `make bench` 両ランタイムでベンチマーク実行とHTMLレポート生成
- `make bench-mri` MRI のみ実行
- `make bench-truffleruby` TruffleRuby のみ実行
- `make test` Minitest を実行
- `make lint` RuboCop
- `make format` syntax_tree write
- `make typecheck` Sorbet tc
- `make check` lint + format-check + typecheck + test + build

## 品質ゲート

pre-commit(lefthook)で syntax_tree check と RuboCop と Sorbet tc を実行します。
pre-push(lefthook)で Minitest と docker compose build と bench スモーク実行を行います。
CI(GitHub Actions)で品質ゲートと Docker ビルドとスモーク実行を MRI と TruffleRuby のマトリクスで実行します。

## ディレクトリ構成

実装計画と詳細設計は `docs/2026-05-24-implementation-plan.md` に記載しています。

## 実装メモ

Sorbet ランタイム検査は `T::Configuration.default_checked_level = :never` でオフにしているため、本番計測時のオーバーヘッドはありません。TruffleRuby 側では development グループの gem を入れない設定になっています。
