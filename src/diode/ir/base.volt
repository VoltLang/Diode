// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.ir.base;


/// Argument to all visitor functions.
alias Sink = scope void delegate(const(char)[]);

/**
 * Base class for all nodes.
 */
abstract class Node
{
public:
	abstract Status accept(Visitor v, Sink sink);
}


class File : Node
{
public:
	Node[] nodes;

public:
	override Status accept(Visitor v, Sink sink)
	{
		auto s1 = v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		foreach (n; nodes) {
			auto s3 = n.accept(v, sink);
			if (s3 == Status.Stop) {
				return s3;
			}
		}

		return filterParent(v.leave(this, sink));
	}
}

class Text : Node
{
public:
	string text;

public:
	this(string text)
	{
		assert(text.length > 0);
		this.text = text;
	}

	override Status accept(Visitor v, Sink sink)
	{
		return filterParent(v.visit(this, sink));
	}
}

class Print : Node
{
public:
	Exp exp;

public:
	this(Exp exp)
	{
		assert(exp !is null);
		this.exp = exp;
	}

	override Status accept(Visitor v, Sink sink)
	{
		auto s1 = v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(exp !is null);
		auto s2 = exp.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		return filterParent(v.leave(this, sink));
	}
}

abstract class Exp : Node
{
}

class Ident : Exp
{
public:
	string ident;

public:
	this(string ident)
	{
		assert(ident !is null);
		this.ident = ident;
	}

	override Status accept(Visitor v, Sink sink)
	{
		return filterParent(v.visit(this, sink));
	}
}

class Access : Exp
{
public:
	Exp child;
	string ident;

public:
	this(Exp child, string ident)
	{
		assert(child !is null);
		assert(ident !is null);
		this.child = child;
		this.ident = ident;
	}

	override Status accept(Visitor v, Sink sink)
	{
		auto s1 = v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(child !is null);
		auto s2 = child.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		return filterParent(v.leave(this, sink));
	}
}

class For : Node
{
public:
	string var;
	Node[] nodes;
	Exp exp;

public:
	this(string var, Exp exp, Node[] nodes)
	{
		assert(var !is null);
		assert(exp !is null);
		this.var = var;
		this.exp = exp;
		this.nodes = nodes;
	}

	override Status accept(Visitor v, Sink sink)
	{
		auto s1 = v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(exp !is null);
		auto s2 = exp.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		foreach (n; nodes) {
			auto s3 = n.accept(v, sink);
			if (s3 == Status.Stop) {
				return s3;
			}
		}

		return filterParent(v.leave(this, sink));
	}
}


/*
 *
 * Visitor
 *
 */

enum Status
{
	Stop,
	Continue,
	ContinueParent,
}

abstract class Visitor
{
	alias Status = .Status;
	alias Stop = Status.Stop;
	alias Continue = Status.Continue;
	alias ContinueParent = Status.ContinueParent;

	abstract Status enter(File f, Sink sink);
	abstract Status leave(File f, Sink sink);

	abstract Status visit(Text t, Sink sink);
	abstract Status enter(Print p, Sink sink);
	abstract Status leave(Print p, Sink sink);
	abstract Status enter(For f, Sink sink);
	abstract Status leave(For f, Sink sink);

	abstract Status visit(Ident p, Sink sink);
	abstract Status enter(Access a, Sink sink);
	abstract Status leave(Access a, Sink sink);
}

Status filterParent(Status s)
{
	return s == Status.ContinueParent ? Status.Continue : s;
}
