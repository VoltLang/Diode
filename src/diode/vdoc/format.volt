// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.vdoc.format;

import core.exception;

import io = watt.io;
import watt.text.vdoc;
import watt.text.string;
import watt.text.format;

import diode.errors;
import diode.eval;
import diode.vdoc;
import diode.vdoc.parser;


class VodcModuleBrief : ir.File
{
	override fn accept(v: ir.Visitor, sink: Sink) ir.Status
	{
		e := cast(Engine)v;
		if (e is null) {
			io.error.writefln("internal error");
			io.error.flush();
			return ir.Status.Continue;
		}

		mod := e.env.ident(this, "include").ident(this, "mod");

		s: State;
		s.mod = cast(Parent)mod;
		s.parent = s.mod;

		if (s.mod is null) {
			io.error.writefln("include set not given mod argument.");
			io.error.flush();
			return ir.Status.Continue;
		}


		sink("```volt\n");

		s.drawBrief(s.mod, sink);
		format(sink, "module %s;\n\n", s.mod.name);

		s.drawImports(Access.Public, sink);

		sink("\n");

		s.drawChildren(sink);

		format(sink, "```\n");

		return ir.Status.Continue;
	}
}

struct State
{
public:
	engine: Engine;
	mod: Parent;
	parent: Parent;

	tabs: string;
	tabsProt: string;

	lastKind: Kind;
	lastAccess: Access;

	hasProt: bool;
	hasPrinted: bool;
}

fn setup(ref newState: State, ref oldState: State, parent: Parent)
{
	newState.mod = oldState.mod;
	newState.parent = parent;
	newState.tabs ~= "\t";
	if (oldState.mod !is oldState.parent) {
		newState.tabsProt ~= "\t";
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
	b := rawToBrief(n.raw);
	if (b.length == 0) {
		return;
	}

	foreach (line; splitLines(b)) {
		format(sink, "%s/// %s\n", s.tabs, line);
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
		if (c.bind !is null) {
			format(sink, "%simport %s = %s;\n", prefix, c.bind, c.name);
		} else {
			format(sink, "%simport %s;\n", prefix, c.name);
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
	format(sink, "%senum %s\n%s{\n", s.tabs, c.name, s.tabs);
	tabs := s.tabs ~ "\t";

	foreach (child; c.children) {
		ed := cast(EnumDecl)child;
		format(sink, "%s%s,\n", tabs, ed.name);
	}

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
	format(sink, "%senum %s;\n", s.tabs, c.name);
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
		format(sink, "%s%s%s: %s;\n", s.tabs, prefix, c.name, c.type);
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
		s.drawFn(c, prefix, sink);
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

fn drawFn(ref s: State, f: Function, prefix: string, sink: Sink)
{
	format(sink, "%s%sfn %s(", s.tabs, prefix, f.name);

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
	format(sink, "%sclass %s\n%s{\n", s.tabs, c.name, s.tabs);

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
	s.drawAggrs(access, Kind.Struct, "union", sink);
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
	format(sink, "%s%s %s\n%s{\n", s.tabs, prefix, c.name, s.tabs);

	newState: State;
	newState.setup(ref s, c);
	newState.drawChildren(sink);

	format(sink, "%s}\n", s.tabs);
}