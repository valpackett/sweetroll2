.PHONY: clean

all: priv/static/icons.svg.gz priv/static/icons.svg.br

clean:
	rm priv/static/*.gz priv/static/*.br

priv/static/icons.svg: priv/static/icons/*.svg
	npx svgstore-cli -o priv/static/icons.svg $?

priv/static/%.gz: priv/static/%
	gzip --keep --best $?

priv/static/%.br: priv/static/%
	brotli --keep --best $?
