// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.ir.node;

// We are using the one true string sink from watt.
public import watt.text.sink : Sink;


/*!
 * Base class for all nodes.
 */
abstract class Node
{
public:
	abstract fn accept(v: Visitor, sink: Sink) Status;
}

/*!
 * Top level container node.
 */
class File : Node
{
public:
	nodes: Node[];


public:
	override fn accept(v: Visitor, sink: Sink) Status
	{
		s1 := v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		foreach (n; nodes) {
			s3 := n.accept(v, sink);
			if (s3 == Status.Stop) {
				return s3;
			}
		}

		return filterParent(v.leave(this, sink));
	}
}

/*!
 * A string of text to be printed out directly.
 */
class Text : Node
{
public:
	text: string;


public:
	this(text: string)
	{
		assert(text.length > 0);
		this.text = text;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		return filterParent(v.visit(this, sink));
	}
}

/*!
 * A expression to be evaluated and printed.
 */
class Print : Node
{
public:
	exp: Exp;


public:
	this(exp: Exp)
	{
		assert(exp !is null);
		this.exp = exp;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		s1 := v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(exp !is null);
		s2 := exp.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		return filterParent(v.leave(this, sink));
	}
}

/*!
 * Base class for all expressions.
 */
abstract class Exp : Node
{
}

/*!
 * A single identifier to be looked up in the global scope.
 */
class Ident : Exp
{
public:
	ident: string;


public:
	this(ident: string)
	{
		assert(ident !is null);
		this.ident = ident;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		return filterParent(v.visit(this, sink));
	}
}

/*!
 * A string literal.
 */
class StringLiteral : Exp
{
public:
	val: string;


public:
	this(val: string)
	{
		this.val = val;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		return filterParent(v.visit(this, sink));
	}
}

/*!
 * A bool literal.
 */
class BoolLiteral : Exp
{
public:
	val: bool;


public:
	this(val: bool)
	{
		this.val = val;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		return filterParent(v.visit(this, sink));
	}
}

/*!
 * A literal for a number.
 */
class NumberLiteral : Exp
{
public:
	val: f64;
	integer: bool;


public:
	this(val: f64, integer: bool)
	{
		this.val = val;
		this.integer = integer;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		return filterParent(v.visit(this, sink));
	}
}

class BinOp : Exp
{
public:
	enum Type
	{
		Equal,
		NotEqual,
		GreaterThan,
		LessThan,
		GreaterThanOrEqual,
		LessThanOrEqual,
		Or,
		And
	}

public:
	type: Type;
	l: Exp;
	r: Exp;

public:
	this(type: Type, l: Exp, r: Exp)
	{
		assert(l !is null && r !is null);
		this.type = type;
		this.l = l;
		this.r = r;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		s1 := v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		s2 := l.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		s3 := r.accept(v, sink);
		if (s3 == Status.Stop) {
			return s3;
		}

		return filterParent(v.leave(this, sink));
	}
}

/*!
 * Lookup symbol into child expression.
 */
class Access : Exp
{
public:
	child: Exp;
	ident: string;


public:
	this(child: Exp, ident: string)
	{
		assert(child !is null);
		assert(ident !is null);
		this.child = child;
		this.ident = ident;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		s1 := v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(child !is null);
		s2 := child.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		return filterParent(v.leave(this, sink));
	}
}

/*!
 * Filter expression.
 */
class Filter : Exp
{
public:
	child: Exp;
	ident: string;
	args: Exp[];


public:
	this(child: Exp, ident: string, args: Exp[])
	{
		assert(child !is null);
		assert(ident !is null);
		this.child = child;
		this.ident = ident;
		this.args = args;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		s1 := v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(child !is null);
		s2 := child.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		foreach (arg; args) {
			s3 := arg.accept(v, sink);
			if (s3 == Status.Stop) {
				return s3;
			}
		}

		return filterParent(v.leave(this, sink));
	}
}

/*!
 * If control statement.
 */
class If : Node
{
public:
	thenNodes: Node[];
	elseNodes: Node[];
	exp: Exp;
	invert: bool;


public:
	this(invert: bool, exp: Exp, thenNodes: Node[], elseNodes: Node[])
	{
		assert(exp !is null);
		this.invert = invert;
		this.exp = exp;
		this.thenNodes = thenNodes;
		this.elseNodes = elseNodes;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		s1 := v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(exp !is null);
		s2 := exp.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		foreach (n; thenNodes) {
			s3 := n.accept(v, sink);
			if (s3 == Status.Stop) {
				return s3;
			}
		}

		foreach (n; elseNodes) {
			s4 := n.accept(v, sink);
			if (s4 == Status.Stop) {
				return s4;
			}
		}

		return filterParent(v.leave(this, sink));
	}
}

/*!
 * For loop control statement.
 */
class For : Node
{
public:
	var: string;
	nodes: Node[];
	exp: Exp;


public:
	this(var: string, exp: Exp, nodes: Node[])
	{
		assert(var !is null);
		assert(exp !is null);
		this.var = var;
		this.exp = exp;
		this.nodes = nodes;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		s1 := v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(exp !is null);
		s2 := exp.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		foreach (n; nodes) {
			s3 := n.accept(v, sink);
			if (s3 == Status.Stop) {
				return s3;
			}
		}

		return filterParent(v.leave(this, sink));
	}
}

class Assign : Node
{
public:
	ident: string;
	exp: Exp;


public:
	this(ident: string, exp: Exp)
	{
		assert(ident !is null);
		assert(exp !is null);
		this.ident = ident;
		this.exp = exp;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		s1 := v.enter(this, sink);
		if (s1 != Status.Continue) {
			return filterParent(s1);
		}

		assert(exp !is null);
		s2 := exp.accept(v, sink);
		if (s2 == Status.Stop) {
			return s2;
		}

		return filterParent(v.leave(this, sink));
	}
}

class Include : Node
{
public:
	filename: string;
	assigns: Assign[];


public:
	this(filename: string, assigns: Assign[])
	{
		assert(filename !is null);
		this.filename = filename;
		this.assigns = assigns;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		return filterParent(v.visit(this, sink));
	}
}

/*
 * Utility Nodes
 */

/*!
 * Not actually output by the parser. Used for things like %endif%,
 * which mark the end of a list of nodes.
 */
class ClosingTagNode : Node
{
public:
	name: string;

public:
	this(name: string)
	{
		assert(name !is null);
		this.name = name;
	}

	override fn accept(v: Visitor, sink: Sink) Status
	{
		assert(false);
	}
}


/*
 *
 * Visitor
 *
 */


/*!
 * Control the flow of the visitor.
 */
enum Status
{
	Stop,
	Continue,
	ContinueParent,
}

/*!
 * Base visitor class.
 */
abstract class Visitor
{
	alias Status = .Status;
	alias Stop = Status.Stop;
	alias Continue = Status.Continue;
	alias ContinueParent = Status.ContinueParent;

	abstract fn enter(File, Sink) Status;
	abstract fn leave(File, Sink) Status;

	abstract fn visit(Text, Sink) Status;
	abstract fn enter(Print, Sink) Status;
	abstract fn leave(Print, Sink) Status;
	abstract fn enter(If, Sink) Status;
	abstract fn leave(If, Sink) Status;
	abstract fn enter(For, Sink) Status;
	abstract fn leave(For, Sink) Status;
	abstract fn enter(Assign, Sink) Status;
	abstract fn leave(Assign, Sink) Status;
	abstract fn visit(Include, Sink) Status;

	abstract fn enter(Access, Sink) Status;
	abstract fn leave(Access, Sink) Status;
	abstract fn enter(Filter, Sink) Status;
	abstract fn leave(Filter, Sink) Status;
	abstract fn enter(BinOp, Sink) Status;
	abstract fn leave(BinOp, Sink) Status;
	abstract fn visit(Ident, Sink) Status;
	abstract fn visit(StringLiteral, Sink) Status;
	abstract fn visit(BoolLiteral, Sink) Status;
	abstract fn visit(NumberLiteral, Sink) Status;
}

/*!
 * Filter out continue parent and turn that into a continue.
 */
fn filterParent(s: Status) Status
{
	return s == Status.ContinueParent ? Status.Continue : s;
}
