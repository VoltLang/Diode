// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.main;

import watt.io : writefln;


int main(string[] args)
{
	auto tokens = lex(text);
	foreach (t; tokens) {
		writefln("%s '%s'", t.kind, t.value);
	}
	return 0;
}


/*
 *
 * A bunch of test code.
 *
 */

import diode.token.lexer;
import ir = diode.ir;
import diode.ir.build;
import diode.eval;

void test()
{
	Set set = buildInbuilt();
	auto e = new Engine(set);

	auto f = buildTest();
	f.accept(e);
}

Set buildInbuilt()
{
	auto base = new Set();
	auto site = new Set();
	base.ctx["site"]  = site;
	site.ctx["base"]  = new Text("http://helloworld.com");
	auto p1 = new Set();
	p1.ctx["title"]   = new Text("The Title");
	p1.ctx["content"] = new Text("the content");
	auto p2 = new Set();
	p2.ctx["title"]   = new Text("Another Title");
	p2.ctx["content"] = new Text("the content");
	auto p3 = new Set();
	p3.ctx["title"]   = new Text("The last Title");
	p3.ctx["content"] = new Text("the content");
	site.ctx["posts"] = new Array(p1, p2, p3);
	return base;
}


enum string text = `---
layout: default
title: Test
---
### Header

Some text here

{% for post in site.posts %}
#### {{ post.title }}
{{ post.content }}

ender
{% endfor %}
`;

ir.File buildTest()
{
	auto f = bFile();
	f.nodes ~= bText(part1);
	f.nodes ~= bFor("post", bChain("site", "posts"),
		[cast(ir.Node)bText(part2),
		bPrintChain("post", "title"),
		bText(part3),
		bPrintChain("post", "content"),
		bText(part4),
		]);
	f.nodes ~= bChain("site", "base");
	f.nodes ~= bText("foof");
	return f;
}

enum string part1 =
`### Header

Some text here

`;

enum string part2 =
`
#### `;

enum string part3 =
`
`;

enum string part4 =
`

ender
`;
