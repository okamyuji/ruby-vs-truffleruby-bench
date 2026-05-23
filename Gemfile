# frozen_string_literal: true

source "https://rubygems.org"

# TruffleRuby 24.1.x は Ruby 3.2.4 互換のため、両ランタイムを跨ぐ最小要件としてここでは >= 3.2.0 を指定します。
# CI / Docker 側で MRI 3.4 と TruffleRuby 24.1 を明示固定し、TruffleRuby 25 以降に上げる際は本制約も >= 3.4.0 に揃えます。
ruby ">= 3.2.0"

# Benchmark stack
gem "benchmark-ips", "~> 2.15"
gem "get_process_mem", "~> 1.0"
gem "memory_profiler", "~> 1.1"

# Test
gem "minitest", "~> 5.25"
gem "minitest-reporters", "~> 1.7"
gem "rake", "~> 13.2"

# Type runtime (always loaded but checks disabled at runtime for perf)
gem "sorbet-runtime", "~> 0.5"

# Development tools (skipped on TruffleRuby container via bundle config without 'development')
group :development do
  gem "rubocop", "~> 1.68"
  gem "rubocop-minitest", "~> 0.36"
  gem "rubocop-performance", "~> 1.22"
  gem "sorbet", "~> 0.5"
  gem "syntax_tree", "~> 6.2"
  gem "tapioca", "~> 0.16"
end
