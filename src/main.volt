// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
/**
 * Holds the main function and some small test code.
 */
module main;

import diode.interfaces;


int main(string[] args)
{
	test();
	return 0;
}


/*
 *
 * A bunch of test code.
 *
 */

import watt.io;
import watt.text.sink;
import diode.eval;
import diode.driver;
import diode.parser : parse;
import diode.interfaces;


void test()
{
	auto s = new Settings();
	s.workDir = "example";
	s.fillInDefaults();

	auto d = new DiodeDriver(s);
	d.addLayout(defaultHtmlFile, "default.html");
	d.addLayout(pageHtmlFile, "page.html");

	d.renderFile(testMdFile, "test.md");
}

enum string testMdFile = `---
layout: page
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

enum string pageHtmlFile = `---
layout: default
---
<article>
{{ content }}
</article>
`;

enum string defaultHtmlFile = `<!DOCTYPE html>
<html lang="en">
  <body>
{{ content }}
  </body>
</html>`;
