// Copyright © 2016-2018, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
/*!
 * This module holds code to parse json files into eval sets and values.
 */
module liquid.eval.json;

import watt.text.format;

import json = watt.json;

import liquid.eval;


fn toValue(ref v: json.Value) Value
{
	final switch (v.type()) with (json.DomType) {
	case STRING: return new Text(v.str());
	case BOOLEAN: return new Bool(v.boolean());
	case NULL: return new Nil();
	case DOUBLE: return new Text(format("%s", v.floating()));
	case LONG: return new Text(format("%s", v.integer()));
	case ULONG: return new Text(format("%s", v.unsigned()));
	case OBJECT: return v.toSet();
	case ARRAY: return v.toArray();
	}
}

fn toSet(ref v: json.Value) Set
{
	ret := new Set();

	foreach (k; v.keys()) {
		child := v.lookupObjectKey(k);
		ret.ctx[k] = child.toValue();
	}

	return ret;
}

fn toArray(ref v: json.Value) Array
{
	arr := v.array();
	ret := new Value[](arr.length);

	foreach (i, ref child; arr) {
		ret[i] = child.toValue();
	}

	return new Array(ret);
}
