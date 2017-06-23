// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to format vdoc object doccomments in full.
module diode.vdoc.brief;

import watt.text.sink : Sink, StringSink;
import watt.text.string : strip, indexOf;

import ir = diode.ir;

import diode.interfaces : Driver;
import diode.vdoc : VdocRoot, Named;
import diode.vdoc.filter : DocCommentValue;


//! Generate a brief from doccomment.
class DocCommentBrief : DocCommentValue
{
public:
	//! Keep output from regular content incase there is no brief tag.
	autoBrief: StringSink;
	//! Are we in brief mode.
	isBrief: bool;
	//! Are we in auto mode.
	isAuto: bool;
	//! Has a brief been found.
	hasBrief: bool;


public:
	this(d: Driver, root: VdocRoot, named: Named)
	{
		super(d, root, named);
	}

	fn getString(named: Named) string
	{
		this.named = named;
		s: StringSink;
		toText(null, s.sink);
		return strip(s.toString());
	}

	override fn toText(n: ir.Node, sink: Sink)
	{
		autoBrief.reset();

		isAuto = true;
		isBrief = false;
		hasBrief = false;

		if (!safeParse(sink)) {
			return;
		}

		if (!hasBrief) {
			autoBrief.toSink(sink);
		}
	}

	override fn briefStart(sink: Sink)
	{
		isAuto = false;
		isBrief = true;
	}

	override fn briefEnd(sink: Sink)
	{
		isBrief = false;
		hasBrief = true;
	}

	override fn briefContent(d: string, sink: Sink)
	{
		if (isBrief) {
			sink(d);
		}
	}

	override fn p(d: string, sink: Sink)
	{
		if (isBrief) {
			sink(d);
		} else if (isAuto) {
			autoBrief.sink(d);
		}
	}

	override fn link(link: string, sink: Sink)
	{
		if (isBrief) {
			sink(link);
		} else if (isAuto) {
			autoBrief.sink(link);
		}
	}

	override fn content(d: string, sink: Sink)
	{
		if (!isAuto && d.length <= 0) {
			return;
		}

		index := d.indexOf(".");
		if (index < 0) {
			return autoBrief.sink(d);
		}

		autoBrief.sink(d[0 .. index + 1]);
		isAuto = false;
	}
}
