[comment {-*- tcl -*- manpage fragment for filter method, shared by nx::Object and nx::Class}]

[keywords "method filter"]

[call [arg [vset CMD]] [const [vset MODIFIER]] [method filters] [arg submethod] [opt "[arg arg] ..."]]

Accesses and modifies the list of methods which are registered as
[term "filter"]s with [arg [vset CMD]] using a specific setter or getter 
[arg submethod]:

[list_begin definitions]

[def "[arg [vset CMD]] [const [vset MODIFIER]] [method {filters add}] [arg spec] [opt [arg index]]"]
Inserts a single [term "filter"] into the current list of [term "filter"]s of [arg [vset CMD]]. Using [arg index], a position in the existing list of [term "filter"]s for inserting the new [term "filter"] can be set. If
omitted, [arg index] defaults to the list head (0).

[def "[arg [vset CMD]] [const [vset MODIFIER]] [method {filters clear}]"]
Removes all [term "filter"]s from [arg [vset CMD]] and returns the list of removed [term "filter"]s. Clearing
is equivalent to passing an empty list for [arg filterSpecList] to
[const [vset SCOPE]] [method {filter set}].

[def "[arg [vset CMD]] [const [vset MODIFIER]] [method {filters delete}] [opt [option -nocomplain]] [arg specPattern]"]
Removes a single [term "filter"] from the current list of [term "filter"]s of
[arg [vset CMD]] whose spec matches [arg specPattern]. [arg specPattern] can
contain special matching chars (see [cmd "string match"]). [const [vset SCOPE]] [method "filters delete"] will
throw an error if there is no matching [term "filter"], unless
[option -nocomplain] is set.

[def "[arg [vset CMD]] [const [vset MODIFIER]] [method {filters get}]"]
Returns the list of current [term "filter specification"]s registered for [arg [vset CMD]].

[def "[arg [vset CMD]] [const [vset MODIFIER]] [method {filters guard}] [arg methodName] [opt [arg expr]]"]

If [arg expr] is specified, registers a guard expression [arg expr] with a filter [arg methodName]. This requires that the filter [arg methodName] has been previously set using [const [vset MODIFIER]] [method {filters set}] or added using
[const [vset MODIFIER]] [method {filters add}]. [arg expr] must be a valid Tcl expression (see
[cmd expr]). An empty string for [arg expr] will clear the currently registered
guard expression for filter [arg methodName].

[para]

If [arg expr] is omitted, returns the guard expression set on the
[term "filter"] [arg methodName] defined for [arg [vset CMD]]. If none
is available, an empty string will be returned.

[def "[arg [vset CMD]] [const [vset MODIFIER]] [method "filters methods"] [opt [arg pattern]]"]

If [arg pattern] is omitted, returns all filter names which are
defined by [arg [vset CMD]]. By specifying [arg pattern], the returned
filters can be limited to those whose names match [arg patterns] (see
[cmd "string match"]).

[def "[arg [vset CMD]] [const [vset MODIFIER]] [method {filters set}] [arg filterSpecList]"]

[arg filterSpecList] takes a list of [term "filter"] specs, with each spec being itself either a
one-element or a two-element list: [arg methodName] ?-guard [arg guardExpr]?. [arg methodName] identifies
an existing method of [arg [vset CMD]] which becomes
registered as a filter. If having three elements, the third
element [arg guardExpr] will be stored as a guard expression of the
[term "filter"]. This guard expression must be a valid Tcl expression
(see [cmd expr]). [arg expr] is evaluated when [arg [vset CMD]] receives a message to determine whether the
filter should intercept the message. Guard expressions
allow for realizing context-dependent or conditional filter
composition.


[list_end]
Every [arg methodName] in a [arg spec] must resolve to an existing method in
the scope of the [vset SCOPE]. To
access and to manipulate the list of [term "filter"]s of [arg [vset CMD]], 
[method cget]|[method configure] [option -[join [list {*}[vset MODIFIER] filters] -]] can also be used.
