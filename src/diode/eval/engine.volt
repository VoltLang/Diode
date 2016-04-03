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

		// Setup new env and loop over nodes.
		env = myEnv;
		foreach(elm; arr) {
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
	override Status leave(ir.For, Sink sink) { assert(false); }
}
