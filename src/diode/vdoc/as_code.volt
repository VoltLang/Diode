// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to format vdoc objects as code.
//! Hmm ![Foo](http://i.imgur.com/UONEjuQ.png)
module diode.vdoc.as_code;

import core.exception;

import watt.text.sink : StringSink;
import watt.text.vdoc;
import watt.text.string;
import watt.text.format;
import watt.markdown : filterMarkdown;

import ir = liquid.ir;

import liquid.eval;

import diode.errors;
import diode.vdoc;
import diode.interfaces;
import diode.vdoc.parser;


//! Formats a vdoc module into code.
class FormatAsCode : Value
{
private:
	mState: State;


public:
	this(d: Driver, e: Engine, root: VdocRoot, v: Value, type: string)
	{
		mod := cast(Parent)v;
		mState.setup(d, e, root, mod, mod);

		// TODO handle other briefs.
		if (mod is null || mod.kind != Kind.Module) {
			d.warning("argument was not a vdoc module");
		}

		switch (type) {
		case "brief": break;
		default:
			d.warning("type '%s' not supported for as_code.", type);
		}
	}

	override fn toText(n: ir.Node, sink: Sink)
	{
		drawModule(ref mState, sink);
	}
}

struct State
{
public:
	drv: Driver;
	mod: Parent;
	root: VdocRoot;
	engine: Engine;
	parent: Parent;

	tabs: string;
	tabsProt: string;

	lastKind: Kind;
	lastAccess: Access;

	hasProt: bool;


public:
	fn setup(drv: Driver, engine: Engine, root: VdocRoot, mod: Parent, parent: Parent)
	{
		intSetup(drv, engine, root, mod, parent);
	}

	fn setup(ref oldState: State, parent: Parent)
	{
		intSetup(
			oldState.drv,
			oldState.engine,
			oldState.root,
			oldState.mod,
			parent);

		this.tabs = oldState.tabs ~ "\t";
		if (oldState.mod !is oldState.parent) {
			this.tabsProt = oldState.tabsProt ~ "\t";
		}
	}


private:
	fn intSetup(drv: Driver, engine: Engine, root: VdocRoot, mod: Parent,
	            parent: Parent)
	{
		this.drv = drv;
		this.root = root;
		this.mod = mod;
		this.parent = parent;
		this.engine = engine;
	}
}

fn flushaProtAndNewLine(ref s: State, access: Access, kind: Kind, spacing: string, sink: Sink)
{
	// Force one spacing on module level.
	if (s.mod is s.parent && s.lastKind != kind) {
		s.lastKind = kind;
		sink("\n");
		return;
	}

	if (s.lastKind == kind && s.lastAccess == access) {
		sink(spacing);
		return;
	}

	if (s.hasProt) {
		sink("\n\n");
	}

	s.hasProt = true;
	s.lastKind = kind;
	s.lastAccess = access;
	format(sink, "%s<span class=\"kw\">%s</span>:\n", s.tabsProt, accessToString(access));
}

fn drawName(ref s: State, named: Named, htmlClass: string, sink: Sink)
{
	drawName(ref s, named, named.name, htmlClass, sink);
}

fn drawName(ref s: State, named: Named, name: string, htmlClass: string, sink: Sink)
{
	if (named.url !is null) {
		format(sink, `<a class="%s" href="%s">%s</a>`,
		       htmlClass, named.url, name);
	} else if (named.tag !is null) {
		format(sink, `<a class="%s" href="#%s">%s</a>`,
		       htmlClass, named.tag, name);
	} else {
		sink(name);
	}
}

fn drawModule(ref s: State, sink: Sink)
{
	s.drawBrief(s.mod, sink);
	sink("<span class=\"ki\">module</span> ");
	s.drawName(s.mod, "na", sink);
	sink(";\n\n");

	s.drawImports(Access.Public, sink);

	s.drawChildren(sink);
}

fn drawChildren(ref s: State, sink: Sink)
{
	s.drawEnumDecls(Access.Public, sink);
	s.drawEnums(Access.Public, sink);
	s.drawAliases(Access.Public, sink);
	s.drawInterfaces(Access.Public, sink);
	s.drawClasses(Access.Public, sink);
	s.drawStructs(Access.Public, sink);
	s.drawUnions(Access.Public, sink);
	s.drawFields(Access.Public, sink);
	s.drawLocals(Access.Public, sink);
	s.drawGlobals(Access.Public, sink);
	s.drawCtors(Access.Public, sink);
	s.drawMembers(Access.Public, sink);
	s.drawFns(Access.Public, sink);

	s.drawEnumDecls(Access.Protected, sink);
	s.drawEnums(Access.Protected, sink);
	s.drawAliases(Access.Protected, sink);
	s.drawInterfaces(Access.Protected, sink);
	s.drawClasses(Access.Protected, sink);
	s.drawStructs(Access.Protected, sink);
	s.drawUnions(Access.Protected, sink);
	s.drawFields(Access.Protected, sink);
	s.drawLocals(Access.Protected, sink);
	s.drawGlobals(Access.Protected, sink);
	s.drawMembers(Access.Protected, sink);
	s.drawFns(Access.Protected, sink);
}

fn drawBrief(ref s: State, n: Named, sink: Sink)
{
	b := n.brief;
	if (b.length == 0) {
		return;
	}

	foreach (line; splitLines(b)) {
		format(sink, "%s<span class=\"c\">//! %s</span>\n", s.tabs, line);
	}
}

fn drawParentList(sink: Sink, parents: scope string[])
{
	if (parents.length > 0) {
		sink(" : ");

		hasPrinted: bool;
		foreach (p; parents) {
			if (hasPrinted) {
				sink(", ");
			}
			sink(p);
			hasPrinted = true;
		}
	}
}

fn drawImports(ref s: State, access: Access, sink: Sink)
{
	prefix: string;
	final switch(access) with (Access) {
	case Public: prefix = "<span class=\"kw\">public</span> "; break;
	case Protected: prefix = "<span class=\"kw\">protected</span> "; break;
	case Private: prefix = ""; break;
	}

	foreach (child; s.parent.children) {
		c := cast(Import)child;
		if (c is null || c.kind != Kind.Import ||
		    c.access != access) {
			continue;
		}

		s.lastKind = Kind.Import;
		s.drawBrief(c, sink);
		sink(prefix);
		sink("<span class=\"ki\">import</span> ");

		n := s.root.findNamed(c.name);
		if (n is null) {
			n = c;
		}

		if (c.bind !is null) {
			s.drawName(c, c.bind, sink);
			sink(" = ");
			s.drawName(n, "ni", sink);
			sink("\n");
		} else {
			s.drawName(n, "ni", sink);
			sink(";\n");
		}
	}

	// Extra newline between imports and other elements.
	if (s.lastKind == Kind.Import) {
		sink("\n");
	}
}


/*
 *
 * Enums
 *
 */

fn drawEnums(ref s: State, access: Access, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(Parent)child;
		if (c is null || c.kind != Kind.Enum ||
		    c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.Enum, "\n", sink);
		s.drawBrief(c, sink);
		s.drawEnum(c, sink);
	}
}

fn drawEnum(ref s: State, c: Parent, sink: Sink)
{
	format(sink, "%s<span class=\"ki\">enum</span> ", s.tabs);
	s.drawName(c, "ne", sink);
	format(sink, "\n%s{\n", s.tabs);
	old := s.tabs;
	s.tabs ~= "\t";

	foreach (child; c.children) {
		ed := cast(EnumDecl)child;
		s.drawBrief(ed, sink);
		sink(s.tabs);
		s.drawName(ed, "ne", sink);
		sink(",\n");
	}

	s.tabs = old;
	format(sink, "%s}\n", s.tabs);
}

fn drawAliases(ref s: State, access: Access, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(Alias)child;
		if (c is null || c.kind != Kind.Alias || c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.Alias, "", sink);
		s.drawAlias(c, sink);
	}
}

fn drawAlias(ref s: State, c: Alias, sink: Sink)
{
	s.drawBrief(c, sink);
	format(sink, "%s<span class=\"ki\">alias</span> ", s.tabs);
	s.drawName(c, "na", sink);
	format(sink, " = %s;\n", c.type);
}

fn drawEnumDecls(ref s: State, access: Access, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(EnumDecl)child;
		if (c is null || c.kind != Kind.EnumDecl ||
		    c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.EnumDecl, "", sink);
		s.drawEnumDecl(c, sink);
	}
}

fn drawEnumDecl(ref s: State, c: EnumDecl, sink: Sink)
{
	s.drawBrief(c, sink);
	format(sink, "%s<span class=\"ki\">enum</span> ", s.tabs);
	s.drawName(c, "ne", sink);
	format(sink, ";\n");
}


/*
 *
 * Variables
 *
 */

fn drawFields(ref s: State, access: Access, sink: Sink)
{
	s.drawVariables(access, Storage.Field, sink);
}

fn drawLocals(ref s: State, access: Access, sink: Sink)
{
	s.drawVariables(access, Storage.Local, sink);
}

fn drawGlobals(ref s: State, access: Access, sink: Sink)
{
	s.drawVariables(access, Storage.Global, sink);
}

fn drawVariables(ref s: State, access: Access, storage: Storage sink: Sink)
{
	prefix: string;
	final switch (storage) with (Storage) {
	case Field: prefix = ""; break;
	case Local: prefix = "<span class=\"kw\">local</span> "; break;
	case Global: prefix = "<span class=\"kw\">global</span> "; break;
	}

	foreach (child; s.parent.children) {
		c := cast(Variable)child;

		if (c is null || c.kind != Kind.Variable ||
		    c.access != access || c.storage != storage) {
			continue;
		}

		s.flushaProtAndNewLine(access, Kind.Variable, "", sink);
		s.drawBrief(c, sink);
		format(sink, "%s%s", s.tabs, prefix);
		s.drawName(c, "nv", sink);
		format(sink, ": %s;\n", c.type);
	}
}


/*
 *
 * Functions
 *
 */

fn drawFns(ref s: State, access: Access, sink: Sink)
{
	prefix := s.mod is s.parent ? "" : "<span class=\"kw\">static</span> ";

	foreach (child; s.parent.children) {
		c := cast(Function)child;
		if (c is null || c.kind != Kind.Function ||
		    c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.Function, "", sink);
		s.drawBrief(c, sink);
		s.drawFn(c, prefix, sink);
	}
}

fn drawCtors(ref s: State, access: Access, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(Function)child;
		if (c is null || c.kind != Kind.Constructor ||
		    c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.Member, "", sink);
		s.drawBrief(c, sink);
		s.drawCtor(c, sink);
	}
}

fn drawMembers(ref s: State, access: Access, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(Function)child;
		if (c is null || c.kind != Kind.Member ||
		    c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.Member, "", sink);
		s.drawBrief(c, sink);
		s.drawFn(c, "", sink);
	}
}

fn drawCtor(ref s: State, f: Function, sink: Sink)
{
	format(sink, "%s", s.tabs);
	drawName(ref s, f, "this", "nf", sink);
	sink("(");

	hasPrinted := false;
	foreach (c; f.args) {
		arg := cast(Arg)c;
		if (hasPrinted) {
			sink(", ");
		}

		if (arg.name is null) {
			format(sink, "%s", arg.type);
		} else {
			format(sink, "%s: %s", arg.name, arg.type);
		}
		hasPrinted = true;
	}

	sink(") { }\n");
}

fn drawFn(ref s: State, f: Function, prefix: string, sink: Sink)
{
	format(sink, "%s%s<span class=\"ki\">fn</span> ", s.tabs, prefix);
	s.drawName(f, "nf", sink);
	sink("(");

	hasPrinted := false;
	foreach (c; f.args) {
		arg := cast(Arg)c;
		if (hasPrinted) {
			sink(", ");
		}

		if (arg.name is null) {
			format(sink, "%s", arg.type);
		} else {
			format(sink, "%s: %s", arg.name, arg.type);
		}
		hasPrinted = true;
	}

	sink(")");

	if (f.rets.length > 0 && (cast(Return)f.rets[0]).type != "void") {
		format(sink, " %s", (cast(Return)f.rets[0]).type);
	}

	if (f.hasBody) {
		sink(" { }\n");
	} else {
		sink(";\n");
	}
}


/*
 *
 * Classes
 *
 */

fn drawInterfaces(ref s: State, access: Access, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(Parent)child;
		if (c is null || c.kind != Kind.Interface ||
		    c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.Interface, "\n", sink);
		s.drawBrief(c, sink);
		s.drawInterface(c, sink);
	}
}

fn drawInterface(ref s: State, c: Parent, sink: Sink)
{
	format(sink, "%s<span class=\"ki\">interface</span> ", s.tabs);
	s.drawName(c, "na", sink);

	drawParentList(sink, c.interfacesStr);

	format(sink, "\n%s{\n", s.tabs);

	newState: State;
	newState.setup(ref s, c);
	newState.drawChildren(sink);

	format(sink, "%s}\n", s.tabs);
}


/*
 *
 * Classes
 *
 */

fn drawClasses(ref s: State, access: Access, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(Parent)child;
		if (c is null || c.kind != Kind.Class ||
		    c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.Class, "\n", sink);
		s.drawBrief(c, sink);
		s.drawClass(c, sink);
	}
}

fn drawClass(ref s: State, c: Parent, sink: Sink)
{
	format(sink, "%s<span class=\"ki\">class</span> ", s.tabs);
	s.drawName(c, "na", sink);

	if (c.parentStr !is null) {
		drawParentList(sink, [c.parentStr] ~ c.interfacesStr);
	} else {
		drawParentList(sink, c.interfacesStr);
	}

	format(sink, "\n%s{\n", s.tabs);

	newState: State;
	newState.setup(ref s, c);
	newState.drawChildren(sink);

	format(sink, "%s}\n", s.tabs);
}


/*
 *
 * Aggregates
 *
 */

fn drawUnions(ref s: State, access: Access, sink: Sink)
{
	s.drawAggrs(access, Kind.Union, "<span class=\"ki\">union</span>", sink);
}

fn drawStructs(ref s: State, access: Access, sink: Sink)
{
	s.drawAggrs(access, Kind.Struct, "<span class=\"ki\">struct</span>", sink);
}

fn drawAggrs(ref s: State, access: Access, kind: Kind, prefix: string, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(Parent)child;
		if (c is null || c.kind != kind || c.access != access) {
			continue;
		}
		s.flushaProtAndNewLine(access, Kind.Class, "\n", sink);
		s.drawBrief(c, sink);
		s.drawAggr(c, prefix, sink);
	}
}

fn drawAggr(ref s: State, c: Parent, prefix: string, sink: Sink)
{
	format(sink, "%s%s ", s.tabs, prefix);
	s.drawName(c, "na", sink);
	format(sink, "\n%s{\n", s.tabs);

	newState: State;
	newState.setup(ref s, c);
	newState.drawChildren(sink);

	format(sink, "%s}\n", s.tabs);
}
