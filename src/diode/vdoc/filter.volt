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


/*
 *
 * Drawing functions.
 *
 */

//! Print the brief as regular text.
fn drawBriefText(named: Named, sink: Sink)
{
	sink(named.brief);
}

//! Print the raw content as markdown.
fn drawContentMD(named: Named, sink: Sink)
{
	sink(named.content);
}

//! Print the content as html as processed by markdown.
fn drawContentHTML(named: Named, sink: Sink)
{
	filterMarkdown(sink, named.content);
}

//! Print the full content as HTML.
fn drawFullHTML(named: Named, sink: Sink)
{
	filterMarkdown(sink, named.content);

	if (func := cast(Function)named) {
		drawFullFunctionHTML(func, sink);
	}

	// Post process see also.
	if (named.sa !is null) {
		sink("<h3>See also</h3>\n");
		sink("<ul>\n");

		foreach (sa; named.sa) {
			format(sink, "<li>\n");
			filterMarkdown(sink, sa);
			format(sink, "</li>\n");
		}

		sink("</ul>\n");
	}
}

//! Print extra function doccomments, like return and parameters.
fn drawFullFunctionHTML(func: Function, sink: Sink)
{
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
			format(sink, "<tr><td><strong>%s</strong></td>", arg.name);
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


/*
 *
 * Filter classes
 *
 */

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
		assert(named !is null);
	}
}

//! Filter for brief.
class FilterBrief : FilterValue
{
public:
	this(named: Named) { super(named, true); }

	override fn toText(n: ir.Node, sink: Sink)
	{
		drawBriefText(named, sink);
	}
}

//! Filter for formating of content of DocComments into HTML.
class FilterContent : FilterValue
{
public:
	this(named: Named, html: bool) { super(named, html); }

	override fn toText(n: ir.Node, sink: Sink)
	{
		if (html) {
			drawContentHTML(named, sink);
		} else {
			drawContentMD(named, sink);
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
		drawFullHTML(named, sink);
	}
}
