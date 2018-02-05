// Copyright © 2012-2018, Bernard Helyer.  All rights reserved.
// Copyright © 2015-2018, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module liquid.eval.engine;

import core.exception;

import core.c.time : strftime, gmtime, time_t, tm, time;
import core.c.string : strcmp;

import watt.algorithm : runSort;
import watt.conv : toUpper, toDouble, toLower, toStringz;
import watt.math : ceil, floor, round;
import watt.text.sink;
import watt.text.string : split, join, replace, stripLeft, indexOf, stripRight, strip;
import watt.text.format : format;
import watt.text.utf : encode, decode, count;
import watt.text.ascii : isASCII, asciiToUpper = toUpper;
import watt.text.html : htmlEscape;

import ir = liquid.ir;
import liquid.eval.value;


class Engine : ir.Visitor
{
public:
	env: Set;
	v: Value;

	this(env: Set)
	{
		assert(env !is null);
		this.env = env;
	}


public:
	fn handleFilter(n: ir.Node, ident: string, child: Value, args: Value[], sink: Sink)
	{
		s: StringSink;
		child.toText(n, s.sink);

		fn getArg(i: size_t) string
		{
			if (args.length <= i) {
				handleError(format("expected at least %s argument to '%s' filter.", i+1, ident));
			}
			argsink: StringSink;
			args[i].toText(n, argsink.sink);
			return argsink.toString();
		}

		fn getIntegerArg(i: size_t) i32
		{
			if (args.length <= i) {
				handleError(format("expected at least %s argument to '%s' filter.", i+1, ident));
			}
			num := cast(Number)args[i];
			if (num is null || !num.integer) {
				handleError(format("expected integer argument to '%s' filter.", ident));
			}
			return cast(i32)num.value;
		}

		//! Do a (non-divide) arithmetic operation. (plus, minus, etc).
		fn arithmeticFilter(operation: dg(f64, f64) f64)
		{
			if (args.length != 1) {
				handleError(format("expected 1 argument to '%s'", ident));
			}
			childNum := cast(Number)child;
			argNum := cast(Number)args[0];
			if (childNum is null || argNum is null) {
				handleError(format("expected number arguments to %s filter", ident));
			}
			result := operation(childNum.value, argNum.value);
			v = new Number(result, argNum.integer);
		}

		fn replaceFirst(a: string, b: string)
		{
			str := s.toString();
			i := str.indexOf(a);
			if (i < 0) {
				v = new Text(s.toString());
			}
			index := cast(size_t)i;
			if (index+a.length >= str.length) {
				index = str.length;
			} else {
				index = index + a.length;
			}
			str = replace(str[0 .. index], a, b) ~ str[index .. $];
			v = new Text(str);
		}

		fn getTimeVal(val: Value) tm*
		{
			num := cast(Number)child;
			str := s.toString();
			t: time_t;
			if (num !is null) {
				if (!num.integer) {
					return null;
				}
				t = cast(time_t)num.value;
			} else if (str == "now" || str == "today") {
				t = time(null);
			} else {
				return null;
			}
			return gmtime(&t);
		}

		switch (ident) {
		case "abs":
			val := toDouble(s.toString());
			v = new Number(val < 0 ? val * -1 : val, floor(val) == val);
			break;
		case "append":
			arg := getArg(0);
			v = new Text(s.toString() ~ arg);
			break;
		case "capitalize":
			str := s.toString();
			i: size_t;
			firstc := decode(str, ref i);
			if (isASCII(firstc)) {
				str = [cast(immutable(char))asciiToUpper(str[0])] ~ str[1 .. $];
			}
			v = new Text(str);
			break;
		case "ceil":
			val := toDouble(s.toString());
			v = new Number(ceil(val), true);
			break;
		case "compact":
			arr := child.toArray(n);
			outvals: Value[];
			foreach (val; arr) {
				asNil := cast(Nil)val;
				if (asNil !is null) {
					continue;
				}
				outvals ~= val;
			}
			v = new Array(outvals);
			break;
		case "date":
			arg := getArg(0);
			ts := getTimeVal(child);
			if (ts is null) {
				v = new Nil();
				break;
			}
			buf: char[512];
			rv := strftime(buf.ptr, buf.length, toStringz(arg), ts);
			v = new Text(cast(string)buf[0 .. rv]);
			break;
		case "default":
			truthy := child.toBool(n);
			if (!truthy) {
				v = args[0];
			} else {
				v = child;
			}
			break;
		case "divided_by":
			if (args.length != 1) {
				handleError("expected 1 argument to 'divided_by'");
			}
			childNum := cast(Number)child;
			argNum := cast(Number)args[0];
			if (childNum is null || argNum is null) {
				handleError("expected number arguments to divided_by filter");
			}
			if (argNum.integer && cast(i32)argNum.value == 0) {
				handleError("divide by zero");
			}
			result := childNum.value / argNum.value;
			if (argNum.integer) {
				result = cast(f64)cast(i32)result;
			}
			v = new Number(result, argNum.integer);
			break;
		case "downcase": v = new Text(toLower(s.toString())); break;
		case "escape": v = new Text(htmlEscape(s.toString())); break;
		case "escape_once": 
			str := s.toString();
			str = str.replace("&#39;", "\'");
			str = str.replace("&quot;", `"`);
			str = str.replace("&lt;", "<");
			str = str.replace("&gt;", ">");
			str = str.replace("&amp;", "&");
			v = new Text(htmlEscape(str)); break;
		case "floor":
			val := toDouble(s.toString());
			v = new Number(floor(val), true);
			break;
		case "join":
			arg := getArg(0);
			children := child.toArray(n);
			argStrings := new string[](children.length);
			foreach (i, c; children) {
				cs: StringSink;
				c.toText(n, cs.sink);
				argStrings[i] = cs.toString();
			}
			v = new Text(join(argStrings, arg));
			break;
		case "lstrip": v = new Text(stripLeft(s.toString())); break;
		case "map":
			arr := child.toArray(n);
			arg := getArg(0);
			outvals := new Value[](arr.length);
			foreach (i, val; arr) {
				outvals[i] = val.ident(n, arg);
			}
			v = new Array(outvals);
			break;
		case "minus":
			fn doIt(a: f64, b: f64) f64 { return a - b; }
			arithmeticFilter(doIt);
			break;
		case "modulo":
			fn doIt(a: f64, b: f64) f64 { return a % b; }
			arithmeticFilter(doIt);
			break;
		case "plus":
			fn doIt(a: f64, b: f64) f64 { return a + b; }
			arithmeticFilter(doIt);
			break;
		case "prepend":
			arg := getArg(0);
			v = new Text(arg ~ s.toString());
			break;
		case "remove":
			arg := getArg(0);
			str := s.toString();
			v = new Text(str.replace(arg, ""));
			break;
		case "remove_first":
			replaceFirst(getArg(0), "");
			break;
		case "replace":
			arg1 := getArg(0);
			arg2 := getArg(1);
			str := s.toString();
			v = new Text(str.replace(arg1, arg2));
			break;
		case "replace_first":
			replaceFirst(getArg(0), getArg(1));
			break;
		case "reverse":
			values := child.toArray(n);
			newValues := new Value[](values.length);
			foreach (i, val; values) {
				newValues[$ - (i+1)] = val;
			}
			v = new Array(newValues);
			break;
		case "round":
			str := s.toString();
			if (args.length != 1) {
				v = new Number(round(toDouble(str)), true);
			} else {
				arg := cast(Number)args[0];
				if (arg is null || !arg.integer) {
					v = new Nil();
					break;
				}
				argstr := getArg(0);
				v = new Number(toDouble(format(format("%%.%sf", argstr), toDouble(str))), false);
			}
			break;
		case "rstrip": v = new Text(stripRight(s.toString())); break;
		case "size":
			v = child.toSize(n);
			break;
		case "slice":
			str := s.toString();
			a, b: i32;
			a = getIntegerArg(0);
			if (args.length > 1) {
				b = getIntegerArg(1) + a;
			} else {
				b = a + 1;
			}
			if (a < 0) {
				a = cast(i32)str.length + a;
				b += cast(i32)str.length;
			}
			i: size_t;
			acount := 0;
			while (acount < a && i < str.length) {
				decode(str, ref i);
				acount++;
			}
			j := i;
			bcount := acount;
			while (bcount < b && j < str.length) {
				decode(str, ref j);
				bcount++;
			}
			if (j > str.length) {
				j = str.length;
			}
			if (i >= str.length) {
				v = new Nil();
			} else {
				v = new Text(str[i .. j]);
			}
			break;
		case "sort", "sort_natural":
			arr := child.toArray(n);
			natural := ident == "sort_natural";
			fn cmp(ia: size_t, ib: size_t) bool
			{
				a, b: StringSink;
				arr[ia].toText(n, a.sink);
				arr[ib].toText(n, b.sink);
				as := a.toString();
				bs := b.toString();
				if (natural) {
					as = toLower(as);
					bs = toLower(bs);
				}
				return strcmp(toStringz(as), toStringz(bs)) < 0;
			}
			fn swap(ia: size_t, ib: size_t)
			{
				tmp: Value = arr[ia];
				arr[ia] = arr[ib];
				arr[ib] = tmp;
			}
			runSort(arr.length, cmp, swap);
			v = new Array(arr);
			break;
		case "strip": v = new Text(strip(s.toString())); break;
		case "strip_newlines":
			str := s.toString();
			str = str.replace("\r\n", "");
			str = str.replace("\n", "");
			v = new Text(str);
			break;
		case "times":
			fn doIt(a: f64, b: f64) f64 { return a * b; }
			arithmeticFilter(doIt);
			break;
		case "truncate":
			if (args.length < 1) {
				handleError("expected 1 or 2 arguments to truncate");
			}
			num := cast(Number)args[0];
			if (num is null) {
				handleError("expected first argument to truncate to be a number");
			}
			chars := cast(size_t)num.value;
			ellipsis := "...";
			if (args.length > 1) {
				ellipsis = getArg(1);
			}
			str := s.toString();
			if (count(str) <= chars) {
				v = new Text(str);
				break;
			}
			chars -= ellipsis.length;
			i: size_t;
			while (i < chars) {
				decode(str, ref i);
			}
			v = new Text(str[0 .. i] ~ ellipsis);
			break;
		case "truncatewords":
			if (args.length < 1) {
				handleError("expected 1 or 2 arguments to truncatewords");
			}
			num := cast(Number)args[0];
			if (num is null) {
				handleError("expected first argument to truncatewords to be a number");
			}
			wordcount := cast(size_t)num.value;
			ellipsis := "...";
			if (args.length > 1) {
				ellipsis = getArg(1);
			}
			str := s.toString();
			words := str.split(" ");
			if (words.length <= wordcount) {
				v = new Text(str);
				break;
			}
			outsink: StringSink;
			foreach (i, word; words[0 .. wordcount]) {
				outsink.sink(word);
				if (i < wordcount - 1) {
					outsink.sink(" ");
				}
			}
			outsink.sink(ellipsis);
			v = new Text(outsink.toString());
			break;
		case "uniq":
			// Not a fast way of doing this.
			arr := cast(Array)child;
			if (arr is null) {
				handleError("expected array child to uniq filter");
			}
			outvals: Value[];
			fn exists(v: Value) bool
			{
				foreach (outval; outvals) {
					if (v == outval) {
						return true;
					}
				}
				return false;
			}
			foreach (val; arr.vals) {
				if (!exists(val)) {
					outvals ~= val;
				}
			}
			v = new Array(outvals);
			break;
		case "upper", "upcase": v = new Text(toUpper(s.toString())); break;
		case "split":
			arg := getArg(0);
			pieces: string[];
			if (arg == "") {
				pieces = new string[](s.toString().length);
				foreach (i, c: dchar; s.toString()) {
					pieces[i] = encode(c);
				}
			} else {
				pieces  = s.toString().split(arg);
			}
			values := new Value[](pieces.length);
			foreach (i, piece; pieces) {
				values[i] = new Text(pieces[i]);
			}
			v = new Array(values);
			break;
		default: handleError("unknown filter " ~ ident); assert(false);
		/* These filters are used in testing. */
		case "TEST_replace_empty_with_nil":
			// A simple way of testing arrays with nil values interspersed.
			arr := child.toArray(n);
			outvals := new Value[](arr.length);
			foreach (i, val; arr) {
				ss: StringSink;
				val.toText(n, ss.sink);
				if (ss.toString() == "") {
					outvals[i] = new Nil();
				} else {
					outvals[i] = val;
				}
			}
			v = new Array(outvals);
			break;
		case "TEST_replace_NL_with_newline":
			str := s.toString();
			str = str.replace("NL", "\n");
			v = new Text(str);
			break;
		}
	}

	fn handleError(str: string)
	{
		throw new Exception(str);
	}

	fn handleInclude(i: ir.Include, env: Set, sink: Sink)
	{
		// Noop.
	}


public:
	override fn visit(t: ir.Text, sink: Sink) Status
	{
		sink(t.text);
		return Continue;
	}

	override fn leave(p: ir.Print, sink: Sink) Status
	{
		assert(v !is null);
		v.toText(p, sink);
		v = null;
		return Continue;
	}

	override fn enter(i: ir.If, sink: Sink) Status
	{
		// Eval expression
		// if 'site.has_feature'
		v = null;
		i.exp.accept(this, sink);
		assert(v !is null);
		cond := v.toBool(i);
		v = null;

		// If the cond is false nothing more to do, unless its inverted.
		condFalse := cond == i.invert;
		nodes := i.thenNodes;
		if (condFalse && i.elseNodes.length == 0) {
			return ContinueParent;
		} else if (condFalse && i.elseNodes.length > 0) {
			nodes = i.elseNodes;
		}

		// Create a new env for the child nodes.
		// 'if' site.has_feature
		parent := env;
		env = new Set();
		env.parent = parent;

		// Walk the nodes if cond is true.
		// 'if' site.has_feature
		foreach (n; nodes) {
			n.accept(this, sink);
		}
		env = parent;

		return ContinueParent;
	}

	override fn enter(f: ir.For, sink: Sink) Status
	{
		// Eval expression
		// for post in 'site.url'
		v = null;
		f.exp.accept(this, sink);
		assert(v !is null);

		// Set new env with var in it.
		// for 'post' in site.url
		arr := v.toArray(f.exp);
		v = null;

		parent := env;
		first := new Bool(true);
		last := new Bool(false);

		forloop := new Set();
		forloop.ctx["first"] = first;
		forloop.ctx["last"] = last;
		forloop.ctx["prev"] = new Nil();

		// Setup new env and loop over nodes.
		foreach(i, elm; arr) {
			env = new Set();
			env.parent = parent;
			env.ctx[f.var] = elm;
			env.ctx["forloop"] = forloop;

			// Update variables
			first.value = i == 0;
			last.value = i == arr.length - 1;

			foreach(n; f.nodes) {
				n.accept(this, sink);
			}

			forloop.ctx["prev"] = elm;
		}
		env = parent;

		return ContinueParent;
	}

	override fn leave(a: ir.Assign, sink: Sink) Status
	{
		assert(a.ident !is null);
		assert(v !is null);
		env.ctx[a.ident] = v;
		v = null;

		return Continue;
	}

	override fn visit(p: ir.Include, sink: Sink) Status
	{
		include := new Set();
		foreach (a; p.assigns) {
			a.exp.accept(this, sink);
			include.ctx[a.ident] = this.v;
			v = null;
		}

		// Setup a new environment.
		e := new Set();
		e.ctx["include"] = include;

		handleInclude(p, e, sink);

		return Continue;
	}


	/*
	 *
	 * Exp
	 *
	 */

	override fn enter(p: ir.BinOp, sink: Sink) Status
	{
		l, r: Value;
		p.l.accept(this, sink);
		l = v;
		p.r.accept(this, sink);
		r = v;
		lnil := cast(Nil)l;
		rnil := cast(Nil)r;
		nilinvolved := lnil !is null || rnil !is null;

		final switch (p.type) with (ir.BinOp.Type) {
		case Equal:
			v = new Bool(l == r);
			break;
		case NotEqual:
			v = new Bool(l != r);
			break;
		case GreaterThan:
			v = new Bool(l > r);
			break;
		case LessThan:
			v = new Bool(l < r);
			break;
		case GreaterThanOrEqual:
			v = new Bool(l >= r && !nilinvolved);
			break;
		case LessThanOrEqual:
			v = new Bool(l <= r && !nilinvolved);
			break;
		case Or:
			v = new Bool(l.toBool(null) || r.toBool(null));
			break;
		case And:
			v = new Bool(l.toBool(null) && r.toBool(null));
			break;
		case Contains:
			v = new Bool(l.contains(r));
			break;
		}
		return ContinueParent;
	}

	override fn leave(p: ir.BinOp, sink: Sink) Status
	{
		assert(false);
	}

	override fn enter(p: ir.Index, sink: Sink) Status
	{
		child, index: Value;
		p.child.accept(this, sink);
		child = v;
		p.index.accept(this, sink);
		index = v;

		v = child[index];
		return ContinueParent;
	}

	override fn leave(p: ir.Index, sink: Sink) Status
	{
		assert(false);
	}

	override fn leave(p: ir.Access, sink: Sink) Status
	{
		assert(v !is null);
		v = v.ident(p, p.ident);
		return Continue;
	}

	override fn enter(p: ir.Filter, sink: Sink) Status
	{
		// Eval expression
		// 'exp' | filter[: arg1[, arg2]]
		v = null;
		p.child.accept(this, sink);
		assert(v !is null);
		child := v;

		args := new Value[](p.args.length);
		foreach (i, parg; p.args) {
			v = null;
			parg.accept(this, sink);
			assert(v !is null);
			args[i] = v;
		}

		// Let implementor handle the filter.
		handleFilter(p, p.ident, child, args, sink);

		// Done.
		return ContinueParent;
	}

	override fn visit(p: ir.Ident, sink: Sink) Status
	{
		v = env.ident(p, p.ident);
		return Continue;
	}

	override fn visit(p: ir.StringLiteral, sink: Sink) Status
	{
		v = new Text(p.val);
		return Continue;
	}

	override fn visit(p: ir.BoolLiteral, sink: Sink) Status
	{
		v = new Bool(p.val);
		return Continue;
	}

	override fn visit(p: ir.NumberLiteral, sink: Sink) Status
	{
		v = new Number(p.val, p.integer);
		return Continue;
	}


	/*
	 *
	 * Dead
	 *
	 */

	override fn enter(ir.Assign, Sink) Status { return Continue; }
	override fn enter(ir.File, Sink) Status { return Continue; }
	override fn leave(ir.File, Sink) Status { return Continue; }
	override fn enter(ir.Access, Sink) Status { return Continue; }
	override fn leave(ir.Filter, Sink) Status { assert(false); }
	override fn enter(ir.Print, Sink) Status { return Continue; }
	override fn leave(ir.If, Sink) Status { assert(false); }
	override fn leave(ir.For, Sink) Status { assert(false); }
}
