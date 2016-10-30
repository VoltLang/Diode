// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.eval.engine;

import ir = diode.ir;
import diode.eval.value;


class Engine : ir.Visitor
{
public:
	env : Set;
	v : Value;

	this(env : Set)
	{
		assert(env !is null);
		this.env = env;
	}

public:
	override fn visit(t : ir.Text, sink : Sink) Status
	{
		sink(t.text);
		return Continue;
	}

	override fn leave(p : ir.Print, sink : Sink) Status
	{
		assert(v !is null);
		v.toText(p, sink);
		v = null;
		return Continue;
	}

	override fn enter(i : ir.If, sink : Sink) Status
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

	override fn enter(f : ir.For, sink : Sink) Status
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

	override fn leave(a : ir.Assign, sink : Sink) Status
	{
		assert(a.ident !is null);
		assert(v !is null);
		env.ctx[a.ident] = v;
		v = null;

		return Continue;
	}


	/*
	 *
	 * Exp
	 *
	 */

	override fn leave(p : ir.Access, sink : Sink) Status
	{
		assert(v !is null);
		v = v.ident(p, p.ident);
		return Continue;
	}

	override fn visit(p : ir.Ident, sink : Sink) Status
	{
		v = env.ident(p, p.ident);
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
	override fn enter(ir.Print, Sink) Status { return Continue; }
	override fn leave(ir.If, Sink) Status { assert(false); }
	override fn leave(ir.For, Sink) Status { assert(false); }
}
