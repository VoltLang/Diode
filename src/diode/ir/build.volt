// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.ir.build;

import ir = diode.ir;


ir.File bFile()
{
	return new ir.File();
}

ir.Print bPrint(ir.Exp e)
{
	return new ir.Print(e);
}

ir.Text bText(string str)
{
	return new ir.Text(str);
}

ir.For bFor(string ident, ir.Exp exp, ir.Node[] nodes)
{
	return new ir.For(ident, exp, nodes);
}

ir.If bIf(ir.Exp exp, ir.Node[] nodes)
{
	return new ir.If(exp, nodes);
}

ir.Access bAccess(ir.Exp exp, string key)
{
	return new ir.Access(exp, key);
}

ir.Ident bIdent(string ident)
{
	return new ir.Ident(ident);
}


ir.Print bPrintChain(string start, string[] idents...)
{
	return new ir.Print(bChain(start, idents));
}

ir.Exp bChain(string start, string[] idents...)
{
	ir.Exp exp = bIdent(start);
	foreach(ident; idents) {
		exp = bAccess(exp, ident);
	}
	return exp;
}
