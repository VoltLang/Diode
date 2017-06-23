// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to format vdoc object doccomments in full.
module diode.vdoc.full;

import watt.text.sink : Sink, StringSink;
import watt.text.format : format;
import watt.text.markdown : filterMarkdown;

import ir = diode.ir;

import diode.interfaces : Driver;
import diode.vdoc : VdocRoot, Named;
import diode.vdoc.filter : DocCommentValue;


//! Handles formating of DocComments into HTML.
class DocCommentFull : DocCommentValue
{
public:
	this(d: Driver, root: VdocRoot, named: Named)
	{
		super(d, root, named);
	}

	override fn toText(n: ir.Node, sink: Sink)
	{
		s: StringSink;
		if (!safeParse(s.sink)) {
			return;
		}

		md := s.toString();
		if (md.length <= 0) {
			return;
		}

		filterMarkdown(sink, md);
	}

	override fn content(d: string, sink: Sink)
	{
		sink(d);
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
