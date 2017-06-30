// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to format vdoc object doccomments in full.
module diode.vdoc.full;

import watt.text.vdoc : DocState;
import watt.text.sink : Sink, StringSink;
import watt.text.string : strip;
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

	override fn content(sink: Sink, state: DocState, d: string)
	{
		if (state != DocState.Content) {
			return;
		}

		sink(d);
	}

	override fn p(sink: Sink, state: DocState, d: string)
	{
		if (state != DocState.Content) {
			return;
		}

		sink("<code class=\"highlighter-rouge\">");
		sink(d);
		sink("</code>");
	}

	override fn link(sink: Sink, state: DocState, target: string, text: string)
	{
		if (state != DocState.Content) {
			return;
		}

		text = strip(text);
		url: string;

		n := root.findNamed(target);
		if (n !is null) {
			if (text is null) {
				text = n.name;
			}
			url = n.url;
		} else if (text is null) {
			text = target;
		}

		if (url !is null) {
			format(sink, `[%s](%s)`, text, url);
		} else {
			sink(text);
		}
	}
}
