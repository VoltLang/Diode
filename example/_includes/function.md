
{%- assign f = include.function -%}

fn {{ f.name }}(
{%- for arg in f.args -%}
	{{- arg.type -}}
	{%- unless forloop.last %}, {% endif %}
{%- endfor %}) {% for r in f.rets -%}
	{{- r.type -}}
{%- endfor %};
