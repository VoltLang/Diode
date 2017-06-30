// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to format vdoc object doccomments in full.
module diode.vdoc.full;

import watt.text.vdoc : DocState;
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

	override fn content(state: DocState, d: string, sink: Sink)
	{
		if (state != DocState.Content) {
			return;
		}

		sink(d);
	}

	override fn p(state: DocState, d: string, sink: Sink)
	{
		if (state != DocState.Content) {
			return;
		}

		sink("<code class=\"highlighter-rouge\">");
		sink(d);
		sink("</code>");
	}

	override fn link(state: DocState, link: string, sink: Sink)
	{
		if (state != DocState.Content) {
			return;
		}

		// TODO use find and what not.
		format(sink, `<a href="%s">%s</a>`, link, link);
	}
}
