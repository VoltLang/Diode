// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.eval.value;

import ir = diode.ir;
import diode.errors;


/// Use the IR visitor Sink.
alias Sink = ir.Sink;

abstract class Value
{
	Value ident(ir.Node n, string key)
	{
		throw makeNotSet(n);
	}

	void toText(ir.Node n, Sink)
	{
		throw makeNotText(n);
	}

	Value[] toArray(ir.Node n)
	{
		throw makeNotArray(n);
	}
}

class Nil : Value
{
	override Value[] toArray(ir.Node)
	{
		return null;
	}
}

class Text : Value
{
	string text;

	this(string text)
	{
		this.text = text;
	}

	override void toText(ir.Node, Sink sink)
	{
		sink(text);
	}
}

class Array : Value
{
	Value[] vals;

	this(Value[] vals...)
	{
		this.vals = vals;
	}

	override Value[] toArray(ir.Node n)
	{
		return vals;
	}
}

class Set : Value
{
	Set parent;
	Value[string] ctx;

	override Value ident(ir.Node n, string key)
	{
		auto ret = key in ctx;
		if (ret !is null) {
			return *ret;
		} else if (parent !is null) {
			return parent.ident(n, key);
		} else {
			throw makeNoField(n, key);
		}
	}
}
