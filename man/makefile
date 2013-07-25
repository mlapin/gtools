# Makes man pages
# Note: requires http://www.methods.co.nz/asciidoc/

all: $(patsubst %.1.txt,%.1,$(wildcard *.1.txt)) gt-command.1

%.1: %.1.txt
	a2x --doctype manpage --format manpage $<

gt-command.1: gt-cmd.1
	ln -fs $< $@

clean:
	rm -f *.1
