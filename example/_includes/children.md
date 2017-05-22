{%-

assign p = include.parent -%}{%-

unless p.all
	%} { }
{%
else
	%}
{
{%
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
endif
-%}
