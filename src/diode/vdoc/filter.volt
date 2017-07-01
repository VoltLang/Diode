// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code handle vdoc filters.
module diode.vdoc.filter;

import watt.text.markdown;
import watt.text.vdoc;

import diode.errors;
import diode.eval;
import diode.vdoc;
import diode.interfaces;


fn handleDocCommentFilter(d: Driver, e: Engine, root: VdocRoot, v: Value, filter: string, type: string) Value
{
	isHtml: bool;
	isFull: bool;
	isBrief: bool;

	named := cast(Named)v;
	if (named is null) {
		e.handleError("filter argument must be vdoc named thing.");
		return null;
	}

	switch (filter) {
	case "vdoc_find_full", "vdoc_full": isFull = true; break;
	case "vdoc_find_brief", "vdoc_brief": isBrief = true; break;
	default:
		err := format("internal error filter '%s' not known", filter);
		e.handleError(err);
		return null;
	}

	switch (type) {
	case "html": isHtml = true; break;
	default:
		err := format("type '%s' not support for '%s'", type, filter);
		e.handleError(err);
		return null;
	}

	// No doccomment just return empty text.
	if (named.raw is null) {
		return new Text(null);
	}

	if (isFull) {
		return new FilterFull(named);
	} else if (isBrief) {
		return new FilterBrief(named);
	} else {
		e.handleError("internal error");
	}
}

//! Helper class for Filters.
abstract class FilterValue : Value
{
public:
	named: Named;


public:
	this(named: Named)
	{
		this.named = named;
	}
}

//! Filter for brief.
class FilterBrief : FilterValue
{
public:
	this(named: Named) { super(named); }

	override fn toText(n: ir.Node, sink: Sink)
	{
		if (named !is null) {
			sink(named.brief);
		}
	}
}

//! Filter for formating of full DocComments into HTML.
class FilterFull : FilterValue
{
public:
	this(named: Named) { super(named); }

	override fn toText(n: ir.Node, sink: Sink)
	{
		if (named !is null) {
			filterMarkdown(sink, named.mdFull);
		}
	}
}
