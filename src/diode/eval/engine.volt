// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.eval.engine;

import core.exception;

import watt.conv : toUpper, toDouble;
import watt.text.sink;
import watt.text.string : split, join;
import watt.text.format : format;
import watt.text.utf : encode;

import ir = diode.ir;
import diode.eval.value;


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

		fn getFirstArg() string
		{
			if (args.length != 1) {
				handleError(format("expected 1 argument to '%s' filter, not %s", ident, args.length));
			}
			argsink: StringSink;
			args[0].toText(n, argsink.sink);
			return argsink.toString();
		}

		switch (ident) {
		case "abs":
			val := toDouble(s.toString());
			v = new Number(val < 0 ? val * -1 : val);
			break;
		case "upper": v = new Text(toUpper(s.toString())); break;
		case "split":
			arg := getFirstArg();
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
		case "reverse":
			values := child.toArray(n);
			newValues := new Value[](values.length);
			foreach (i, val; values) {
				newValues[$ - (i+1)] = val;
			}
			v = new Array(newValues);
			break;
		case "join":
			arg := getFirstArg();
			children := child.toArray(n);
			argStrings := new string[](children.length);
			foreach (i, c; children) {
				cs: StringSink;
				c.toText(n, cs.sink);
				argStrings[i] = cs.toString();
			}
			v = new Text(join(argStrings, arg));
			break;
		default: handleError("unknown filter " ~ ident);
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
		v = new Number(p.val);
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
