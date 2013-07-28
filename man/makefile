# Makes man pages
# Note: requires http://www.methods.co.nz/asciidoc/

all: $(patsubst %.1.txt,%.1,$(wildcard *.1.txt))

%.1: %.1.txt
	a2x --doctype manpage --format manpage $<

clean:
	rm -f *.1
