{%-

assign p = include.parent -%}{%-

unless p.all
	%} { }
{%
else
	%}
{
{%
	for v in p.variables
		%}	{{ v.name }}: {{ v.type }};
{%
		if forloop.last %}
{%
		endif -%}{%-
	endfor -%}{%-

	for m in p.methods
		%}	{%
		include function.md function=m -%}{%-
	endfor -%}{%-

	for f in p.functions
		%}	static {%
		include function.md function=f -%}{%-
	endfor
	%}}
{%
endif -%}
