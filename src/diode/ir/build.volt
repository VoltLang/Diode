// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.ir.build;

import ir = diode.ir;


fn bFile() ir.File
{
	return new ir.File();
}

fn bPrint(e : ir.Exp) ir.Print
{
	return new ir.Print(e);
}

fn bText(str : string) ir.Text
{
	return new ir.Text(str);
}

fn bAssign(ident : string, exp : ir.Exp) ir.Assign
{
	return new ir.Assign(ident, exp);
}

fn bInclude(filename : string, assigns : ir.Assign[]) ir.Include
{
	return new ir.Include(filename, assigns);
}

fn bFor(ident : string, exp : ir.Exp, nodes : ir.Node[]) ir.For
{
	return new ir.For(ident, exp, nodes);
}

fn bIf(invert : bool, exp : ir.Exp, nodes : ir.Node[], elseNodes : ir.Node[]) ir.If
{
	return new ir.If(invert, exp, nodes, elseNodes);
}

fn bAccess(exp : ir.Exp, key : string) ir.Access
{
	return new ir.Access(exp, key);
}

fn bIdent(ident : string) ir.Ident
{
	return new ir.Ident(ident);
}

fn bPrintChain(start : string, idents : string[]...) ir.Print
{
	return new ir.Print(bChain(start, idents));
}

fn bChain(start : string, idents : string[]...) ir.Exp
{
	exp : ir.Exp = bIdent(start);
	foreach(ident; idents) {
		exp = bAccess(exp, ident);
	}
	return exp;
}
