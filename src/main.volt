// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
/**
 * Holds the main function and some small test code.
 */
module main;

import diode.licence;
import diode.interfaces;


fn main(args : string[]) i32
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
import watt.io.file : read, exists, searchDir, isDir;
import watt.path : dirSeparator;
import watt.text.sink;
import diode.eval;
import diode.driver;
import diode.parser : parse;
import diode.interfaces;


fn test()
{
	s := new Settings();
	s.sourceDir = "example";
	s.outputDir = "output";
	s.fillInDefaults();

	d := new DiodeDriver(s);
	d.addLayouts();
	d.addVdocs();

	d.renderFile(testHtmlFile, "test.html");
}

fn addLayouts(d: Driver)
{
	dir := d.settings.layoutDir;
	if (!exists(dir) || !isDir(dir)) {
		error.writefln("dir not found '%s'", dir);
		return;
	}

	fn hit(file: string) {
		if (isDir(file)) {
			return;
		}
		fullpath := dir ~ dirSeparator ~ file;
		str := cast(string)read(fullpath);
		d.addLayout(str, file);

		error.writefln("added layout '%s'", fullpath);
	}

	searchDir(dir, "*.html", hit);
}

fn addVdocs(d: Driver)
{
	dir := d.settings.vdocDir;
	if (!exists(dir) || !isDir(dir)) {
		error.writefln("dir not found '%s'", dir);
		return;
	}

	fn hit(file: string) {
		if (isDir(file)) {
			return;
		}
		fullpath := dir ~ dirSeparator ~ file;
		str := cast(string)read(fullpath);
		d.addDoc(str, file);

		error.writefln("added vdoc '%s'", fullpath);
	}

	searchDir(dir, "*.json", hit);
}


enum testHtmlFile = `---
layout: default
title: Test
---
<span class='indexcommand page'>
	<span class='listname'>Getting Started</span>
	<span class='listsearch'>Getting Started</span>
</span>
{%- for mod in doc.modules -%}
<span class='indexcommand mod'>
	<span class='listname'>module {{ mod.name }}</span>
	<span class='listsearch'>{{ mod.name }}</span>
</span>
{%- endfor -%}
{%- for mod in doc.modules -%}
{%- for class in mod.classes -%}
<span class='indexcommand class'>
	<span class='listname'>class {{ mod.name }}.{{ class.name }} { }</span>
	<span class='listsearch'>{{ mod.name }}.{{ class.name }}</span>
</span>
{%- endfor -%}
{%- endfor -%}
{%- for mod in doc.modules -%}
{%- for func in mod.functions -%}
<span class='indexcommand fn'>
	<span class='listname'>fn {{ mod.name }}.{{ func.name }}(
{%- for arg in func.args -%}
{{- arg.type -}}
{%- unless forloop.last %}, {% endif -%}
{%- endfor %}) {% for r in func.rets -%}
{{- r.type -}}
{%- endfor -%}
{%- if func.hasBody %} { }{% endif -%}
{%- unless func.hasBody -%};{% endif -%}
</span>
	<span class='listsearch'>{{ mod.name }}.{{ func.name }}</span>
</span>
{%- endfor -%}
{%- endfor -%}
`;

enum string testMdFile = r"---
layout: page
title: Test
---
### Header

Some text here

{% for mod in doc.modules %}
```
module {{ mod.name }}

{%


for e in mod.enums
%}{% if forloop.first %}
{% endif %}enum {{ e.name }}
{

}
{% unless forloop.last %}
{% endif %}{% endfor %}{%


for u in mod.unions
%}{% if forloop.first %}
{% endif %}union {{ u.name }}
{

}
{% unless forloop.last %}
{% endif %}{% endfor %}{%


for s in mod.structs
%}{% if forloop.first %}
{% endif %}struct {{ s.name }}
{

}
{% unless forloop.last %}
{% endif %}{% endfor %}{%


for c in mod.classes
%}{% if forloop.first %}
{% endif %}class {{ c.name }}
{

}
{% unless forloop.last %}
{% endif %}{% endfor %}{%


for v in mod.variables
%}{% if forloop.first %}
{% endif %}{{ v.name }}: {{ v.type }};
{% endfor %}{%


for f in mod.constructors
%}{% if forloop.first %}
{% endif %}fn {{ f.name }}();
{% endfor %}{%


if mod.destructors
%}
~this();
{% endif %}{%


for f in mod.functions
%}{% if forloop.first %}
{% endif %}fn {{ f.name }}({%
for arg in f.args %}{{ arg.type
}}{% unless forloop.last %}, {% endif %}{% endfor %}) {%
for r in f.rets %}{{ r.type }}{% endfor %};
{% endfor %}```



{% endfor %}
";
