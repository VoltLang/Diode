// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diod.eval.engine;

import watt.io;

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
	void sink(const(char)[] str)
	{
		writef("%s", str);
	}

	void print(ir.Node n)
	{
		n.accept(this);
		if (v !is null) {
			v.toText(n, sink);
			v = null;
		}
	}

	override Status visit(ir.Text t)
	{
		sink(t.text);
		return Continue;
	}

	override Status leave(ir.Print f)
	{
		v.toText(f, sink);
		v = null;
		return Continue;
	}

	override Status enter(ir.For f)
	{
		// Eval expression
		// for post in 'site.url'
		v = null;
		f.exp.accept(this);
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
				n.accept(this);
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

	override Status leave(ir.Access p)
	{
		assert(v !is null);
		v = v.ident(p, p.ident);
		return Continue;
	}

	override Status visit(ir.Ident p)
	{
		v = env.ident(p, p.ident);
		return Continue;
	}


	/*
	 *
	 * Dead
	 *
	 */

	override Status enter(ir.File) { return Continue; }
	override Status leave(ir.File) { return Continue; }
	override Status enter(ir.Access) { return Continue; }
	override Status enter(ir.Print) { return Continue; }
	override Status leave(ir.For) { assert(false); }
}
