.PHONY: help build bench bench-mri bench-mri-yjit bench-truffleruby report image-sizes test lint format format-check typecheck check clean

DC := docker compose

help:
	@echo "Targets:"
	@echo "  build              docker compose build (all runtimes)"
	@echo "  bench              run bench on all runtimes and render HTML"
	@echo "  bench-mri          run bench on MRI Ruby 3.4 (interpreter) only"
	@echo "  bench-mri-yjit     run bench on MRI Ruby 3.4 +YJIT only"
	@echo "  bench-truffleruby  run bench on TruffleRuby 3.4 only"
	@echo "  report             render results/report.html from existing JSON"
	@echo "  image-sizes        write results/image_sizes.json from docker image inspect"
	@echo "  test               bundle exec rake test (MRI)"
	@echo "  lint               run RuboCop"
	@echo "  format             run syntax_tree write"
	@echo "  format-check       run syntax_tree check"
	@echo "  typecheck          run sorbet tc"
	@echo "  check              lint + format-check + typecheck + test + build"
	@echo "  clean              remove results/*.json results/*.html"

build:
	$(DC) build

bench-mri:
	$(DC) run --rm ruby34

bench-mri-yjit:
	$(DC) run --rm ruby34-yjit

bench-truffleruby:
	$(DC) run --rm truffleruby34

bench: bench-mri bench-mri-yjit bench-truffleruby image-sizes report

report:
	$(DC) run --rm ruby34 bundle exec bin/render_report results/mri.json results/mri-yjit.json results/truffleruby.json results/report.html

image-sizes:
	./bin/collect_image_sizes.sh results/image_sizes.json

test:
	bundle exec rake test

lint:
	bundle exec rubocop

format:
	bundle exec stree write 'lib/**/*.rb' 'test/**/*.rb' 'bin/*'

format-check:
	bundle exec stree check 'lib/**/*.rb' 'test/**/*.rb' 'bin/*'

typecheck:
	bundle exec srb tc

check: lint format-check typecheck test build

clean:
	rm -f results/*.json results/*.html
