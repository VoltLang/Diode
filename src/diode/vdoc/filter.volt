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
	isMd: bool;
	isHtml: bool;
	isFull: bool;
	isBrief: bool;
	isContent: bool;

	named := cast(Named)v;
	if (named is null) {
		e.handleError("filter argument must be vdoc named thing.");
		return null;
	}

	switch (filter) {
	case "vdoc_find_full", "vdoc_full": isFull = true; break;
	case "vdoc_find_brief", "vdoc_brief": isBrief = true; break;
	case "vdoc_find_content", "vdoc_content": isContent = true; break;
	default:
		err := format("internal error filter '%s' not known", filter);
		e.handleError(err);
		return null;
	}

	switch (type) {
	case "html": isHtml = true; break;
	case "md": isMd = true; break;
	default:
	}

	if (isFull && isMd ||
	    !isHtml && !isMd) {
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
	} else if (isContent) {
		return new FilterContent(named, isHtml);
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
	html: bool;
	named: Named;


public:
	this(named: Named, html: bool)
	{
		this.html = html;
		this.named = named;
	}
}

//! Filter for brief.
class FilterBrief : FilterValue
{
public:
	this(named: Named) { super(named, true); }

	override fn toText(n: ir.Node, sink: Sink)
	{
		if (named !is null) {
			sink(named.brief);
		}
	}
}

//! Filter for formating of content of DocComments into HTML.
class FilterContent : FilterValue
{
public:
	this(named: Named, html: bool) { super(named, html); }

	override fn toText(n: ir.Node, sink: Sink)
	{
		if (named is null) {
			return;
		}

		if (html) {
			filterMarkdown(sink, named.content);
		} else {
			sink(named.content);
		}
	}
}

//! Filter for formating of full DocComments into HTML.
class FilterFull : FilterValue
{
public:
	this(named: Named) { super(named, true); }

	override fn toText(n: ir.Node, sink: Sink)
	{
		if (named is null) {
			return;
		}

		filterMarkdown(sink, named.content);

		func := cast(Function)named;
		if (func is null) {
			return;
		}

		argHasDoc: bool;
		foreach (v; func.args) {
			arg := cast(Arg)v;
			if (arg.content !is null) {
				argHasDoc = true;
				break;
			}
		}

		// Post process params.
		if (argHasDoc) {
			sink("<h3>Parameters</h3>\n");
			sink("<table class=\"doc-param-table\">\n");

			foreach (v; func.args) {
				arg := cast(Arg)v;
				format(sink, "<td><strong>%s</strong></td>", arg.name);
				format(sink, "<td>\n");
				filterMarkdown(sink, arg.content);
				format(sink, "</td></tr>\n");
			}

			sink("</table>\n");
		}

		// Post process return.
		if (func.rets !is null) {
			ret := cast(Return)func.rets[0];
			if (ret !is null && ret.content !is null) {
				sink("<h3>Return</h3>\n");
				sink("<div class=\"doc-param-table\">");
				filterMarkdown(sink, ret.content);
				sink("</div>\n");
			}
		}
	}
}
