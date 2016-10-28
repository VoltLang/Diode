// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.eval.value;

import ir = diode.ir;
import diode.errors;


/// Use the IR visitor Sink.
alias Sink = ir.Sink;

abstract class Value
{
public:
	fn ident(n : ir.Node, key : string) Value
	{
		return new Nil();
	}

	fn toText(n : ir.Node, sink : Sink)
	{

	}

	fn toArray(n : ir.Node) Value[]
	{
		return null;
	}

	fn toBool(n : ir.Node) bool
	{
		return true;
	}
}

class Nil : Value
{
public:
	override fn toBool(n : ir.Node) bool
	{
		return false;
	}
}

class Bool : Value
{
public:
	value : bool;


public:
	this(value : bool)
	{
		this.value = value;
	}

	override fn toText(n : ir.Node, sink : Sink)
	{
		sink(value ? "true" : "false");
	}

	override fn toBool(n : ir.Node) bool
	{
		return value;
	}	
}

class Text : Value
{
public:
	text : string;


public:
	this(string text)
	{
		this.text = text;
	}

	override fn toText(n : ir.Node, sink : Sink)
	{
		sink(text);
	}
}

class Array : Value
{
public:
	vals : Value[];


public:
	this(vals : Value[]...)
	{
		this.vals = vals;
	}

	override fn toArray(n : ir.Node) Value[]
	{
		return vals;
	}
}

class Set : Value
{
public:
	parent : Set;
	ctx : Value[string];


public:
	this()
	{
	}

	this(parent : Set)
	{
		this.parent = parent;
	}

	override fn ident(n : ir.Node, key : string) Value
	{
		ret := key in ctx;
		if (ret !is null) {
			return *ret;
		} else if (parent !is null) {
			return parent.ident(n, key);
		} else {
			return new Nil();
		}
	}
}
