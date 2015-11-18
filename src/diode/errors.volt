// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.errors;

import ir = diode.ir;


class EvalException : object.Exception
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
