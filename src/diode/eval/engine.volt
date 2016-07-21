// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.eval.engine;

import ir = diode.ir;
import diode.eval.value;


class Engine : ir.Visitor
{
public:
	Set env;
	Value v;

	this(Set env)
	{
		assert(env !is null);
		this.env = env;
	}

public:
	override Status visit(ir.Text t, Sink sink)
	{
		sink(t.text);
		return Continue;
	}

	override Status leave(ir.Print f, Sink sink)
	{
		v.toText(f, sink);
		v = null;
		return Continue;
	}

	override Status enter(ir.If i, Sink sink)
	{
		// Eval expression
		// if 'site.has_feature'
		v = null;
		i.exp.accept(this, sink);
		assert(v !is null);
		bool cond = v.toBool(i);
		v = null;

		// If the cond is false nothing more to do.
		if (!cond) {
			return ContinueParent;
		}

		// Create a new env for the child nodes.
		// 'if' site.has_feature
		auto myEnv = new Set();
		myEnv.parent = env;
		env = myEnv;

		// Walk the nodes if cond is true.
		// 'if' site.has_feature
		foreach (n; i.nodes) {
			n.accept(this, sink);
		}
		env = env.parent;

		return ContinueParent;
	}

	override Status enter(ir.For f, Sink sink)
	{
		// Eval expression
		// for post in 'site.url'
		v = null;
		f.exp.accept(this, sink);
		assert(v !is null);

		// Set new env with var in it.
		// for 'post' in site.url
		auto myEnv = new Set();
		myEnv.parent = env;
		auto arr = v.toArray(f.exp);
		v = null;

		auto first = new Bool(true);
		auto last = new Bool(false);
		auto forloop = new Set();
		forloop.ctx["first"] = first;
		forloop.ctx["last"] = last;
		env.ctx["forloop"] = forloop;

		// Setup new env and loop over nodes.
		env = myEnv;
		foreach(i, elm; arr) {
			// Update variables
			first.value = i == 0;
			last.value = i == arr.length - 1;

			env.ctx[f.var] = elm;
			foreach(n; f.nodes) {
				n.accept(this, sink);
			}
		}
		env = env.parent;

		return ContinueParent;
	}


	/*
	 *
	 * Exp
	 *
	 */

	override Status leave(ir.Access p, Sink sink)
	{
		assert(v !is null);
		v = v.ident(p, p.ident);
		return Continue;
	}

	override Status visit(ir.Ident p, Sink sink)
	{
		v = env.ident(p, p.ident);
		return Continue;
	}


	/*
	 *
	 * Dead
	 *
	 */

	override Status enter(ir.File, Sink sink) { return Continue; }
	override Status leave(ir.File, Sink sink) { return Continue; }
	override Status enter(ir.Access, Sink sink) { return Continue; }
	override Status enter(ir.Print, Sink sink) { return Continue; }
	override Status leave(ir.If, Sink sink) { assert(false); }
	override Status leave(ir.For, Sink sink) { assert(false); }
}
