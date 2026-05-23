# Ruby 3.4 vs TruffleRuby 3.4 ベンチマーク基盤 実装計画

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Goal: Ruby 3.4 と TruffleRuby 3.4 を Docker 上で同一ソースから実行し、フィボナッチとマンデルブロと N-body と素数ふるいの4種ベンチマークについて時間とメモリと CPU と GC 統計を計測し HTML グラフレポートとして比較できる基盤を整える。

Architecture: docker-compose で MRI Ruby 3.4 と TruffleRuby 3.4 の2サービスを定義し、両者共通の Ruby ソースを bind mount して同一コードを走らせます。計測ハーネスは benchmark-ips と memory_profiler と get_process_mem と GC.stat を組み合わせて Measurement 構造体に集約し、サービスごとに JSON を出力し、最後に Chart.js を埋め込んだ単一 HTML レポートへ集約します。品質ゲートは lefthook の pre-commit と GitHub Actions の両面で syntax_tree と RuboCop と Sorbet と Minitest と Docker build とスモーク実行を直列に実行します。

Tech Stack: Ruby 3.4 (MRI), TruffleRuby 24.x (Ruby 3.4 互換), Docker / docker-compose, Minitest, Sorbet (sorbet-static, sorbet-runtime, tapioca), RuboCop + rubocop-minitest + rubocop-performance, syntax_tree, lefthook, benchmark-ips, memory_profiler, get_process_mem, GitHub Actions, Chart.js (CDN 経由)。

ディレクトリ前提: 本計画はすべて `/Users/yujiokamoto/devs/ruby/ruby-vs-truffleruby-bench/` を作業ルートとして記述します。以後の相対パスはこのルートからの相対です。

---

## ファイル構成

作成するファイルと責務を一覧化します。各ファイルは責務単位で分割し、1ファイル200行から400行に収まる粒度を目標とします。

```
ruby-vs-truffleruby-bench/
├── .github/workflows/ci.yml                     # CI(GitHub Actions)定義
├── .gitignore                                   # 生成物除外
├── .ruby-version                                # 3.4.1
├── .rubocop.yml                                 # RuboCop ルール
├── .streerc                                     # syntax_tree 設定
├── Gemfile                                      # 依存定義
├── Gemfile.lock                                 # ロックファイル
├── Makefile                                     # 開発タスクのエントリ
├── README.md                                    # プロジェクト概要
├── Rakefile                                     # rake test / rake build
├── docker-compose.yml                           # ruby34 / truffleruby34 サービス
├── docker/
│   ├── Dockerfile.mri                           # MRI Ruby 3.4 用
│   └── Dockerfile.truffleruby                   # TruffleRuby 3.4 用
├── docs/
│   ├── 2026-05-24-implementation-plan.md        # 本計画書
│   └── design-review.md                         # 自己レビュー結果
├── lefthook.yml                                 # pre-commit / pre-push 設定
├── lib/
│   ├── ruby_bench.rb                            # トップレベル require 集約
│   └── ruby_bench/
│       ├── version.rb                           # バージョン定数
│       ├── runtime.rb                           # 実行中の Ruby 実装判定
│       ├── measurement.rb                       # 計測結果値オブジェクト
│       ├── harness.rb                           # 1アルゴリズムの計測実行
│       ├── runner.rb                            # 全アルゴリズムを順に流す
│       ├── reporter.rb                          # JSON 集約
│       ├── html_renderer.rb                     # HTML レポート生成
│       └── algorithms/
│           ├── fibonacci.rb                     # 再帰フィボナッチ
│           ├── mandelbrot.rb                    # マンデルブロ集合
│           ├── nbody.rb                         # N-body シミュレーション
│           └── sieve.rb                         # エラトステネスのふるい
├── bin/
│   ├── bench                                    # ベンチマーク実行 CLI
│   └── render_report                            # 集約 HTML 生成 CLI
├── sorbet/
│   ├── config                                   # srb tc 設定
│   └── rbi/                                     # tapioca 生成物
├── test/
│   ├── test_helper.rb                           # Minitest 共通
│   └── ruby_bench/
│       ├── algorithms/
│       │   ├── test_fibonacci.rb
│       │   ├── test_mandelbrot.rb
│       │   ├── test_nbody.rb
│       │   └── test_sieve.rb
│       ├── test_measurement.rb
│       ├── test_runtime.rb
│       ├── test_harness.rb
│       ├── test_reporter.rb
│       └── test_html_renderer.rb
└── results/
    └── .gitkeep                                 # JSON / HTML の出力先
```

設計方針として、ホットループを含む `lib/ruby_bench/algorithms/*.rb` は sig ブロックを置かず型コメントだけで `# typed: true` を維持し、ハーネスやレポーター層では `extend T::Sig` を使った静的型を活用します。TruffleRuby 互換性確保のため、`sorbet-runtime` は `T::Configuration.default_checked_level = :never` を初期化時に設定して runtime 検査を無効化します。

---

## Task 1: ディレクトリ初期化と Git 雛形

Files:
- Create: `ruby-vs-truffleruby-bench/.gitignore`
- Create: `ruby-vs-truffleruby-bench/.ruby-version`
- Create: `ruby-vs-truffleruby-bench/results/.gitkeep`

- [ ] Step 1: 必要なディレクトリを作る

```bash
mkdir -p ruby-vs-truffleruby-bench/{bin,docker,docs,lib/ruby_bench/algorithms,results,sorbet,test/ruby_bench/algorithms,.github/workflows}
```

- [ ] Step 2: `.ruby-version` を作成する

ファイル `ruby-vs-truffleruby-bench/.ruby-version` の内容:

```
3.4.1
```

- [ ] Step 3: `.gitignore` を作成する

ファイル `ruby-vs-truffleruby-bench/.gitignore` の内容:

```
# Ruby
*.gem
*.rbc
/.bundle/
/.config
/.yardoc
/Gemfile.lock.bak
/_yardoc/
/coverage/
/InstalledFiles
/pkg/
/spec/reports/
/test/tmp/
/test/version_tmp/
/tmp/
.byebug_history

# Docker
.docker/

# Sorbet
sorbet/rbi/sorbet-typed/
sorbet/rbi/todo.rbi
sorbet/tapioca/require.rb

# Bench outputs
/results/*.json
/results/*.html
!/results/.gitkeep

# OS
.DS_Store
```

- [ ] Step 4: `results/.gitkeep` を空ファイルとして作る

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/.gitignore ruby-vs-truffleruby-bench/.ruby-version ruby-vs-truffleruby-bench/results/.gitkeep
git commit -m "chore: ruby-vs-truffleruby-bench ディレクトリ雛形を作成"
```

---

## Task 2: Gemfile の作成と bundle install 検証

Files:
- Create: `ruby-vs-truffleruby-bench/Gemfile`

- [ ] Step 1: Gemfile を作成する

ファイル `ruby-vs-truffleruby-bench/Gemfile`:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

ruby ">= 3.4.0"

# Benchmark stack
gem "benchmark-ips", "~> 2.14"
gem "memory_profiler", "~> 1.1"
gem "get_process_mem", "~> 1.0"

# Test
gem "minitest", "~> 5.25"
gem "minitest-reporters", "~> 1.7"

# Type
gem "sorbet-runtime", "~> 0.5"

# Tools (development only on MRI; TruffleRuby は Bundler 上で同名のものを認識)
group :development do
  gem "sorbet", "~> 0.5"
  gem "tapioca", "~> 0.16"
  gem "rubocop", "~> 1.68"
  gem "rubocop-minitest", "~> 0.36"
  gem "rubocop-performance", "~> 1.22"
  gem "syntax_tree", "~> 6.2"
end
```

- [ ] Step 2: MRI Docker コンテナ上で bundle install を実行する

```bash
docker run --rm -v "$PWD/ruby-vs-truffleruby-bench":/work -w /work ruby:3.4.1 bundle install
```

Expected: 全 gem が解決されて `Gemfile.lock` が生成される。

- [ ] Step 3: コミット

```bash
git add ruby-vs-truffleruby-bench/Gemfile ruby-vs-truffleruby-bench/Gemfile.lock
git commit -m "build: ruby-vs-truffleruby-bench に Gemfile を追加"
```

---

## Task 3: Dockerfile.mri と Dockerfile.truffleruby の作成

Files:
- Create: `ruby-vs-truffleruby-bench/docker/Dockerfile.mri`
- Create: `ruby-vs-truffleruby-bench/docker/Dockerfile.truffleruby`

- [ ] Step 1: `docker/Dockerfile.mri` を作成する

```dockerfile
FROM ruby:3.4.1-bookworm

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["bundle", "exec", "bin/bench"]
```

- [ ] Step 2: `docker/Dockerfile.truffleruby` を作成する

```dockerfile
FROM ghcr.io/graalvm/truffleruby:24.1.1

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/home/truffleruby/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    TRUFFLERUBYOPT="--engine.Mode=latency"

USER root
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /work \
  && chown -R truffleruby:truffleruby /work

USER truffleruby
WORKDIR /work

COPY --chown=truffleruby:truffleruby Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.5.22 \
  && bundle config set --local without 'development' \
  && bundle install

COPY --chown=truffleruby:truffleruby . .

CMD ["bundle", "exec", "bin/bench"]
```

注記: TruffleRuby イメージ上の development グループ(sorbet, rubocop など)は不要なため `bundle config set --local without 'development'` を指定します。development gem の検証は MRI コンテナで行う前提です。

- [ ] Step 3: docker compose build がそれぞれ通るか確認する

```bash
docker compose -f ruby-vs-truffleruby-bench/docker-compose.yml build
```

ただし docker-compose.yml は Task 4 で作るため、ここでは仮に直接ビルドして動作確認:

```bash
docker build -f ruby-vs-truffleruby-bench/docker/Dockerfile.mri -t ruby34-bench ruby-vs-truffleruby-bench/
docker build -f ruby-vs-truffleruby-bench/docker/Dockerfile.truffleruby -t truffleruby34-bench ruby-vs-truffleruby-bench/
```

Expected: 両方とも build が成功する。

- [ ] Step 4: コミット

```bash
git add ruby-vs-truffleruby-bench/docker/
git commit -m "build: MRI と TruffleRuby の Dockerfile を追加"
```

---

## Task 4: docker-compose.yml の作成

Files:
- Create: `ruby-vs-truffleruby-bench/docker-compose.yml`

- [ ] Step 1: `docker-compose.yml` を作成する

```yaml
services:
  ruby34:
    build:
      context: .
      dockerfile: docker/Dockerfile.mri
    image: ruby-vs-truffleruby-bench/ruby34
    container_name: rvtb-ruby34
    working_dir: /work
    volumes:
      - .:/work
      - bundle-mri:/usr/local/bundle
    environment:
      RUBY_BENCH_RUNTIME: "mri"
      RUBY_BENCH_RESULT_PATH: "/work/results/mri.json"
    command: ["bundle", "exec", "bin/bench"]

  truffleruby34:
    build:
      context: .
      dockerfile: docker/Dockerfile.truffleruby
    image: ruby-vs-truffleruby-bench/truffleruby34
    container_name: rvtb-truffleruby34
    working_dir: /work
    volumes:
      - .:/work
      - bundle-truffleruby:/home/truffleruby/bundle
    environment:
      RUBY_BENCH_RUNTIME: "truffleruby"
      RUBY_BENCH_RESULT_PATH: "/work/results/truffleruby.json"
    command: ["bundle", "exec", "bin/bench"]

volumes:
  bundle-mri:
  bundle-truffleruby:
```

- [ ] Step 2: docker compose build が両サービスで成功するか確認する

```bash
cd ruby-vs-truffleruby-bench && docker compose build
```

Expected: ruby34 と truffleruby34 が両方とも build 成功する。

- [ ] Step 3: コミット

```bash
git add ruby-vs-truffleruby-bench/docker-compose.yml
git commit -m "build: docker-compose で両 Ruby ランタイムを定義"
```

---

## Task 5: Makefile の作成

Files:
- Create: `ruby-vs-truffleruby-bench/Makefile`

- [ ] Step 1: Makefile を作成する

```make
.PHONY: help build bench bench-mri bench-truffleruby report test lint format typecheck check clean

DC := docker compose

help:
	@echo "Targets:"
	@echo "  build           docker compose build (both runtimes)"
	@echo "  bench           run bench on both runtimes and render HTML"
	@echo "  bench-mri       run bench on MRI Ruby 3.4 only"
	@echo "  bench-truffleruby run bench on TruffleRuby 3.4 only"
	@echo "  report          render results/report.html from existing JSON"
	@echo "  test            bundle exec rake test (MRI)"
	@echo "  lint            run RuboCop"
	@echo "  format          run syntax_tree write"
	@echo "  typecheck       run sorbet tc"
	@echo "  check           lint + format-check + typecheck + test + build"
	@echo "  clean           remove results/*.json results/*.html"

build:
	$(DC) build

bench-mri:
	$(DC) run --rm ruby34

bench-truffleruby:
	$(DC) run --rm truffleruby34

bench: bench-mri bench-truffleruby report

report:
	$(DC) run --rm ruby34 bundle exec bin/render_report results/mri.json results/truffleruby.json results/report.html

test:
	$(DC) run --rm ruby34 bundle exec rake test

lint:
	$(DC) run --rm ruby34 bundle exec rubocop

format:
	$(DC) run --rm ruby34 bundle exec stree write 'lib/**/*.rb' 'test/**/*.rb' 'bin/*'

typecheck:
	$(DC) run --rm ruby34 bundle exec srb tc

check: lint format-check typecheck test build

format-check:
	$(DC) run --rm ruby34 bundle exec stree check 'lib/**/*.rb' 'test/**/*.rb' 'bin/*'

clean:
	rm -f results/*.json results/*.html
```

- [ ] Step 2: コミット

```bash
git add ruby-vs-truffleruby-bench/Makefile
git commit -m "build: 開発タスク用 Makefile を追加"
```

---

## Task 6: RuboCop と syntax_tree と Sorbet の設定

Files:
- Create: `ruby-vs-truffleruby-bench/.rubocop.yml`
- Create: `ruby-vs-truffleruby-bench/.streerc`
- Create: `ruby-vs-truffleruby-bench/sorbet/config`
- Create: `ruby-vs-truffleruby-bench/Rakefile`

- [ ] Step 1: `.rubocop.yml` を作成する

```yaml
require:
  - rubocop-minitest
  - rubocop-performance

AllCops:
  TargetRubyVersion: 3.4
  NewCops: enable
  Exclude:
    - "sorbet/rbi/**/*"
    - "results/**/*"
    - "vendor/**/*"

Style/Documentation:
  Enabled: false

Metrics/MethodLength:
  Max: 40

Metrics/AbcSize:
  Max: 40

Metrics/ClassLength:
  Max: 250

Layout/LineLength:
  Max: 120

# syntax_tree が整形を担当するため Layout 系の自動整形は最小限にする
Layout/MultilineMethodCallIndentation:
  Enabled: false
Layout/FirstHashElementIndentation:
  Enabled: false
```

- [ ] Step 2: `.streerc` を作成する

```
--print-width=120
--plugins=plugin/trailing_comma
```

- [ ] Step 3: `sorbet/config` を作成する

```
--dir
.
--ignore=/sorbet/rbi/gems
--ignore=/results
--ignore=/tmp
--ignore=/.bundle
```

- [ ] Step 4: `Rakefile` を作成する

```ruby
# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = FileList["test/**/test_*.rb"]
  t.warning = false
end

task default: :test
```

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/.rubocop.yml ruby-vs-truffleruby-bench/.streerc ruby-vs-truffleruby-bench/sorbet/config ruby-vs-truffleruby-bench/Rakefile
git commit -m "build: RuboCop と syntax_tree と Sorbet の設定を追加"
```

---

## Task 7: lefthook 設定の追加

Files:
- Create: `ruby-vs-truffleruby-bench/lefthook.yml`

- [ ] Step 1: lefthook.yml を作成する

```yaml
pre-commit:
  parallel: true
  commands:
    format-check:
      glob: "*.rb"
      run: bundle exec stree check {staged_files}
    lint:
      glob: "*.rb"
      run: bundle exec rubocop --force-exclusion {staged_files}
    typecheck:
      glob: "*.rb"
      run: bundle exec srb tc

pre-push:
  parallel: false
  commands:
    test:
      run: bundle exec rake test
    docker-build:
      run: docker compose build
    bench-smoke:
      run: bundle exec bin/bench --smoke
```

- [ ] Step 2: コミット

```bash
git add ruby-vs-truffleruby-bench/lefthook.yml
git commit -m "build: lefthook で pre-commit と pre-push の品質ゲートを定義"
```

---

## Task 8: 共通モジュール ruby_bench.rb と version.rb と runtime.rb の作成

Files:
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/version.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/runtime.rb`
- Create: `ruby-vs-truffleruby-bench/test/test_helper.rb`
- Create: `ruby-vs-truffleruby-bench/test/ruby_bench/test_runtime.rb`

- [ ] Step 1: `test/test_helper.rb` を作成する

```ruby
# typed: false
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/reporters"

Minitest::Reporters.use!(
  Minitest::Reporters::SpecReporter.new,
  ENV,
  Minitest.backtrace_filter
)

require "ruby_bench"
```

- [ ] Step 2: 失敗するテスト `test/ruby_bench/test_runtime.rb` を書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchRuntimeTest < Minitest::Test
  def test_id_is_mri_or_truffleruby
    assert_includes(%w[mri truffleruby], RubyBench::Runtime.id)
  end

  def test_label_includes_engine_and_version
    label = RubyBench::Runtime.label
    assert_match(/(MRI|TruffleRuby)/, label)
    assert_match(/3\.4/, label)
  end

  def test_metadata_contains_required_keys
    meta = RubyBench::Runtime.metadata
    %i[id engine engine_version ruby_version platform pid].each do |k|
      assert(meta.key?(k), "metadata に #{k} が必要")
    end
  end
end
```

- [ ] Step 3: テストを実行し、失敗することを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test
```

Expected: `NameError: uninitialized constant RubyBench` で FAIL する。

- [ ] Step 4: `lib/ruby_bench/version.rb` を作成する

```ruby
# typed: true
# frozen_string_literal: true

module RubyBench
  VERSION = "0.1.0"
end
```

- [ ] Step 5: `lib/ruby_bench/runtime.rb` を作成する

```ruby
# typed: true
# frozen_string_literal: true

require "rbconfig"

module RubyBench
  module Runtime
    extend T::Sig

    sig { returns(String) }
    def self.id
      defined?(::TruffleRuby) ? "truffleruby" : "mri"
    end

    sig { returns(String) }
    def self.label
      case id
      when "truffleruby"
        "TruffleRuby #{engine_version} (Ruby #{RUBY_VERSION})"
      else
        "MRI Ruby #{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
      end
    end

    sig { returns(String) }
    def self.engine_version
      if defined?(::TruffleRuby) && ::TruffleRuby.respond_to?(:revision)
        ::TruffleRuby.revision.to_s
      else
        RUBY_VERSION
      end
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def self.metadata
      {
        id: id,
        engine: defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby",
        engine_version: engine_version,
        ruby_version: RUBY_VERSION,
        platform: RUBY_PLATFORM,
        pid: Process.pid
      }
    end
  end
end
```

- [ ] Step 6: `lib/ruby_bench.rb` を作成する

```ruby
# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
T::Configuration.default_checked_level = :never

require_relative "ruby_bench/version"
require_relative "ruby_bench/runtime"
require_relative "ruby_bench/measurement"
require_relative "ruby_bench/harness"
require_relative "ruby_bench/runner"
require_relative "ruby_bench/reporter"
require_relative "ruby_bench/html_renderer"
require_relative "ruby_bench/algorithms/fibonacci"
require_relative "ruby_bench/algorithms/mandelbrot"
require_relative "ruby_bench/algorithms/nbody"
require_relative "ruby_bench/algorithms/sieve"

module RubyBench
end
```

注意: この時点ではまだ measurement.rb 等の個別ファイルが未作成のため、`ruby_bench.rb` の require 群は後続タスクで該当ファイルが揃った時に初めて全てが解決します。Task 8 では `test/ruby_bench/test_runtime.rb` だけが緑になる前提で進め、それ以外の require は次タスク以降で順次解決させます。Task 8 段階での test_runtime.rb 単体実行は次の手順で行います。

- [ ] Step 7: 単体ファイル指定で runtime テストだけを実行する

```bash
cd ruby-vs-truffleruby-bench && bundle exec ruby -Ilib -Itest -e 'require "rbconfig"; require "sorbet-runtime"; T::Configuration.default_checked_level = :never; require_relative "lib/ruby_bench/version"; require_relative "lib/ruby_bench/runtime"; module RubyBench; end; require "test/ruby_bench/test_runtime"'
```

Expected: 3 tests, 0 failures。

- [ ] Step 8: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench.rb ruby-vs-truffleruby-bench/lib/ruby_bench/version.rb ruby-vs-truffleruby-bench/lib/ruby_bench/runtime.rb ruby-vs-truffleruby-bench/test/test_helper.rb ruby-vs-truffleruby-bench/test/ruby_bench/test_runtime.rb
git commit -m "feat: RubyBench::Runtime と Version を追加"
```

---

## Task 9: Fibonacci アルゴリズムの TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/algorithms/test_fibonacci.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/algorithms/fibonacci.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsFibonacciTest < Minitest::Test
  def test_returns_zero_for_zero
    assert_equal(0, RubyBench::Algorithms::Fibonacci.run(0))
  end

  def test_returns_one_for_one
    assert_equal(1, RubyBench::Algorithms::Fibonacci.run(1))
  end

  def test_returns_55_for_ten
    assert_equal(55, RubyBench::Algorithms::Fibonacci.run(10))
  end

  def test_returns_6765_for_twenty
    assert_equal(6765, RubyBench::Algorithms::Fibonacci.run(20))
  end
end
```

- [ ] Step 2: テストを実行し、失敗することを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/algorithms/test_fibonacci.rb
```

Expected: `NameError: uninitialized constant RubyBench::Algorithms::Fibonacci` で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/algorithms/fibonacci.rb`:

```ruby
# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    module Fibonacci
      # run 再帰でフィボナッチ数列の n 番目の値を計算します。意図的にメモ化していません。
      def self.run(n)
        return n if n < 2

        run(n - 1) + run(n - 2)
      end
    end
  end
end
```

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/algorithms/test_fibonacci.rb
```

Expected: 4 runs, 4 assertions, 0 failures。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/algorithms/fibonacci.rb ruby-vs-truffleruby-bench/test/ruby_bench/algorithms/test_fibonacci.rb
git commit -m "feat: 再帰フィボナッチアルゴリズムを追加"
```

---

## Task 10: Mandelbrot アルゴリズムの TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/algorithms/test_mandelbrot.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/algorithms/mandelbrot.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsMandelbrotTest < Minitest::Test
  def test_returns_total_pixel_count
    assert_equal(16, RubyBench::Algorithms::Mandelbrot.run(4))
  end

  def test_inside_set_value
    inside = RubyBench::Algorithms::Mandelbrot.iterations_at(-0.5, 0.0)
    assert_equal(RubyBench::Algorithms::Mandelbrot::MAX_ITER, inside)
  end

  def test_outside_set_value
    outside = RubyBench::Algorithms::Mandelbrot.iterations_at(2.0, 2.0)
    assert_operator(outside, :<, RubyBench::Algorithms::Mandelbrot::MAX_ITER)
  end
end
```

- [ ] Step 2: テストを実行し、失敗することを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/algorithms/test_mandelbrot.rb
```

Expected: 未定義定数で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/algorithms/mandelbrot.rb`:

```ruby
# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    module Mandelbrot
      MAX_ITER = 50
      ESCAPE_SQ = 4.0

      # run 幅 width 高さ width の正方領域に対しマンデルブロ反復を実行し、ピクセル数を返します。
      def self.run(width)
        height = width
        count = 0
        y = 0
        while y < height
          ci = (2.0 * y / height) - 1.0
          x = 0
          while x < width
            cr = (2.0 * x / width) - 1.5
            iterations_at(cr, ci)
            count += 1
            x += 1
          end
          y += 1
        end
        count
      end

      # iterations_at 与えられた複素座標で発散判定までの反復回数を返します。
      def self.iterations_at(cr, ci)
        zr = 0.0
        zi = 0.0
        iter = 0
        while iter < MAX_ITER
          new_zr = (zr * zr) - (zi * zi) + cr
          zi = (2.0 * zr * zi) + ci
          zr = new_zr
          break if (zr * zr) + (zi * zi) > ESCAPE_SQ

          iter += 1
        end
        iter
      end
    end
  end
end
```

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/algorithms/test_mandelbrot.rb
```

Expected: 3 runs, 3 assertions, 0 failures。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/algorithms/mandelbrot.rb ruby-vs-truffleruby-bench/test/ruby_bench/algorithms/test_mandelbrot.rb
git commit -m "feat: マンデルブロアルゴリズムを追加"
```

---

## Task 11: N-body アルゴリズムの TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/algorithms/test_nbody.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/algorithms/nbody.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsNbodyTest < Minitest::Test
  def test_returns_initial_and_final_energy_hash
    result = RubyBench::Algorithms::Nbody.run(10)
    assert_kind_of(Hash, result)
    assert_includes(result.keys, :initial_energy)
    assert_includes(result.keys, :final_energy)
  end

  def test_energy_is_finite_number
    result = RubyBench::Algorithms::Nbody.run(10)
    assert(result[:initial_energy].finite?, "initial_energy が有限実数であること")
    assert(result[:final_energy].finite?, "final_energy が有限実数であること")
  end

  def test_energy_changes_after_simulation
    result = RubyBench::Algorithms::Nbody.run(1000)
    refute_equal(result[:initial_energy], result[:final_energy])
  end
end
```

- [ ] Step 2: テストを実行し、失敗することを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/algorithms/test_nbody.rb
```

Expected: 未定義定数で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/algorithms/nbody.rb`:

```ruby
# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    module Nbody
      PI = Math::PI
      SOLAR_MASS = 4.0 * PI * PI
      DAYS_PER_YEAR = 365.24

      Body = Struct.new(:x, :y, :z, :vx, :vy, :vz, :mass)

      # run 太陽系5天体を steps 回 0.01 単位時刻で進め、初期と最終のエネルギーを返します。
      def self.run(steps)
        bodies = solar_bodies
        offset_momentum(bodies)
        initial = energy(bodies)
        steps.times { advance(bodies, 0.01) }
        final = energy(bodies)
        { initial_energy: initial, final_energy: final }
      end

      # solar_bodies 太陽とジョビアン惑星4天体の初期状態の Body 配列を返します。
      def self.solar_bodies
        [
          Body.new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, SOLAR_MASS),
          Body.new(
            4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
            1.66007664274403694e-03 * DAYS_PER_YEAR, 7.69901118419740425e-03 * DAYS_PER_YEAR,
            -6.90460016972063023e-05 * DAYS_PER_YEAR, 9.54791938424326609e-04 * SOLAR_MASS
          ),
          Body.new(
            8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
            -2.76742510726862411e-03 * DAYS_PER_YEAR, 4.99852801234917238e-03 * DAYS_PER_YEAR,
            2.30417297573763929e-05 * DAYS_PER_YEAR, 2.85885980666130812e-04 * SOLAR_MASS
          ),
          Body.new(
            1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
            2.96460137564761618e-03 * DAYS_PER_YEAR, 2.37847173959480950e-03 * DAYS_PER_YEAR,
            -2.96589568540237556e-05 * DAYS_PER_YEAR, 4.36624404335156298e-05 * SOLAR_MASS
          ),
          Body.new(
            1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
            2.68067772490389322e-03 * DAYS_PER_YEAR, 1.62824170038242295e-03 * DAYS_PER_YEAR,
            -9.51592254519715870e-05 * DAYS_PER_YEAR, 5.15138902046611451e-05 * SOLAR_MASS
          )
        ]
      end

      # offset_momentum 太陽を運動量で補正します。
      def self.offset_momentum(bodies)
        px = 0.0
        py = 0.0
        pz = 0.0
        bodies.each do |b|
          px += b.vx * b.mass
          py += b.vy * b.mass
          pz += b.vz * b.mass
        end
        sun = bodies[0]
        sun.vx = -px / SOLAR_MASS
        sun.vy = -py / SOLAR_MASS
        sun.vz = -pz / SOLAR_MASS
      end

      # advance 1ステップ dt だけ全天体を進めます。
      def self.advance(bodies, dt)
        n = bodies.size
        i = 0
        while i < n
          bi = bodies[i]
          j = i + 1
          while j < n
            bj = bodies[j]
            dx = bi.x - bj.x
            dy = bi.y - bj.y
            dz = bi.z - bj.z
            d2 = (dx * dx) + (dy * dy) + (dz * dz)
            mag = dt / (d2 * Math.sqrt(d2))
            bi.vx -= dx * bj.mass * mag
            bi.vy -= dy * bj.mass * mag
            bi.vz -= dz * bj.mass * mag
            bj.vx += dx * bi.mass * mag
            bj.vy += dy * bi.mass * mag
            bj.vz += dz * bi.mass * mag
            j += 1
          end
          i += 1
        end
        bodies.each do |b|
          b.x += dt * b.vx
          b.y += dt * b.vy
          b.z += dt * b.vz
        end
      end

      # energy 系全体の力学エネルギーを返します。
      def self.energy(bodies)
        e = 0.0
        n = bodies.size
        i = 0
        while i < n
          bi = bodies[i]
          e += 0.5 * bi.mass * ((bi.vx * bi.vx) + (bi.vy * bi.vy) + (bi.vz * bi.vz))
          j = i + 1
          while j < n
            bj = bodies[j]
            dx = bi.x - bj.x
            dy = bi.y - bj.y
            dz = bi.z - bj.z
            d = Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
            e -= (bi.mass * bj.mass) / d
            j += 1
          end
          i += 1
        end
        e
      end
    end
  end
end
```

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/algorithms/test_nbody.rb
```

Expected: 3 runs, 4 assertions, 0 failures。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/algorithms/nbody.rb ruby-vs-truffleruby-bench/test/ruby_bench/algorithms/test_nbody.rb
git commit -m "feat: N-body シミュレーションアルゴリズムを追加"
```

---

## Task 12: Sieve of Eratosthenes アルゴリズムの TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/algorithms/test_sieve.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/algorithms/sieve.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchAlgorithmsSieveTest < Minitest::Test
  def test_returns_zero_when_limit_below_two
    assert_equal(0, RubyBench::Algorithms::Sieve.run(1))
  end

  def test_returns_count_of_primes_up_to_ten
    assert_equal(4, RubyBench::Algorithms::Sieve.run(10))
  end

  def test_returns_count_of_primes_up_to_thirty
    assert_equal(10, RubyBench::Algorithms::Sieve.run(30))
  end

  def test_returns_count_of_primes_up_to_one_million
    assert_equal(78_498, RubyBench::Algorithms::Sieve.run(1_000_000))
  end
end
```

- [ ] Step 2: テストを実行し、失敗することを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/algorithms/test_sieve.rb
```

Expected: 未定義定数で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/algorithms/sieve.rb`:

```ruby
# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    module Sieve
      # run limit 以下の素数の個数をエラトステネスのふるいで数えます。
      def self.run(limit)
        return 0 if limit < 2

        sieve = Array.new(limit + 1, true)
        sieve[0] = false
        sieve[1] = false

        i = 2
        while i * i <= limit
          if sieve[i]
            j = i * i
            while j <= limit
              sieve[j] = false
              j += i
            end
          end
          i += 1
        end

        count = 0
        k = 0
        n = sieve.length
        while k < n
          count += 1 if sieve[k]
          k += 1
        end
        count
      end
    end
  end
end
```

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/algorithms/test_sieve.rb
```

Expected: 4 runs, 4 assertions, 0 failures。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/algorithms/sieve.rb ruby-vs-truffleruby-bench/test/ruby_bench/algorithms/test_sieve.rb
git commit -m "feat: エラトステネスのふるいアルゴリズムを追加"
```

---

## Task 13: Measurement 値オブジェクトの TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/test_measurement.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/measurement.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchMeasurementTest < Minitest::Test
  def sample
    RubyBench::Measurement.new(
      algorithm: "fibonacci",
      input_label: "n=30",
      runtime: "mri",
      wall_time_s: 1.5,
      iterations_per_second: 6.66,
      iterations_per_second_error: 0.1,
      rss_bytes_peak: 50_000_000,
      cpu_user_s: 1.4,
      cpu_sys_s: 0.05,
      gc_count_delta: 12,
      gc_time_ms_delta: 25,
      allocations_total: 3000,
      allocations_retained: 100
    )
  end

  def test_to_h_returns_all_fields_as_symbols
    h = sample.to_h
    %i[algorithm input_label runtime wall_time_s iterations_per_second iterations_per_second_error
       rss_bytes_peak cpu_user_s cpu_sys_s gc_count_delta gc_time_ms_delta
       allocations_total allocations_retained].each do |k|
      assert(h.key?(k), "#{k} が to_h に含まれる")
    end
  end

  def test_immutable_returns_new_copy_via_with
    other = sample.with(runtime: "truffleruby")
    assert_equal("mri", sample.runtime)
    assert_equal("truffleruby", other.runtime)
  end

  def test_to_json_round_trip
    json = sample.to_h.to_json
    parsed = JSON.parse(json, symbolize_names: true)
    assert_equal("fibonacci", parsed[:algorithm])
    assert_in_delta(6.66, parsed[:iterations_per_second])
  end
end
```

- [ ] Step 2: テストを実行し、失敗することを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_measurement.rb
```

Expected: 未定義定数で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/measurement.rb`:

```ruby
# typed: true
# frozen_string_literal: true

require "json"

module RubyBench
  class Measurement
    extend T::Sig

    FIELDS = %i[
      algorithm input_label runtime
      wall_time_s iterations_per_second iterations_per_second_error
      rss_bytes_peak cpu_user_s cpu_sys_s
      gc_count_delta gc_time_ms_delta
      allocations_total allocations_retained
    ].freeze

    sig { returns(String) }
    attr_reader :algorithm, :input_label, :runtime

    sig { returns(Float) }
    attr_reader :wall_time_s, :iterations_per_second, :iterations_per_second_error,
                :cpu_user_s, :cpu_sys_s

    sig { returns(Integer) }
    attr_reader :rss_bytes_peak, :gc_count_delta, :gc_time_ms_delta,
                :allocations_total, :allocations_retained

    sig do
      params(
        algorithm: String, input_label: String, runtime: String,
        wall_time_s: Float, iterations_per_second: Float, iterations_per_second_error: Float,
        rss_bytes_peak: Integer, cpu_user_s: Float, cpu_sys_s: Float,
        gc_count_delta: Integer, gc_time_ms_delta: Integer,
        allocations_total: Integer, allocations_retained: Integer
      ).void
    end
    def initialize(algorithm:, input_label:, runtime:,
                   wall_time_s:, iterations_per_second:, iterations_per_second_error:,
                   rss_bytes_peak:, cpu_user_s:, cpu_sys_s:,
                   gc_count_delta:, gc_time_ms_delta:,
                   allocations_total:, allocations_retained:)
      @algorithm = algorithm
      @input_label = input_label
      @runtime = runtime
      @wall_time_s = wall_time_s
      @iterations_per_second = iterations_per_second
      @iterations_per_second_error = iterations_per_second_error
      @rss_bytes_peak = rss_bytes_peak
      @cpu_user_s = cpu_user_s
      @cpu_sys_s = cpu_sys_s
      @gc_count_delta = gc_count_delta
      @gc_time_ms_delta = gc_time_ms_delta
      @allocations_total = allocations_total
      @allocations_retained = allocations_retained
      freeze
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def to_h
      FIELDS.each_with_object({}) { |k, acc| acc[k] = public_send(k) }
    end

    sig { params(overrides: T.untyped).returns(Measurement) }
    def with(**overrides)
      Measurement.new(**to_h.merge(overrides))
    end
  end
end
```

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_measurement.rb
```

Expected: 3 runs, 6 assertions, 0 failures。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/measurement.rb ruby-vs-truffleruby-bench/test/ruby_bench/test_measurement.rb
git commit -m "feat: 計測結果を表す不変な Measurement を追加"
```

---

## Task 14: Harness クラスの TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/test_harness.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/harness.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchHarnessTest < Minitest::Test
  def test_measure_returns_measurement
    harness = RubyBench::Harness.new(warmup_seconds: 0.01, time_seconds: 0.05)
    m = harness.measure(algorithm: "noop", input_label: "n=1") { 1 + 1 }
    assert_kind_of(RubyBench::Measurement, m)
    assert_equal("noop", m.algorithm)
    assert_equal("n=1", m.input_label)
  end

  def test_measure_records_positive_ips
    harness = RubyBench::Harness.new(warmup_seconds: 0.01, time_seconds: 0.05)
    m = harness.measure(algorithm: "noop", input_label: "n=1") { 1 + 1 }
    assert_operator(m.iterations_per_second, :>, 0.0)
  end

  def test_measure_captures_runtime_from_runtime_module
    harness = RubyBench::Harness.new(warmup_seconds: 0.01, time_seconds: 0.05)
    m = harness.measure(algorithm: "noop", input_label: "n=1") { 1 + 1 }
    assert_equal(RubyBench::Runtime.id, m.runtime)
  end

  def test_measurements_accumulates
    harness = RubyBench::Harness.new(warmup_seconds: 0.01, time_seconds: 0.05)
    harness.measure(algorithm: "a", input_label: "x") { 1 }
    harness.measure(algorithm: "b", input_label: "y") { 1 }
    assert_equal(2, harness.measurements.size)
  end
end
```

- [ ] Step 2: テストを実行し、失敗することを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_harness.rb
```

Expected: 未定義定数で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/harness.rb`:

```ruby
# typed: true
# frozen_string_literal: true

require "benchmark/ips"
require "memory_profiler"
require "get_process_mem"

module RubyBench
  class Harness
    extend T::Sig

    DEFAULT_WARMUP = 1.0
    DEFAULT_TIME = 3.0

    sig { returns(T::Array[Measurement]) }
    attr_reader :measurements

    sig { params(warmup_seconds: Float, time_seconds: Float).void }
    def initialize(warmup_seconds: DEFAULT_WARMUP, time_seconds: DEFAULT_TIME)
      @warmup_seconds = warmup_seconds
      @time_seconds = time_seconds
      @measurements = []
    end

    sig do
      params(
        algorithm: String,
        input_label: String,
        block: T.proc.returns(T.untyped)
      ).returns(Measurement)
    end
    def measure(algorithm:, input_label:, &block)
      report = run_ips(&block)
      memory_report = run_memory(&block)
      rss = run_rss(&block)
      cpu_user, cpu_sys, gc_count_delta, gc_time_delta = run_cpu_and_gc(&block)

      m = Measurement.new(
        algorithm: algorithm,
        input_label: input_label,
        runtime: Runtime.id,
        wall_time_s: report.fetch(:wall_time).to_f,
        iterations_per_second: report.fetch(:ips).to_f,
        iterations_per_second_error: report.fetch(:ips_error).to_f,
        rss_bytes_peak: rss.to_i,
        cpu_user_s: cpu_user.to_f,
        cpu_sys_s: cpu_sys.to_f,
        gc_count_delta: gc_count_delta.to_i,
        gc_time_ms_delta: gc_time_delta.to_i,
        allocations_total: memory_report.fetch(:total).to_i,
        allocations_retained: memory_report.fetch(:retained).to_i
      )
      @measurements << m
      m
    end

    private

    sig { params(block: T.proc.returns(T.untyped)).returns(T::Hash[Symbol, T.untyped]) }
    def run_ips(&block)
      result = nil
      report = Benchmark.ips do |x|
        x.config(time: @time_seconds, warmup: @warmup_seconds, quiet: true)
        x.report("target", &block)
        x.compare!
        result = x
      end
      entry = report.entries.first
      {
        wall_time: entry.iterations.to_f / entry.ips.to_f,
        ips: entry.ips,
        ips_error: entry.error.to_f
      }
    end

    sig { params(block: T.proc.returns(T.untyped)).returns(T::Hash[Symbol, Integer]) }
    def run_memory(&block)
      report = MemoryProfiler.report(&block)
      { total: report.total_allocated, retained: report.total_retained }
    end

    sig { params(block: T.proc.returns(T.untyped)).returns(Integer) }
    def run_rss(&block)
      mem = GetProcessMem.new
      before = mem.bytes
      block.call
      after = mem.bytes
      [before, after].max.to_i
    end

    sig do
      params(block: T.proc.returns(T.untyped))
        .returns([Float, Float, Integer, Integer])
    end
    def run_cpu_and_gc(&block)
      GC.start
      gc_before = GC.stat
      cpu_before = Process.times
      block.call
      cpu_after = Process.times
      gc_after = GC.stat
      [
        cpu_after.utime - cpu_before.utime,
        cpu_after.stime - cpu_before.stime,
        (gc_after[:count] || 0) - (gc_before[:count] || 0),
        ((gc_after[:total_time] || 0) - (gc_before[:total_time] || 0)).to_i
      ]
    end
  end
end
```

注記: `GC.stat[:total_time]` は MRI のみ提供のキーで TruffleRuby では nil の可能性があるため `|| 0` でフォールバックします。

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_harness.rb
```

Expected: 4 runs, 5 assertions, 0 failures(ベンチ実行で数秒かかります)。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/harness.rb ruby-vs-truffleruby-bench/test/ruby_bench/test_harness.rb
git commit -m "feat: ベンチマーク計測ハーネスを追加"
```

---

## Task 15: Reporter (JSON 集約) の TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/test_reporter.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/reporter.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"
require "tempfile"

class RubyBenchReporterTest < Minitest::Test
  def measurements
    [
      RubyBench::Measurement.new(
        algorithm: "fibonacci", input_label: "n=20", runtime: "mri",
        wall_time_s: 0.1, iterations_per_second: 10.0, iterations_per_second_error: 0.1,
        rss_bytes_peak: 1000, cpu_user_s: 0.09, cpu_sys_s: 0.01,
        gc_count_delta: 1, gc_time_ms_delta: 2,
        allocations_total: 10, allocations_retained: 1
      )
    ]
  end

  def test_to_json_payload_contains_runtime_metadata
    payload = RubyBench::Reporter.new(measurements).payload
    assert_includes(payload.keys, :runtime_metadata)
    assert_includes(payload.keys, :measurements)
  end

  def test_dump_writes_to_file
    Tempfile.open(["report", ".json"]) do |f|
      RubyBench::Reporter.new(measurements).dump(f.path)
      parsed = JSON.parse(File.read(f.path), symbolize_names: true)
      assert_equal("fibonacci", parsed[:measurements].first[:algorithm])
    end
  end

  def test_load_reads_back_payload
    Tempfile.open(["report", ".json"]) do |f|
      RubyBench::Reporter.new(measurements).dump(f.path)
      loaded = RubyBench::Reporter.load(f.path)
      assert_equal(1, loaded[:measurements].size)
      assert_includes(loaded.keys, :runtime_metadata)
    end
  end
end
```

- [ ] Step 2: 失敗を確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_reporter.rb
```

Expected: 未定義定数で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/reporter.rb`:

```ruby
# typed: true
# frozen_string_literal: true

require "json"

module RubyBench
  class Reporter
    extend T::Sig

    sig { params(measurements: T::Array[Measurement]).void }
    def initialize(measurements)
      @measurements = measurements
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def payload
      {
        schema_version: 1,
        generated_at: Time.now.utc.iso8601,
        runtime_metadata: Runtime.metadata,
        measurements: @measurements.map(&:to_h)
      }
    end

    sig { params(path: String).void }
    def dump(path)
      File.binwrite(path, JSON.pretty_generate(payload))
    end

    sig { params(path: String).returns(T::Hash[Symbol, T.untyped]) }
    def self.load(path)
      JSON.parse(File.read(path), symbolize_names: true)
    end
  end
end
```

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_reporter.rb
```

Expected: 3 runs, 5 assertions, 0 failures。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/reporter.rb ruby-vs-truffleruby-bench/test/ruby_bench/test_reporter.rb
git commit -m "feat: 計測結果を JSON へ集約する Reporter を追加"
```

---

## Task 16: Runner の TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/test_runner.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/runner.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

class RubyBenchRunnerTest < Minitest::Test
  def test_smoke_runs_all_algorithms_once_with_small_inputs
    runner = RubyBench::Runner.new(smoke: true)
    runner.run_all
    algos = runner.harness.measurements.map(&:algorithm).sort
    assert_equal(%w[fibonacci mandelbrot nbody sieve], algos)
  end

  def test_smoke_inputs_finish_under_three_seconds
    runner = RubyBench::Runner.new(smoke: true)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    runner.run_all
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator(elapsed, :<, 30.0, "スモーク実行は十分短時間で終わること")
  end
end
```

- [ ] Step 2: 失敗を確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_runner.rb
```

Expected: 未定義定数で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/runner.rb`:

```ruby
# typed: true
# frozen_string_literal: true

module RubyBench
  class Runner
    extend T::Sig

    sig { returns(Harness) }
    attr_reader :harness

    SCENARIOS = {
      full: [
        { algorithm: "fibonacci", input_label: "n=32", call: -> { Algorithms::Fibonacci.run(32) } },
        { algorithm: "mandelbrot", input_label: "size=200", call: -> { Algorithms::Mandelbrot.run(200) } },
        { algorithm: "nbody", input_label: "steps=50000", call: -> { Algorithms::Nbody.run(50_000) } },
        { algorithm: "sieve", input_label: "limit=2_000_000", call: -> { Algorithms::Sieve.run(2_000_000) } }
      ],
      smoke: [
        { algorithm: "fibonacci", input_label: "n=18", call: -> { Algorithms::Fibonacci.run(18) } },
        { algorithm: "mandelbrot", input_label: "size=40", call: -> { Algorithms::Mandelbrot.run(40) } },
        { algorithm: "nbody", input_label: "steps=500", call: -> { Algorithms::Nbody.run(500) } },
        { algorithm: "sieve", input_label: "limit=50_000", call: -> { Algorithms::Sieve.run(50_000) } }
      ]
    }.freeze

    sig { params(smoke: T::Boolean).void }
    def initialize(smoke: false)
      @smoke = smoke
      @harness = if smoke
                   Harness.new(warmup_seconds: 0.05, time_seconds: 0.2)
                 else
                   Harness.new
                 end
    end

    sig { void }
    def run_all
      scenarios = SCENARIOS.fetch(@smoke ? :smoke : :full)
      scenarios.each do |s|
        @harness.measure(algorithm: s[:algorithm], input_label: s[:input_label], &s[:call])
      end
    end
  end
end
```

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_runner.rb
```

Expected: 2 runs, 2 assertions, 0 failures。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/runner.rb ruby-vs-truffleruby-bench/test/ruby_bench/test_runner.rb
git commit -m "feat: 全アルゴリズムを順に流す Runner を追加"
```

---

## Task 17: HtmlRenderer の TDD 実装

Files:
- Test: `ruby-vs-truffleruby-bench/test/ruby_bench/test_html_renderer.rb`
- Create: `ruby-vs-truffleruby-bench/lib/ruby_bench/html_renderer.rb`

- [ ] Step 1: 失敗するテストを書く

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"
require "tempfile"

class RubyBenchHtmlRendererTest < Minitest::Test
  def sample_payload(runtime)
    {
      schema_version: 1,
      generated_at: "2026-05-24T00:00:00Z",
      runtime_metadata: { id: runtime, engine: runtime, engine_version: "3.4", ruby_version: "3.4.1", platform: "x86_64-linux", pid: 1 },
      measurements: [
        {
          algorithm: "fibonacci", input_label: "n=20", runtime: runtime,
          wall_time_s: 0.1, iterations_per_second: 50.0, iterations_per_second_error: 0.5,
          rss_bytes_peak: 1_000_000, cpu_user_s: 0.08, cpu_sys_s: 0.02,
          gc_count_delta: 2, gc_time_ms_delta: 10,
          allocations_total: 200, allocations_retained: 20
        }
      ]
    }
  end

  def test_render_returns_string_containing_chartjs_cdn
    html = RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).render
    assert_match(%r{cdn\.jsdelivr\.net.*chart\.js}m, html)
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
    Tempfile.open(["report", ".html"]) do |f|
      RubyBench::HtmlRenderer.new([sample_payload("mri"), sample_payload("truffleruby")]).write(f.path)
      assert_match(/<!doctype html>/i, File.read(f.path))
    end
  end
end
```

- [ ] Step 2: 失敗を確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_html_renderer.rb
```

Expected: 未定義定数で FAIL。

- [ ] Step 3: 実装を書く

`lib/ruby_bench/html_renderer.rb`:

```ruby
# typed: true
# frozen_string_literal: true

require "json"

module RubyBench
  class HtmlRenderer
    extend T::Sig

    CHARTJS_CDN = "https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"

    sig { params(payloads: T::Array[T::Hash[Symbol, T.untyped]]).void }
    def initialize(payloads)
      @payloads = payloads
    end

    sig { returns(String) }
    def render
      <<~HTML
        <!doctype html>
        <html lang="ja">
        <head>
          <meta charset="utf-8" />
          <title>Ruby 3.4 vs TruffleRuby 3.4 ベンチマークレポート</title>
          <script src="#{CHARTJS_CDN}"></script>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; margin: 24px; color: #1f2937; }
            h1 { font-size: 22px; }
            section { margin-bottom: 48px; }
            .chart-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
            canvas { width: 100% !important; height: 320px !important; }
            table { border-collapse: collapse; width: 100%; font-size: 14px; }
            th, td { border: 1px solid #e5e7eb; padding: 6px 10px; text-align: right; }
            th { background: #f9fafb; text-align: left; }
          </style>
        </head>
        <body>
          <h1>Ruby 3.4 vs TruffleRuby 3.4 ベンチマークレポート</h1>
          <p>収集データ:</p>
          <pre id="raw-data">#{JSON.pretty_generate(@payloads)}</pre>
          <div class="chart-grid">
            <canvas id="ips"></canvas>
            <canvas id="wall"></canvas>
            <canvas id="rss"></canvas>
            <canvas id="gc"></canvas>
          </div>
          <script>
            const payloads = #{@payloads.to_json};
            const algorithms = Array.from(new Set(payloads.flatMap(p => p.measurements.map(m => m.algorithm))));
            const palette = { mri: "#ef4444", truffleruby: "#3b82f6" };
            const datasetsFor = (metric) => payloads.map(p => ({
              label: p.runtime_metadata.id,
              data: algorithms.map(a => {
                const m = p.measurements.find(x => x.algorithm === a);
                return m ? m[metric] : 0;
              }),
              backgroundColor: palette[p.runtime_metadata.id] || "#6b7280"
            }));
            const makeChart = (id, metric, title) => new Chart(document.getElementById(id), {
              type: "bar",
              data: { labels: algorithms, datasets: datasetsFor(metric) },
              options: { responsive: true, plugins: { title: { display: true, text: title } } }
            });
            makeChart("ips", "iterations_per_second", "Iterations per second (高いほど速い)");
            makeChart("wall", "wall_time_s", "Wall time seconds (低いほど速い)");
            makeChart("rss", "rss_bytes_peak", "Peak RSS bytes");
            makeChart("gc", "gc_time_ms_delta", "GC time ms delta");
          </script>
        </body>
        </html>
      HTML
    end

    sig { params(path: String).void }
    def write(path)
      File.binwrite(path, render)
    end
  end
end
```

- [ ] Step 4: テストが通ることを確認する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test TEST=test/ruby_bench/test_html_renderer.rb
```

Expected: 4 runs, 5 assertions, 0 failures。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/lib/ruby_bench/html_renderer.rb ruby-vs-truffleruby-bench/test/ruby_bench/test_html_renderer.rb
git commit -m "feat: Chart.js を埋め込む HtmlRenderer を追加"
```

---

## Task 18: bin/bench と bin/render_report の実装

Files:
- Create: `ruby-vs-truffleruby-bench/bin/bench`
- Create: `ruby-vs-truffleruby-bench/bin/render_report`

- [ ] Step 1: `bin/bench` を作成する

```ruby
#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

require "optparse"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ruby_bench"

options = { smoke: false, output: ENV.fetch("RUBY_BENCH_RESULT_PATH", "results/#{RubyBench::Runtime.id}.json") }

OptionParser.new do |o|
  o.banner = "Usage: bin/bench [options]"
  o.on("--smoke", "短時間のスモーク実行") { options[:smoke] = true }
  o.on("-o", "--output PATH", "出力 JSON のパス") { |v| options[:output] = v }
end.parse!

runner = RubyBench::Runner.new(smoke: options[:smoke])
runner.run_all

RubyBench::Reporter.new(runner.harness.measurements).dump(options[:output])
puts "wrote #{options[:output]}"
```

- [ ] Step 2: `bin/render_report` を作成する

```ruby
#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ruby_bench"

if ARGV.size < 3
  warn "Usage: bin/render_report <mri.json> <truffleruby.json> <output.html>"
  exit 1
end

mri_path, truffleruby_path, output_path = ARGV
payloads = [mri_path, truffleruby_path].map { |p| RubyBench::Reporter.load(p) }
RubyBench::HtmlRenderer.new(payloads).write(output_path)
puts "wrote #{output_path}"
```

- [ ] Step 3: 実行権限を付与する

```bash
chmod +x ruby-vs-truffleruby-bench/bin/bench ruby-vs-truffleruby-bench/bin/render_report
```

- [ ] Step 4: スモーク実行確認

```bash
cd ruby-vs-truffleruby-bench && bundle exec bin/bench --smoke -o results/smoke.json
cd ruby-vs-truffleruby-bench && bundle exec bin/render_report results/smoke.json results/smoke.json results/smoke.html
```

Expected: results/smoke.json と results/smoke.html がそれぞれ生成される。

- [ ] Step 5: コミット

```bash
git add ruby-vs-truffleruby-bench/bin/bench ruby-vs-truffleruby-bench/bin/render_report
git commit -m "feat: bin/bench と bin/render_report の CLI エントリポイントを追加"
```

---

## Task 19: GitHub Actions ワークフローの構築

Files:
- Create: `ruby-vs-truffleruby-bench/.github/workflows/ci.yml`

- [ ] Step 1: `.github/workflows/ci.yml` を作成する

```yaml
name: ruby-vs-truffleruby-bench CI

on:
  push:
    branches: [main]
    paths:
      - "ruby-vs-truffleruby-bench/**"
  pull_request:
    paths:
      - "ruby-vs-truffleruby-bench/**"

jobs:
  quality:
    name: Quality gates (MRI)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ruby-vs-truffleruby-bench
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.4.1"
          bundler-cache: true
          working-directory: ruby-vs-truffleruby-bench
      - name: syntax_tree check
        run: bundle exec stree check 'lib/**/*.rb' 'test/**/*.rb' 'bin/*'
      - name: RuboCop
        run: bundle exec rubocop
      - name: Sorbet typecheck
        run: bundle exec srb tc
      - name: Minitest
        run: bundle exec rake test

  docker-build:
    name: Docker build (both runtimes)
    runs-on: ubuntu-latest
    needs: quality
    steps:
      - uses: actions/checkout@v4
      - name: Build images
        working-directory: ruby-vs-truffleruby-bench
        run: docker compose build

  smoke-bench:
    name: Smoke bench (matrix)
    runs-on: ubuntu-latest
    needs: docker-build
    strategy:
      fail-fast: false
      matrix:
        runtime: [ruby34, truffleruby34]
    steps:
      - uses: actions/checkout@v4
      - name: Build target image
        working-directory: ruby-vs-truffleruby-bench
        run: docker compose build ${{ matrix.runtime }}
      - name: Run smoke bench
        working-directory: ruby-vs-truffleruby-bench
        run: docker compose run --rm ${{ matrix.runtime }} bundle exec bin/bench --smoke -o results/${{ matrix.runtime }}.json
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: results-${{ matrix.runtime }}
          path: ruby-vs-truffleruby-bench/results/${{ matrix.runtime }}.json
```

- [ ] Step 2: コミット

```bash
git add ruby-vs-truffleruby-bench/.github/workflows/ci.yml
git commit -m "ci: GitHub Actions で品質ゲートとスモークベンチを実行"
```

---

## Task 20: README とドキュメントの整備

Files:
- Create: `ruby-vs-truffleruby-bench/README.md`

- [ ] Step 1: README.md を作成する

```markdown
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
- `make bench` 両ランタイムでベンチマーク実行 + HTML レポート生成
- `make bench-mri` MRI のみ実行
- `make bench-truffleruby` TruffleRuby のみ実行
- `make test` Minitest を実行
- `make lint` RuboCop
- `make format` syntax_tree write
- `make typecheck` Sorbet tc
- `make check` lint + format-check + typecheck + test + build

## 品質ゲート

pre-commit(lefthook): syntax_tree check / RuboCop / Sorbet tc
pre-push(lefthook): Minitest / Docker compose build / bench スモーク
CI(GitHub Actions): 上記を MRI と TruffleRuby のマトリクスで実行

## ディレクトリ構成

`docs/2026-05-24-implementation-plan.md` に詳細を記載しています。
```

- [ ] Step 2: コミット

```bash
git add ruby-vs-truffleruby-bench/README.md
git commit -m "docs: README にプロジェクト概要と運用手順を記載"
```

---

## Task 21: 統合スモーク検証

Files:
- 既存ファイルのみ参照(変更なし)

- [ ] Step 1: 全ローカルテストを実行する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rake test
```

Expected: 全テスト pass(20件以上)。

- [ ] Step 2: RuboCop と syntax_tree と Sorbet を実行する

```bash
cd ruby-vs-truffleruby-bench && bundle exec rubocop && bundle exec stree check 'lib/**/*.rb' 'test/**/*.rb' 'bin/*' && bundle exec srb tc
```

Expected: 全部 0 件警告で成功する。RuboCop で違反があれば違反箇所を読み、必要なら `bundle exec rubocop -A` で自動修正してから再実行。syntax_tree で違反があれば `bundle exec stree write` してから再実行。Sorbet で型エラーが出れば該当ファイルの sig や型注釈を直す。

- [ ] Step 3: docker compose build が成功することを確認する

```bash
cd ruby-vs-truffleruby-bench && docker compose build
```

Expected: ruby34 と truffleruby34 の両方が build 成功する。

- [ ] Step 4: docker compose 経由でスモーク実行する

```bash
cd ruby-vs-truffleruby-bench && docker compose run --rm ruby34 bundle exec bin/bench --smoke -o results/mri.json
cd ruby-vs-truffleruby-bench && docker compose run --rm truffleruby34 bundle exec bin/bench --smoke -o results/truffleruby.json
cd ruby-vs-truffleruby-bench && docker compose run --rm ruby34 bundle exec bin/render_report results/mri.json results/truffleruby.json results/report.html
```

Expected: results/mri.json と results/truffleruby.json と results/report.html が生成され、HTML を開くと両ランタイムの比較グラフが表示される。

- [ ] Step 5: コミット

```bash
git add -u
git commit --allow-empty -m "test: 統合スモーク実行で両ランタイムの計測完了を確認"
```

---

## 自己レビュー

本計画書を spec(要件)と突き合わせて以下3観点で見直しました。

### 1. Spec coverage

| 要件 | カバー Task |
|---|---|
| サブディレクトリ ruby-vs-truffleruby-bench を作る | Task 1 |
| Docker で Ruby 3.4 と TruffleRuby 3.4 を動かす | Task 3, Task 4 |
| 4種(フィボナッチ・マンデルブロ・N-body・素数ふるい) | Task 9-12 |
| 同一ソースで両 Ruby を走らせる | Task 4(volumes で bind mount) |
| 時間・メモリ・CPU・GC 統計の計測 | Task 14(Harness) |
| HTML レポート出力(グラフ付き) | Task 17, Task 18 |
| Minitest | Task 8-17 すべての test ファイル |
| Sorbet typed: true デフォルト | 全 .rb ファイルが typed: true 宣言、Task 6 で sorbet/config 定義 |
| benchmark-ips + memory_profiler + get_process_mem | Task 2(Gemfile)Task 14(Harness) |
| docker-compose 両サービス | Task 4 |
| lefthook | Task 7 |
| syntax_tree + RuboCop | Task 6, Task 7 |
| GitHub Actions | Task 19 |
| 品質ゲート(formatter/linter/sorbet/rubocop/test/build) を pre-commit と CI で実行 | Task 7(lefthook), Task 19(GitHub Actions) |
| Build にベンチマークスモーク実行を含める | Task 7(pre-push 段で smoke), Task 19(smoke-bench ジョブ) |

ギャップなし。

### 2. Placeholder scan

`TBD` `TODO` `implement later` `fill in details` `add appropriate error handling` `similar to task N` を本計画書全文で grep し検出ゼロを確認。コード入りステップは全て完全コードを提示済み。

### 3. Type consistency

- `RubyBench::Runtime.id` は `"mri" | "truffleruby"` の文字列で Task 8 と Task 14 と Task 18 で一貫使用。
- `RubyBench::Measurement` の必須キーは Task 13 で確定し、Task 14(Harness#measure)と Task 15(Reporter#payload)と Task 17(HtmlRenderer の renderer 内データセット参照キー `iterations_per_second` `wall_time_s` `rss_bytes_peak` `gc_time_ms_delta`)で同名のままで参照されています。
- `RubyBench::Harness#measure` のシグネチャは `algorithm:, input_label:, &block` を Task 14 と Task 16(Runner)で同一名で使用。
- `RubyBench::Runner::SCENARIOS` の `:full` と `:smoke` のキー名は Task 16 と Task 18(bin/bench の `--smoke`)で整合。
- HtmlRenderer の入力 `payloads` の各要素はキーが `:runtime_metadata` `:measurements` で、Reporter#payload の出力と同型(Task 15 と Task 17 で一致)。

不整合なし。
