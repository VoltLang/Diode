// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to format vdoc object doccomments in full.
module diode.vdoc.brief;

import watt.text.vdoc;
import watt.text.sink;

import diode.interfaces;
import diode.eval;
import diode.vdoc;
import diode.vdoc.full;


class DocCommentBrief : DocCommentFull
{
public:
	//! Are we collecting input.
	collecting: bool;
	hasCollected: bool;


public:
	this(d: Driver, root: VdocRoot, named: Named)
	{
		super(d, root, named);
	}

	fn getString(named: Named) string
	{
		hasCollected = false;
		this.named = named;
		s: StringSink;
		toText(null, s.sink);
		return s.toString();
	}

	override fn toText(n: ir.Node, sink: Sink)
	{
		// TODO use markdown instead.
		super.toText(n, sink);

		if (!hasCollected) {
			// TODO this can handled better.
			rawToBrief(named.raw, sink);
		}

		hasCollected = false;
	}

	override fn briefStart(sink: Sink)
	{
		collecting = true;
	}

	override fn briefEnd(sink: Sink)
	{
		collecting = false;
		hasCollected = true;
	}

	override fn briefContent(d: string, sink: Sink) { if (collecting) { sink(d); } }
	override fn p(d: string, sink: Sink) { if (collecting) { super.p(d, sink); } }
	override fn link(link: string, sink: Sink) { if (collecting) { super.link(link, sink); } }

	override fn paramStart(direction: string, arg: string, sink: Sink) { }
	override fn paramContent(d: string, sink: Sink) { }
	override fn paramEnd(sink: Sink) { }

	override fn start(sink: Sink) { }
	override fn content(d: string, sink: Sink) { }
	override fn end(sink: Sink) { }
}
