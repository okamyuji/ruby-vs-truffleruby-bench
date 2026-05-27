# typed: true
# frozen_string_literal: true

module RubyBench
  class Runner
    extend T::Sig

    sig { returns(Harness) }
    attr_reader :harness

    sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
    attr_reader :warmup

    sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
    attr_reader :startup

    sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
    attr_reader :parallelism

    # WARMUP ウォームアップ曲線の計測対象。JIT 効果が大きく出る mandelbrot を代表に選ぶ。
    WARMUP = {
      full: {
        algorithm: "mandelbrot",
        input_label: "size=160",
        runs: 50,
        call: -> { Algorithms::Mandelbrot.run(160) }
      },
      smoke: {
        algorithm: "mandelbrot",
        input_label: "size=40",
        runs: 8,
        call: -> { Algorithms::Mandelbrot.run(40) }
      }
    }.freeze

    # STARTUP_RUNS 起動計測のサブプロセス起動回数 (最小/中央値を取るため複数回)。
    STARTUP_RUNS = { full: 7, smoke: 3 }.freeze

    # PARALLELISM 並列スケーリング計測の設定 (総仕事量とスレッド数の段階)。
    PARALLELISM = {
      full: {
        total: 20_000_000,
        thread_counts: [1, 2, 4, 8],
        warmup: 4,
        repeats: 3
      },
      smoke: {
        total: 500_000,
        thread_counts: [1, 2],
        warmup: 1,
        repeats: 1
      }
    }.freeze

    SCENARIOS = {
      full: [
        { algorithm: "fibonacci", input_label: "n=32", call: -> { Algorithms::Fibonacci.run(32) } },
        { algorithm: "mandelbrot", input_label: "size=200", call: -> { Algorithms::Mandelbrot.run(200) } },
        { algorithm: "nbody", input_label: "steps=50000", call: -> { Algorithms::Nbody.run(50_000) } },
        { algorithm: "sieve", input_label: "limit=2_000_000", call: -> { Algorithms::Sieve.run(2_000_000) } },
        { algorithm: "json", input_label: "records=2000", call: -> { Algorithms::JsonRoundtrip.run(2_000) } },
        { algorithm: "regexp", input_label: "lines=20000", call: -> { Algorithms::RegexpScan.run(20_000) } }
      ],
      smoke: [
        { algorithm: "fibonacci", input_label: "n=18", call: -> { Algorithms::Fibonacci.run(18) } },
        { algorithm: "mandelbrot", input_label: "size=40", call: -> { Algorithms::Mandelbrot.run(40) } },
        { algorithm: "nbody", input_label: "steps=500", call: -> { Algorithms::Nbody.run(500) } },
        { algorithm: "sieve", input_label: "limit=50_000", call: -> { Algorithms::Sieve.run(50_000) } },
        { algorithm: "json", input_label: "records=50", call: -> { Algorithms::JsonRoundtrip.run(50) } },
        { algorithm: "regexp", input_label: "lines=200", call: -> { Algorithms::RegexpScan.run(200) } }
      ]
    }.freeze

    sig { params(smoke: T::Boolean).void }
    def initialize(smoke: false)
      @smoke = smoke
      @harness = (smoke ? Harness.new(warmup_seconds: 0.05, time_seconds: 0.2) : Harness.new)
    end

    sig { returns(Symbol) }
    def mode
      @smoke ? :smoke : :full
    end

    sig { void }
    def run_all
      scenarios = SCENARIOS.fetch(mode)
      scenarios.each { |s| @harness.measure(algorithm: s[:algorithm], input_label: s[:input_label], &s[:call]) }
    end

    # run_warmup 代表アルゴリズムの連続実行で温まり方の曲線を取る。JIT が温まる前に実行する。
    sig { void }
    def run_warmup
      cfg = WARMUP.fetch(mode)
      samples = Warmup.measure(runs: cfg[:runs], &cfg[:call])
      @warmup = { algorithm: cfg[:algorithm], input_label: cfg[:input_label], wall_ms: samples }
    end

    # run_startup サブプロセス起動でコールドスタート相当の起動時間を計測する。
    sig { void }
    def run_startup
      @startup = { scenarios: Startup.measure(runs: STARTUP_RUNS.fetch(mode)) }
    end

    # run_parallelism CPU バウンド処理の強スケーリングを計測する。GVL の有無で差が出る。
    sig { void }
    def run_parallelism
      cfg = PARALLELISM.fetch(mode)
      @parallelism =
        Parallelism.measure(total: cfg[:total], thread_counts: cfg[:thread_counts], warmup: cfg[:warmup], repeats: cfg[:repeats])
    end
  end
end
