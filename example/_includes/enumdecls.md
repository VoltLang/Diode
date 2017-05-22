{% unless include.decls %} { }
{% else %}
{
{% for decl in include.decls
%}	{{ decl.name }},
{% endfor -%}
}
{% endif -%}
