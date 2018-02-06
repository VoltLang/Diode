// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.errors;

import core.exception;
import watt.text.format : format;
import ir = liquid.ir;


class DiodeException : Exception
{
	this(msg: string)
	{
		super(msg);
	}
}


/*
 *
 * Specific Exceptions.
 *
 */

fn makeNoExtension(file: string) DiodeException
{
	str := format("error: no file extension '%s'", file);
	return new DiodeException(str);
}

fn makeExtensionNotSupported(file: string) DiodeException
{
	str := format("error: file extension not supported '%s'", file);
	return new DiodeException(str);
}

fn makeLayoutNotFound(file: string, layout: string) DiodeException
{
	str := format("%s:1 error: layout '%s' not found", file, layout);
	return new DiodeException(str);
}

fn makeConversionNotSupported(layout: string, contents: string) DiodeException
{
	str := format("%s:1 error: can not convert '%s' -> '%s'",
	                  contents, contents, layout);
	return new DiodeException(str);
}


/*
 *
 * Eval Exceptions
 *
 */

class EvalException : DiodeException
{
public:
	n: ir.Node;


public:
	this(n: ir.Node, msg: string)
	{
		super(msg);
	}
}

fn makeNoField(n: ir.Node, key: string) EvalException
{
	return new EvalException(n, "no field named '" ~ key ~ "'");
}

fn makeNotSet(n: ir.Node) EvalException
{
	return new EvalException(n, "value is not a set");
}

fn makeNotText(n: ir.Node) EvalException
{
	return new EvalException(n, "value is not text (or convertable)");
}

fn makeNotArray(n: ir.Node) EvalException
{
	return new EvalException(n, "value is not an array");
}
