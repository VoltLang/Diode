// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to format vdoc objects as code.
module diode.vdoc.as_code;

import core.exception;

import io = watt.io;
import watt.text.sink : StringSink;
import watt.text.vdoc;
import watt.text.string;
import watt.text.format;
import watt.text.markdown : filterMarkdown;

import diode.errors;
import diode.eval;
import diode.vdoc;
import diode.interfaces;
import diode.vdoc.parser;
import diode.vdoc.brief;


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
	//! Cached object for generating brief doccomments.
	brief: DocCommentBrief;

	tabs: string;
	tabsProt: string;

	lastKind: Kind;
	lastAccess: Access;

	hasProt: bool;
	hasPrinted: bool;


public:
	fn setup(drv: Driver, engine: Engine, root: VdocRoot, mod: Parent, parent: Parent)
	{
		intSetup(drv, engine, root, mod, parent,
		      new DocCommentBrief(drv, root, mod));
	}

	fn setup(ref oldState: State, parent: Parent)
	{
		intSetup(
			oldState.drv,
			oldState.engine,
			oldState.root,
			oldState.mod,
			parent,
			oldState.brief);

		this.tabs ~= "\t";
		if (oldState.mod !is oldState.parent) {
			this.tabsProt ~= "\t";
		}
	}


private:
	fn intSetup(drv: Driver, engine: Engine, root: VdocRoot, mod: Parent,
	            parent: Parent, brief: DocCommentBrief)
	{
		this.drv = drv;
		this.root = root;
		this.mod = mod;
		this.parent = parent;
		this.engine = engine;
		this.brief = brief;
	}
}

fn flushProt(ref s: State, access: Access, kind: Kind, sink: Sink)
{
	if (s.hasPrinted) {
		sink("\n");
		s.hasPrinted = false;
	}

	if ((s.lastKind == kind || s.mod is s.parent) &&
	    s.lastAccess == access) {
		return;
	}


	if (s.hasProt) {
		sink("\n");
	}

	s.hasProt = true;
	s.lastKind = kind;
	s.lastAccess = access;
	format(sink, "%s%s:\n", s.tabsProt, accessToString(access));
}

fn drawName(ref s: State, named: Named, sink: Sink)
{
	drawName(ref s, named, named.name, sink);
}

fn drawName(ref s: State, named: Named, name: string, sink: Sink)
{
	if (named.url !is null) {
		format(sink, `<a class="code" href="%s">%s</a>`,
		       named.url, name);
	} else if (named.tag !is null) {
		format(sink, `<a class="code" href="#%s">%s</a>`,
		       named.tag, name);
	} else {
		sink(name);
	}
}

fn drawModule(ref s: State, sink: Sink)
{
	s.drawBrief(s.mod, sink);
	sink("module ");
	s.drawName(s.mod, sink);
	sink(";\n\n");

	s.drawImports(Access.Public, sink);

	sink("\n");

	s.drawChildren(sink);
}

fn drawChildren(ref s: State, sink: Sink)
{
	s.drawEnumDecls(Access.Public, sink);
	s.drawEnums(Access.Public, sink);
	s.drawClasses(Access.Public, sink);
	s.drawStructs(Access.Public, sink);
	s.drawUnions(Access.Public, sink);
	s.drawFields(Access.Public, sink);
	s.drawLocals(Access.Public, sink);
	s.drawGlobals(Access.Public, sink);
	s.drawMembers(Access.Public, sink);
	s.drawFns(Access.Public, sink);
	s.drawCtors(Access.Public, sink);

	s.drawEnumDecls(Access.Protected, sink);
	s.drawEnums(Access.Protected, sink);
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
	b := s.brief.getString(n);
	if (b.length == 0) {
		return;
	}

	foreach (line; splitLines(b)) {
		format(sink, "%s//! %s\n", s.tabs, line);
	}
}

fn drawImports(ref s: State, access: Access, sink: Sink)
{
	prefix: string;
	final switch(access) with (Access) {
	case Public: prefix = "public "; break;
	case Protected: prefix = "protected "; break;
	case Private: prefix = ""; break;
	}

	foreach (child; s.parent.children) {
		c := cast(Import)child;
		if (c is null || c.kind != Kind.Import ||
		    c.access != access) {
			continue;
		}

		s.drawBrief(c, sink);
		sink(prefix);
		sink("import ");
		if (c.bind !is null) {
			s.drawName(c, c.bind, sink);
			format(sink, " = %s;\n", c.name);
		} else {
			s.drawName(c, sink);
			sink(";\n");
		}
		s.hasPrinted = true;
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
		s.flushProt(access, Kind.Enum, sink);
		s.drawBrief(c, sink);
		s.drawEnum(c, sink);
		s.hasPrinted = true;
	}
}

fn drawEnum(ref s: State, c: Parent, sink: Sink)
{
	format(sink, "%senum ", s.tabs);
	s.drawName(c, sink);
	format(sink, "\n%s{\n", s.tabs);
	old := s.tabs;
	s.tabs ~= "\t";

	foreach (child; c.children) {
		ed := cast(EnumDecl)child;
		s.drawBrief(ed, sink);
		sink(s.tabs);
		s.drawName(ed, sink);
		sink(",\n");
	}

	s.tabs = old;
	format(sink, "%s}\n", s.tabs);
}

fn drawEnumDecls(ref s: State, access: Access, sink: Sink)
{
	hasPrinted: bool;

	foreach (child; s.parent.children) {
		c := cast(EnumDecl)child;
		if (c is null || c.kind != Kind.EnumDecl ||
		    c.access != access) {
			continue;
		}
		s.flushProt(access, Kind.EnumDecl, sink);
		s.drawEnumDecl(c, sink);
		hasPrinted = true;
	}

	if (hasPrinted) {
		s.hasPrinted = true;
	}
}

fn drawEnumDecl(ref s: State, c: EnumDecl, sink: Sink)
{
	s.drawBrief(c, sink);
	format(sink, "%senum ", s.tabs);
	s.drawName(c, sink);
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
	hasPrinted: bool;
	final switch (storage) with (Storage) {
	case Field: prefix = ""; break;
	case Local: prefix = "local "; break;
	case Global: prefix = "global "; break;
	}

	foreach (child; s.parent.children) {
		c := cast(Variable)child;

		if (c is null || c.kind != Kind.Variable ||
		    c.access != access || c.storage != storage) {
			continue;
		}

		s.flushProt(access, Kind.EnumDecl, sink);
		s.drawBrief(c, sink);
		format(sink, "%s%s", s.tabs, prefix);
		s.drawName(c, sink);
		format(sink, ": %s;\n", c.type);
		hasPrinted = true;
	}

	if (hasPrinted) {
		s.hasPrinted = true;
	}
}


/*
 *
 * Functions
 *
 */

fn drawFns(ref s: State, access: Access, sink: Sink)
{
	hasPrinted: bool;
	prefix := s.mod is s.parent ? "" : "static ";

	foreach (child; s.parent.children) {
		c := cast(Function)child;
		if (c is null || c.kind != Kind.Function ||
		    c.access != access) {
			continue;
		}
		s.flushProt(access, Kind.Function, sink);
		s.drawBrief(c, sink);
		s.drawFn(c, prefix, sink);
		hasPrinted = true;
	}

	if (hasPrinted) {
		s.hasPrinted = true;
	}
}

fn drawCtors(ref s: State, access: Access, sink: Sink)
{
	hasPrinted: bool;

	foreach (child; s.parent.children) {
		c := cast(Function)child;
		if (c is null || c.kind != Kind.Constructor ||
		    c.access != access) {
			continue;
		}
		s.drawCtor(c, sink);
		hasPrinted = true;
	}

	if (hasPrinted) {
		s.hasPrinted = true;
	}
}

fn drawMembers(ref s: State, access: Access, sink: Sink)
{
	hasPrinted: bool;

	foreach (child; s.parent.children) {
		c := cast(Function)child;
		if (c is null || c.kind != Kind.Member ||
		    c.access != access) {
			continue;
		}
		s.flushProt(access, Kind.Member, sink);
		s.drawBrief(c, sink);
		s.drawFn(c, "", sink);
		hasPrinted = true;
	}

	if (hasPrinted) {
		s.hasPrinted = true;
	}
}

fn drawCtor(ref s: State, f: Function, sink: Sink)
{
	format(sink, "%s", s.tabs);
	drawName(ref s, f, "this", sink);
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
	format(sink, "%s%sfn ", s.tabs, prefix, f.name);
	s.drawName(f, sink);
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

	if (f.rets.length > 0 && (cast(Arg)f.rets[0]).type != "void") {
		format(sink, " %s", (cast(Arg)f.rets[0]).type);
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

fn drawClasses(ref s: State, access: Access, sink: Sink)
{
	foreach (child; s.parent.children) {
		c := cast(Parent)child;
		if (c is null || c.kind != Kind.Class ||
		    c.access != access) {
			continue;
		}
		s.flushProt(access, Kind.Class, sink);
		s.drawBrief(c, sink);
		s.drawClass(c, sink);
		s.hasPrinted = true;
	}
}

fn drawClass(ref s: State, c: Parent, sink: Sink)
{
	format(sink, "%sclass ", s.tabs);
	s.drawName(c, sink);
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
	s.drawAggrs(access, Kind.Union, "union", sink);
}

fn drawStructs(ref s: State, access: Access, sink: Sink)
{
	s.drawAggrs(access, Kind.Struct, "struct", sink);
}

fn drawAggrs(ref s: State, access: Access, kind: Kind, prefix: string, sink: Sink)
{
	hasPrinted: bool;

	foreach (child; s.parent.children) {
		c := cast(Parent)child;
		if (c is null || c.kind != kind || c.access != access) {
			continue;
		}
		s.flushProt(access, Kind.Class, sink);
		s.drawBrief(c, sink);
		s.drawAggr(c, prefix, sink);
		s.hasPrinted = true;
	}
}

fn drawAggr(ref s: State, c: Parent, prefix: string, sink: Sink)
{
	format(sink, "%s%s ", s.tabs, prefix);
	s.drawName(c, sink);
	format(sink, "\n%s{\n", s.tabs);

	newState: State;
	newState.setup(ref s, c);
	newState.drawChildren(sink);

	format(sink, "%s}\n", s.tabs);
}
