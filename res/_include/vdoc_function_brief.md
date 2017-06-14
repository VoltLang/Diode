
{%- assign f = include.function -%}

fn {{ f.name }}(
{%- for arg in f.args -%}
	{{- arg.type -}}
	{%- unless forloop.last %}, {% endunless %}
{%- endfor %}) {% for r in f.rets -%}
	{{- r.type -}}
{%- endfor %};
