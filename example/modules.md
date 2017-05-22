---
layout: page
title: Test
---
### Header

Some text here

{% for mod in doc.modules %}
```
module {{ mod.name }}

{%


for e in mod.enumdecls
%}{% if forloop.first %}
{% endif %}enum {{ e.name }};
{% endfor %}{%


for e in mod.enums
%}{% if forloop.first %}
{% endif %}enum {{ e.name }}
{%- include enumdecls.md decls=e.all -%}
{% unless forloop.last %}
{% endif %}{% endfor %}{%


for u in mod.unions
%}{% if forloop.first %}
{% endif %}union {{ u.name }}
{%- include children.md parent=u -%}
{% unless forloop.last %}
{% endif %}{% endfor %}{%


for s in mod.structs
%}{% if forloop.first %}
{% endif %}struct {{ s.name }}
{%- include children.md parent=s -%}
{% unless forloop.last %}
{% endif %}{% endfor %}{%


for c in mod.classes
%}{% if forloop.first %}
{% endif %}class {{ c.name }}
{%- include children.md parent=c -%}
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
