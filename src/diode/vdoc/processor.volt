// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to process vdoc objects raw doccomments.
module diode.vdoc.processor;

import watt.text.sink : Sink, StringSink;
import watt.text.string : strip, indexOf;
import watt.text.format : format;
import watt.text.vdoc;
import watt.text.ascii;

import diode.vdoc;
import diode.vdoc.brief;


/*!
 * Processes the given VdocRoot.
 *
 * Setting various fields and adding objects to groups.
 */
fn process(vdocRoot: VdocRoot)
{
	p := new Processor(vdocRoot);

	foreach (group; vdocRoot.groups) {
		p.processNamed(group);
	}

	foreach (mod; vdocRoot.modules) {
		p.processParent(mod);
	}
}

//! Main class for processing vdoc objects.
class Processor : DocCommentParser
{
public:
	groups: Parent[string];


public:
	this(root: VdocRoot)
	{
		super(root);

		foreach (group; root.groups) {
			groups[group.search] = group;
		}
	}
}

//! Results from a doccomment parsing.
struct DocCommentResult
{
	//! The main content for this doccomment.
	content: string;

	//! Brief doccomment.
	brief: string;

	//! The groups this comment is in.
	ingroups: string[];

	//! Return documentation.
	ret: string;

	//! Params for functions.
	params: DocCommentParam[];

	//! See also sections.
	sa: string[];

	//! Throws sections.
	_throw: string[];

	//! Side-Effect sections.
	se: string[];

	//! The doccomment content form the return command.
	returnContent: string;
}

//! A single parameter result.
class DocCommentParam
{
	arg: string;
	dir: string;
	doc: string;
}

//! Helper class for DocComments.
class DocCommentParser : DocSink
{
public:
	//! For lookups.
	root: VdocRoot;
	//! The full comment content.
	full: StringSink;
	//! String sink for params, briefs and more.
	temp: StringSink;
	//! Current param.
	param: DocCommentParam;
	//! The result of the processing.
	results: DocCommentResult;
	//! Has a `@@brief` directive been processed.
	hasBrief: bool;


public:
	this(root: VdocRoot)
	{
		this.root = root;
	}

	final fn parseRaw(raw: string)
	{
		results = DocCommentResult.init;
		hasBrief = false;

		parse(raw, this, null);

		// Set the full string.
		results.content = full.toString();
		full.reset();

		// Handle auto brief if @brief command was not used.
		if (!hasBrief) {
			results.brief = generateAutoBrief(results.content);
		}
	}

	override fn ingroup(sink: Sink, group: string)
	{
		results.ingroups ~= group;
	}

	override fn sectionStart(sink: Sink, sec: DocSection)
	{
	}

	override fn sectionEnd(sink: Sink, sec: DocSection)
	{
		final switch (sec) with (DocSection) {
		case SeeAlso:
			val := temp.toString();
			temp.reset();
			word := removeFirstWord(ref val);
			link(sink, DocState.Section, strip(word), "");
			temp.sink(val);
			results.sa ~= temp.toString();
			break;
		case Return: results.ret ~= temp.toString(); break;
		case Throw: results._throw ~= temp.toString(); break;
		case SideEffect: results.se ~= temp.toString(); break;
		}

		temp.reset();
	}

	override fn paramStart(sink: Sink, direction: string, arg: string)
	{
		param = new DocCommentParam();
		param.arg = arg;
		param.dir = direction;
	}

	override fn paramEnd(sink: Sink)
	{
		// Just in case.
		if (param is null) {
			return;
		}

		results.params ~= param;

		param.doc = temp.toString();
		param = null;

		temp.reset();
	}

	override fn briefStart(sink: Sink)
	{
		hasBrief = true;
	}

	override fn briefEnd(sink: Sink)
	{
		// Set the brief string.
		str := temp.toString();
		temp.reset();
		results.brief = generateAutoBrief(str);
	}

	override fn p(sink: Sink, state: DocState, d: string)
	{
		final switch (state) with (DocState) {
		case Content:
			full.sink("`");
			full.sink(d);
			full.sink("`");
			break;
		case Param, Section, Brief:
			temp.sink("`");
			temp.sink(d);
			temp.sink("`");
			break;
		}
	}

	override fn link(sink: Sink, state: DocState, target: string, text: string)
	{
		text = strip(text);
		url: string;
		name: string;
		md: string;

		if (n := root.findNamed(target)) {

			// If we have no text use the name from the object.
			if (text is null) {
				text = n.name;
			}

			// Does this named thing has a URL?
			if (n.url !is null) {
				md = format(`[%s](%s)`, text, n.url);
			} else {
				md = text;
			}

		} else if (text is null) {
			text = target;
			md = target;
		}

		final switch (state) with (DocState) {
		case Content:
			full.sink(md);
			break;
		case Param, Brief, Section:
			temp.sink(md);
			break;
		}
	}

	override fn content(sink: Sink, state: DocState, d: string)
	{
		final switch (state) with (DocState) {
		case Brief, Param, Section: temp.sink(d); return;
		// Content path, for full comment send as is.
		case Content: full.sink(d); break;
		}
	}

	override fn defgroup(sink: Sink, group: string, text: string) { }
	override fn start(sink: Sink) { }
	override fn end(sink: Sink) { }
}

private fn processParent(p: Processor, n: Parent)
{
	p.processNamed(n);

	foreach (child; n.children) {
		if (c := cast(Parent)child) {
			p.processParent(c);
		} else if (c := cast(Function)child) {
			p.processFunction(c);
		} else if (c := cast(Named)child) {
			p.processNamed(c);
		}
	}
}

private fn processFunction(p: Processor, n: Function)
{
	if (!p.processNamed(n)) {
		return;
	}

	foreach (param; p.results.params) {
		arg: Arg;

		foreach (v; n.args) {
			arg = cast(Arg)v;

			if (param.arg == arg.name) {
				arg.content = param.doc;
				break;
			} else {
				arg = null;
			}
		}
	}

	if (n.rets !is null) {
		ret := cast(Return)n.rets[0];
		if (ret !is null) {
			ret.content = p.results.ret;
		}
	}
}

private fn removeFirstWord(ref s: string) string
{
	word := s;
	foreach (i, c: dchar; s) {
		if (!isWhite(c)) {
			continue;
		}
		word = s[0 .. i];
		s = s[i .. $];
	}
	return word;
}

private fn processNamed(p: Processor, n: Named) bool
{
	if (n.raw is null) {
		return false;
	}

	p.parseRaw(n.raw);

	n.content = p.results.content;
	n.brief = p.results.brief;
	n.sa = p.results.sa;
	n.se = p.results.se;
	n._throw = p.results._throw;

	foreach (ident; p.results.ingroups) {
		group := p.groups.get(ident, null);
		if (group is null) {
			group = p.root.addGroup(ident, null, null);
			p.groups[ident] = group;
		}
		group.children ~= n;
		n.ingroup ~= group;
	}

	return true;
}
