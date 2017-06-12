// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.eval.value;

import watt.text.format : format;
import watt.text.string : indexOf;
import watt.text.utf : count;

import ir = diode.ir;
import diode.errors;


//! Use the IR visitor Sink.
alias Sink = ir.Sink;

abstract class Value
{
public:
	fn ident(n: ir.Node, key: string) Value
	{
		if (key == "size") {
			return toSize(n);
		}
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

	fn toSize(n: ir.Node) Value
	{
		return new Number(0.0, true);
	}

	fn opEquals(other: Value) bool
	{
		return false;
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

	override fn opEquals(other: Value) bool
	{
		otherNum := cast(Number)other;
		if (otherNum is null) {
			return false;
		}
		if (integer && otherNum.integer) {
			return cast(size_t)value == cast(size_t)otherNum.value;
		}
		return value == otherNum.value;
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

	override fn opEquals(other: Value) bool
	{
		otherBool := cast(Bool)other;
		if (otherBool is null) {
			return false;
		}
		return value == otherBool.value;
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

	override fn toSize(n: ir.Node) Value
	{
		return new Number(cast(f64)count(text), true);
	}

	override fn opEquals(other: Value) bool
	{
		otherText := cast(Text)other;
		if (otherText is null) {
			return false;
		}
		return text == otherText.text;
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

	override fn toSize(n: ir.Node) Value
	{
		return new Number(cast(f64)vals.length, true);
	}

	override fn ident(n: ir.Node, key: string) Value
	{
		if (vals.length == 0) {
			return super.ident(n, key);
		}
		if (key == "first") {
			return vals[0];
		} else if (key == "last") {
			return vals[$-1];
		} else {
			return super.ident(n, key);
		}
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
