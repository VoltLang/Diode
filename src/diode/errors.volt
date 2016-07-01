// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.errors;

import core.exception;
import watt.text.source;
import watt.text.format : format;
import ir = diode.ir;


class DiodeException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}


/*
 *
 * Specific Exceptions.
 *
 */

DiodeException makeNoExtension(string file)
{
	auto str = format("error: no file extension '%s'", file);
	return new DiodeException(str);
}

DiodeException makeExtensionNotSupported(string file)
{
	auto str = format("error: file extension not supported '%s'", file);
	return new DiodeException(str);
}

DiodeException makeLayoutNotFound(string file, string layout)
{
	auto str = format("%s:1 error: layout '%s' not found", file, layout);
	return new DiodeException(str);
}

DiodeException makeConversionNotSupported(string layout, string contents)
{
	auto str = format("%s:1 error: can not convert '%s' -> '%s'",
	                  contents, contents, layout);
	return new DiodeException(str);
}

DiodeException makeBadHeader(ref Location loc)
{
	return new DiodeException(loc.toString() ~ "error: invalid header");
}


/*
 *
 * Eval Exceptions
 *
 */

class EvalException : DiodeException
{
	ir.Node n;

	this(ir.Node n, string msg)
	{
		super(msg);
	}
}

EvalException makeNoField(ir.Node n, string key)
{
	return new EvalException(n, "no field named '" ~ key ~ "'");
}

EvalException makeNotSet(ir.Node n)
{
	return new EvalException(n, "value is not a set");
}

EvalException makeNotText(ir.Node n)
{
	return new EvalException(n, "value is not text (or convertable)");
}

EvalException makeNotArray(ir.Node n)
{
	return new EvalException(n, "value is not an array");
}
