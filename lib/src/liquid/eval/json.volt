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
	case String: return new Text(v.str());
	case Boolean: return new Bool(v.boolean());
	case Null: return new Nil();
	case Double: return new Text(format("%s", v.floating()));
	case Long: return new Text(format("%s", v.integer()));
	case Ulong: return new Text(format("%s", v.unsigned()));
	case Object: return v.toSet();
	case Array: return v.toArray();
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
