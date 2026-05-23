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
      @harness = (smoke ? Harness.new(warmup_seconds: 0.05, time_seconds: 0.2) : Harness.new)
    end

    sig { void }
    def run_all
      scenarios = SCENARIOS.fetch(@smoke ? :smoke : :full)
      scenarios.each { |s| @harness.measure(algorithm: s[:algorithm], input_label: s[:input_label], &s[:call]) }
    end
  end
end
