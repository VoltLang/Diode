// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to format vdoc object doccomments in full.
module diode.vdoc.full;

import watt.text.sink : StringSink;
import watt.text.vdoc;
import watt.text.string;
import watt.text.format;

import diode.errors;
import diode.eval;
import diode.vdoc;
import diode.interfaces;
import diode.vdoc.parser;


//! Handles formating of DocComments into HTML.
class DocCommentFull : Value, DocSink
{
public:
	drv: Driver;
	root: VdocRoot;
	named: Named;


public:
	this(d: Driver, root: VdocRoot, named: Named)
	{
		this.drv = d;
		this.root = root;
		this.named = named;
	}

	override fn toText(n: ir.Node, sink: Sink)
	{
		if (named is null) {
			return;
		}

		// TODO use markdown instead.
		parse(named.raw, this, sink);
	}

	override fn briefStart(sink: Sink) { }
	override fn briefContent(d: string, sink: Sink) { }
	override fn briefEnd(sink: Sink) { }

	override fn paramStart(direction: string, arg: string, sink: Sink)
	{
		// TODO
	}

	override fn paramContent(d: string, sink: Sink)
	{
		// TODO
	}

	override fn paramEnd(sink: Sink)
	{
		// TODO
	}

	override fn start(sink: Sink)
	{
		// TODO?
	}

	override fn content(d: string, sink: Sink)
	{
		sink(d);
	}

	override fn end(sink: Sink)
	{
		// TODO?
	}

	override fn p(d: string, sink: Sink)
	{
		sink("<code class=\"highlighter-rouge\">");
		sink(d);
		sink("</code>");
	}

	override fn link(link: string, sink: Sink)
	{
		// TODO use find and what not.
		format(sink, `<a href="%s">%s</a>`, link, link);
	}
}
