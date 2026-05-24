# ruby-vs-truffleruby-bench

MRI Ruby 3.4.9とTruffleRuby 34.0.1 (Ruby 3.4.9互換) をDocker上で並列に走らせ、Rubyが遅いとされる代表アルゴリズム4種について時間とメモリとCPUとGC統計を比較するベンチマーク基盤です。

両ランタイムをCRuby 3.4.9に揃えて比較しています。MRIは公式の`ruby:3.4.9-bookworm`イメージを使い、TruffleRubyは[TruffleRuby 34.0.1のCommunity Native release asset](https://github.com/oracle/truffleruby/releases/tag/graal-34.0.1)を`buildpack-deps:stable`上に展開して使っています。ghcrの`graalvm/truffleruby-community`は執筆時点でまだRuby 3.3までしか公開されていないため、Ruby 3.4互換のTruffleRuby 34系を使うためにこの構成を採用しました。

## 対象アルゴリズム

- 再帰フィボナッチ
- マンデルブロ集合
- N-bodyシミュレーション
- エラトステネスのふるい

## 計測指標

- 実行時間 (wall_time_sとiterations_per_second)
- ピークRSSバイト数
- CPU userとsys秒
- GC回数差分とGC時間差分
- メモリアロケーション数 (totalとretained。TruffleRubyは計装非対応のため値が出ません)

## クイックスタート

```bash
git clone https://github.com/okamyuji/ruby-vs-truffleruby-bench.git
cd ruby-vs-truffleruby-bench
make build
make bench
open results/report.html
```

## 主要コマンド

- `make build` 両ランタイムのDockerイメージを構築
- `make bench` 両ランタイムでベンチマーク実行とHTMLレポート生成
- `make bench-mri` MRIのみ実行
- `make bench-truffleruby` TruffleRubyのみ実行
- `make test` Minitestを実行
- `make lint` RuboCop
- `make format` syntax_tree write
- `make typecheck` Sorbet tc
- `make check` lint + format-check + typecheck + test + build

## 品質ゲート

pre-commit (lefthook) でsyntax_tree checkとRuboCopとSorbet tcを実行します。
pre-push (lefthook) でMinitestとdocker compose buildとbenchスモーク実行を行います。
CI (GitHub Actions) で品質ゲートとDockerビルドとスモーク実行をMRIとTruffleRubyのマトリクスで実行します。

## ディレクトリ構成

実装計画と詳細設計は`docs/2026-05-24-implementation-plan.md`に記載しています。

## 実装メモ

Sorbetランタイム検査は`T::Configuration.default_checked_level = :never`でオフにしているため、本番計測時のオーバーヘッドはありません。TruffleRuby側ではdevelopmentグループのgemを入れない設定になっています。TruffleRubyの公式tarball展開は`buildpack-deps:stable`上で行い、SHA-256で改ざん検出をしています。
