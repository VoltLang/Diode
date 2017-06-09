// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.eval.value;

import watt.text.format : format;
import watt.text.string : indexOf;

import ir = diode.ir;
import diode.errors;


//! Use the IR visitor Sink.
alias Sink = ir.Sink;

abstract class Value
{
public:
	fn ident(n: ir.Node, key: string) Value
	{
		return new Nil();
	}

	fn toText(n: ir.Node, sink: Sink)
	{

	}

	fn toArray(n: ir.Node) Value[]
	{
		return null;
	}

	fn toBool(n: ir.Node) bool
	{
		return true;
	}
}

class Nil: Value
{
public:
	override fn toBool(n: ir.Node) bool
	{
		return false;
	}
}

class Number: Value
{
public:
	value: f64;
	integer: bool;


public:
	this(value: f64, integer: bool)
	{
		this.value = value;
		this.integer = integer;
	}

	override fn toText(n: ir.Node, sink: Sink)
	{
		/* The string given to us by vrt/libc/wherever is not really
		 * human friendly, so make it look nice.
		 */
		s := format("%s", value);
		i := s.indexOf('.');
		if (i < 0) {
			// No decimal place. Print it!
			sink(s);
			return;
		}
		if (cast(size_t)i == s.length - 1) {
			// The decimal is the last char already. Trim and print!
			sink(s[0 .. $-1]);
			return;
		}
		// Otherwise, we've got to scan the fractional portion.
		current := cast(size_t)(i+1);
		while (current < s.length && s[current] != '0') {
			current++;
		}
		until := current;
		while (current < s.length && s[current] == '0') {
			current++;
		}
		s = s[0 .. until];
		if (s[$-1] == '.') {
			s = s[0 .. $-1];
		}
		sink(s);
	}
}

class Bool: Value
{
public:
	value: bool;


public:
	this(value: bool)
	{
		this.value = value;
	}

	override fn toText(n: ir.Node, sink: Sink)
	{
		sink(value ? "true" : "false");
	}

	override fn toBool(n: ir.Node) bool
	{
		return value;
	}
}

class Text: Value
{
public:
	text: string;


public:
	this(string text)
	{
		this.text = text;
	}

	override fn toText(n: ir.Node, sink: Sink)
	{
		sink(text);
	}

	override fn toBool(n: ir.Node) bool
	{
		return text.length > 0;
	}
}

class Array: Value
{
public:
	vals: Value[];


public:
	this(vals: Value[]...)
	{
		this.vals = vals;
	}

	override fn toArray(n: ir.Node) Value[]
	{
		return vals;
	}
}

class Set: Value
{
public:
	parent: Set;
	ctx: Value[string];


public:
	this()
	{
	}

	this(parent: Set)
	{
		this.parent = parent;
	}

	override fn ident(n: ir.Node, key: string) Value
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
