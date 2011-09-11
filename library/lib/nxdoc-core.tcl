# @package nx::doc
# 
# Study for documentation classes for the Next Scripting Langauge
# 
# Compared to the "old" @ docmentation effort, this is a rather
# light-weight structure based on xotcl 2 (next) language
# features. The documentation classes build an (extensible) object
# structure which is used as a basis for some renderers. In general,
# the classes are defined in a way they can be used for
#
#  a) building documentation outside the source code artefacts, or
#
#  b) inside code artefacts (value added method definition commands
#     providing extra arguments for the documentation). The
#     documentation commands could reuse there names/arguments
#     etc. directly from the method definition by issuing these
#     commands inside the method definition methods.
#
# One could provide lint-like features to signal, whether the
# documentation is in sync with actually defined methods (when these
# are available).
#
# @require nx
# @version 0.1
 
package provide nx::doc 1.0
namespace eval ::nx::doc {}

package require nx
package require nx::pp

namespace eval ::nx::doc {
  namespace import -force ::nx::*
  
  # @command ::nx::doc::@
  #
  # The helper proc "@" is a conveniant way for creating new
  # documentation objects with less syntactic overhead.
  #
  # @param class Request an instance of a particular entity class (e.g., ...)
  # @param name What is the entity name (e.g., nx::doc for a package)
  # @param args A vector of arbitrary arguments, provided to the
  # entity when being constructed
  # @return The identifier of the newly created entity object
  
  # @subcommand ::nx::doc::@#foo
  #
  # This is the first subcommand foo of "@"
  # {{{
  # set do 1;
  # }}}
  #
  # @param -param1 do it
  # @param param2 do it a second time
  # @return Gives you a "foo" object

  # @subcommand ::nx::doc::@#bar
  #
  # This is the second subcommand bar of "@"
  #
  # @param -param1 do it
  # @param param2 do it a second time
  # @return Gives you a "bar" object

  proc @ {class name args} {$class new -name $name {*}$args}
 

  # @command ::nx::doc::sorted
  #
  # This proc is used to sort instances by values of a specified
  # attribute. {{{ set 
  # code 1; puts stderr $code; puts stderr [info script]; set l \{x\}
  # }}} Und nun gehen wir in eine zweite Zeile ... und fügen einen Link ein (e.g., {{@object ::nx::doc::@object}})
  #
  # ... um nach einem Zeilenbruch weiterzumachen
  # {{{
  #	\# Some comment
  #	set instances [list [Object new] [Object new]]
  #	::nx::doc::sorted $instances; set l {{{x}}}; # Some comment
  # {{{ }}} 
  #	set instances [list [Object new] [Object new]]
  #	::nx::doc::sorted $instances
  # }}}
  # Here it goes wider ...
    # {{{
  #	set instances [list [Object new] [Object new]]
  #	::nx::doc::sorted $instances
  # }}}
  #
  # @param instances Points to a list of entity instances to sort e.g. {{@object ::nx::doc::@object}}
  # @param sortedBy Indicates the attribte name whose values the sorting will be based on
  # @return A list of sorted documentation entity instances {{{instances of @object}}}
  proc sorted {instances sortedBy} {
    set order [list]
    foreach v $instances {lappend order [list $v [$v eval [list set :$sortedBy]]]}
    set result [list]
    foreach pair [lsort -index 1 $order] {lappend result [lindex $pair 0]}
    return $result
  }

  proc filtered {instances filteredBy} {
    set filtered [list]
    foreach v $instances { 
      if {[$v eval [list expr $filteredBy]]} {
	lappend filtered $v
      }
    }
    return $filtered
  }


  proc sort_by_value {d} {
    set haystack [list]
    dict for {key value} $d {
      lappend haystack [list $key $value]
    }
    return [dict create {*}[concat {*}[lsort -integer -index 1 -decreasing $haystack]]]
  }
    
  proc find_asset_path {{subdir library/lib/nxdoc-assets}} {
      # This helper tries to identify the file system path of the
      # asset ressources.
      #
      # @param -subdir Denotes the name of the sub-directory to look for
      foreach dir $::auto_path {
	set assets [file normalize [file join $dir $subdir]]
	if {[file exists $assets]} {
	  return $assets
	}
      }
    }


  Class create MixinLayer {
    :property {prefix ""}
    :public method init {} {
      set :active_mixins [dict create]
      next
    }
    :public method apply {} {
      if {${:active_mixins} ne ""} {
	puts stderr "Warning: mixin layer has not been revoked!"
	set :active_mixins [dict create]
      }
      foreach mixin [:info children -type [current class]::Mixin] {
	set base "${:prefix}::[namespace tail $mixin]"
	if {[::nsf::object::exists $base]} {
	  set scope [expr {[$mixin scope] eq "object" && \
			       [$base info is class]?"class":""}]
	  dict lappend :active_mixins $base $mixin
	  $base {*}$scope mixin add $mixin
	}
      }
    }

    :public method revoke {} {
      dict for {base mixins} ${:active_mixins} {
	foreach m $mixins {
	  set scope [expr {[$m scope] eq "object" && \
			       [$base info is class]?"class":""}]
	  $base {*}$scope mixin delete $m
	}
      }
      set :active_mixins [dict create]
    }
    
    Class create [current]::Mixin -superclass Class {
      :property {scope class}
    }
  }

  Class create Tag -superclass Class {
    # A meta-class for named documenation entities. It sets some
    # shared properties (e.g., generation rules for tag names based on
    # entity class names, ...). Most importantly, it provides the
    # basic name-generating mechanisms for documentation entities
    # based on properties such as entity name, root namespace, etc.
    #
    # @param tag Defaults to the tag label to be used in comment
    # tags. It may vary from the auto-generated default!
    # @param root_namespace You may choose your own root-level
    # namespace hosting the namespace hierarchy of entity objects

    :property {tag {[string trimleft [string tolower [namespace tail [current]]] @]}}
    :property {root_namespace "::nx::doc::entities"}

    namespace eval ::nx::doc::entities {}

    :public class method normalise {tagpath names} {
      # puts stderr "tagpath $tagpath names $names"
      # 1) verify balancedness of 
      if {[llength $tagpath] != [llength $names]} {
	return [list 1 "Imbalanced tag line spec: '$tagpath' vs. '$names'"]
      }
      
      # 2) expand shortcuts (i.e., nested lists into additional tag
      # path elements) and flatten the tagpath list.
      set expanded [list]
      
      foreach n $names {
	lappend expanded {*}[lrepeat [llength $n] [lindex $tagpath [lsearch -exact $names $n]]]
      }

      return [list 0 [list $expanded [concat {*}$names]]]

    }
    
    :public class method find {
	-strict:switch 
	-all:switch 
	tagpath 
	names 
	{entity ""}} {

      if {[llength $tagpath] != [llength $names]} {
	return [list 1 "Imbalanced tag line spec: '$tagpath' vs. '$names'"]
      }

      # make sure that expansion has been applied (not allowing sub-lists in names!)

      if {[concat {*}$names] ne $names} {
	return [list 1 "Names list contains sub-lists. Not expanded?"]
      }

      set last_axis [expr {$entity ne ""?[$entity info class]:""}]
      set last_name [expr {$entity ne ""?[$entity name]:""}]
      set entity_path [list]
      foreach axis $tagpath value $names {
	if {$entity eq ""} {
	  set cmd [info command @$axis]
	  #
	  # TODO interp-aliasing objects under different command names
	  # is currently not transparent to some ::nsf::* helpers,
	  # such as ::nsf::object::exists. Should this be changed?
	  #
	  if {$cmd ne ""} {
	    set cmd [namespace origin $cmd]
	    set target [interp alias {} $cmd]
	    if {$target ne ""} {
	      set cmd $target
	    }
	  }
	  if {$cmd eq "" || ![::nsf::object::exists $cmd] || ![$cmd info has type Tag]} {
	    return [list 1 "The entity type '@$axis' is not available."]
	  }
	  set entity [@$axis id $value]
	} else {
	  if {$strict && ![::nsf::object::exists $entity]} {
	    return [list 1 "The tag path '$tagpath' -> '$names' points to a non-existing documentation entity: '@$last_axis' -> '$last_name'"]
	  }
      if {$all} {lappend entity_path $entity [$entity name]}
	  set entity [$entity origin]
	  if {[$entity info lookup methods -source application @$axis] eq ""} {
	    return [list 1 "The tag '$axis' is not supported for the entity type '[namespace tail [$entity info class]]'"]
	  }
	  #puts stderr "$entity @$axis id $value"
	  set entity [$entity @$axis id $value]
	  set last_axis $axis
	  set last_name $value
	}
      }

      if {$strict && $entity ne "" && ![::nsf::object::exists $entity]} {
	return [list 1 "The tag path '$tagpath' -> '$names' points to a non-existing documentation entity: '@$last_axis' -> '$last_name'"]
      }
      if {$all} {lappend entity_path $entity [$entity name]}


      return [list 0 [expr {$all?$entity_path:$entity}]]
    }
    
    # @method id 
    #
    # A basic generator for the characteristic ideas, based on the
    # root_namespace, the tag label, and the fully qualified name of
    # the documented entity
    #
    # @param name The name of the documented entity
    # @return An identifier string, e.g., {{{ ::nx::doc::entities::object::ns1::Foo }}}
    # @see tag
    # @see root_namespace

    :public method id {
      -partof_name
      {-scope ""} 
      name
    } {
      set subns [string trimleft [namespace tail [current]] @]
      if {[info exists partof_name]} {
	set partof_name [string trimleft $partof_name :]
	return [join [list [:root_namespace] $subns $partof_name {*}$scope $name] ::]
      } else {
	set name [string trimleft $name :]
	return "[:root_namespace]::${subns}::$name"
      }
    }

    :public method new {
      -part_attribute
      -partof:object,type=::nx::doc::Entity
      -name:any,required 
      args
    } {
      # A refined frontend for object construction/resolution which
      # provides for generating an explicit name, according to the
      # rules specific to the entity type.
      #
      # @param name The of the documented entity
      # @return The identifier of the newly generated or resolved entity object
      # set fq_name [:get_fully_qualified_name $name]
      set ingredients [list]
      if {[info exists partof]} {
	lappend ingredients -partof_name [$partof name]
	lappend ingredients -scope [expr {[info exists part_attribute]?[$part_attribute scope]:""}]
      }
      lappend ingredients $name
      :createOrConfigure [:id {*}$ingredients] -name $name {*}$args
    }
    
    :method createOrConfigure {id args} {
      namespace eval $id {}
      if {[::nsf::object::exists $id]} {
	$id configure {*}$args
      } else {
	:create $id {*}$args
      }
      return $id
    }

    # @method get_unqualified_name
    #
    # @param qualified_name The fully qualified name (i.e., including the root namespace)
    :public method get_unqualified_name {qualified_name} {
      # TODO: danger, tcl-commands in comments
      # similar to \[namespace tail], but the "tail" might be an object with a namespace
      return [string trimleft [string map [list [:root_namespace] ""] $qualified_name] ":"]
    }
    :public method get_tail_name {qualified_name} {
      #return [string trimleft [string map [list ${:tag} ""] [:get_unqualified_name $qualified_name]]  ":"]
      return [join [lrange [concat {*}[split [:get_unqualified_name $qualified_name] "::"]] 1 end] "::"]
    }
  }

  Class create QualifierTag -superclass Tag {
    :method get_fully_qualified_name {name} {
      if {![string match "::*" $name]} {
	error "You need to provide a fully-qualified (absolute) entity name for '$name'."
      }
      return $name
    }

    :public method id {
      -partof_name
      {-scope ""} 
      name
    } {
      if {[info exists partof_name]} {
	#puts stderr "QUALIFIER=[join [list $partof_name $name] ::]"
	#next [join [list $partof_name $name] ::]
	next
      } else {
	set n [:get_fully_qualified_name $name]
#	puts stderr FINALNAME=$n
	next $n
      }
    }

    :public method new {
      -part_attribute
      -partof:object,type=::nx::doc::Entity
      -name:any,required
      args
    } {
      set id_name $name
      if {[info exists partof]} {
	#set name [join [list [$partof name] $name] ::]
	set id_name ::[join [list [[$partof info class] get_tail_name $partof] $name] ::]
      } else {
	set name [:get_fully_qualified_name $name]
      }
      :createOrConfigure [:id $id_name] \
	  {*}[expr {[info exists part_attribute]?"-part_attribute $part_attribute":""}] \
	  {*}[expr {[info exists partof]?"-partof $partof":""}] \
	  -name $name {*}$args
    }
  }

  Class create PartTag -superclass Tag {
    :public method id {partof_name scope name} {
      next [list -partof_name $partof_name -scope $scope -- $name]
    }

    :public method new {	       
      -part_attribute:required
      -partof:object,type=::nx::doc::Entity
      -name:any,required
      args
    } {
      :createOrConfigure [:id [$partof name] [$part_attribute scope] $name] {*}[current args]
    }
  }
  
  # @object ::nx::doc::PartAttribute
  #
  # This special-purpose Attribute variant realises (1) a cumulative
  # value management and (2) support for distinguishing between
  # literal parts (e.g., @author, @see) and object parts (e.g.,
  # \@param).
  #
  # The cumulative value management adds the append() operation which
  # translates into an add(...,end) operation. PartAttribute slots
  # default to append() as their default setter operation. To draw a
  # line between object and literal parts, PartAttribute slots either
  # refer to a part_class (a subclass of Part) or they do not. If a
  # part_class is given, the values will be transformed accordingly
  # before being pushed into the internal storage.

  ::nx::MetaSlot create PartAttribute -superclass ::nx::VariableSlot {

    # @param part_class
    # 
    # The property refers to a concrete subclass of Part which
    # describes the parts being managed by the property.
    :property part_class:optional,class
    :property scope

    :property {pretty_name {[string totitle [string trimleft [namespace tail [current]] @]]}}
    :property {pretty_plural {[string totitle [string trimleft [namespace tail [current]] @]]}}

    # :forward owning_entity_class {% [[:info parent] info parent] }
    :method init args {
      :defaultmethods [list get append]
      :multiplicity 0..n 
      set :incremental true
      # TODO: setting a default value leads to erratic behaviour;
      # needs to be verified -> @author returns ""
      # :default ""
      if {![info exists :scope]} {
	set :scope ""
	regexp -- {@(.*)-.*} [namespace tail [current]] _ :scope
      }
      next
    }
    
    :public method id {domain prop value} {
      #puts stderr "PARTATTRIBUTE-ID: [current args]"
      if {![info exists :part_class]} {
	error "Requested id generation from a simple part property!"
      }
      return [${:part_class} id [$domain name] ${:scope} $value]
    }

    :method require_part {domain prop value} {
      if {[info exists :part_class]} {
	if {[::nsf::is object $value] && \
		[$value info has type ${:part_class}]} {
	  return $value
	}
	  # puts stderr "NEWWWWWW ${:part_class} new \
	  # 	     -name [lindex $value 0] \
	  # 	     -partof $domain \
	  # 	     -part_attribute [current] \
	  # 	     -@doc [lrange $value 1 end]"
	return  [${:part_class} new \
		     -name [lindex $value 0] \
		     -partof $domain \
		     -part_attribute [current] \
		     [lrange $value 1 end]]
	#-@doc [lrange $value 1 end]]
      }
      return $value
    }
    :public method append {domain prop value} {
      :add $domain $prop $value end
    }
    :public method assign {domain prop value} {
      set parts [list]
      foreach v $value {
	lappend parts [:require_part $domain $prop $v]
      }
      next [list $domain $prop $parts]
    }
    :public method add {domain prop value {pos 0}} {
      set p [:require_part $domain $prop $value]
      if {![$domain eval [list info exists :$prop]] || $p ni [$domain $prop]} {
	next [list $domain $prop $p $pos]
      }
      return $p
    }
    :public method delete {domain prop value} {
      next [list $domain $prop [:require_part $domain $prop $value]]
    }
  }
  
  ::nx::MetaSlot create SwitchAttribute -superclass ::nx::VariableSlot {
    :public method init args {
      set :defaultmethods [list get get]
      next
    }
    :public method get {obj prop} {
      set def [expr {[info exists :default]?${:default}:0}]
      if {[$obj eval [list set :$prop]] == $def} {
	return [::nsf::var::set $obj $prop [expr {!$def}]]
      }
      return [next]
    }
  }

  Class create Entity {
    #
    # Entity is the base class for the documentation classes
    #

    # @param name
    #
    # gives you the name (i.e., the Nx object identifier) of the documented entity
    :property name:any,required

    # every Entity must be created with a "@doc" value and can have
    # an optional initcmd 
    #:method objectparameter args {
      #next [list [list @doc:optional __initcmd:initcmd,optional]]
    #}

    :class property current_project:object,type=::nx::doc::@project,0..1
    :public forward current_project [current] %method

    :property partof:object,type=::nx::doc::StructuredEntity
    :property part_attribute:object,type=::nx::doc::PartAttribute
 
    #
    # TODO: the pdata/pinfo/validate combo only makes sense for
    # entities which reflect Tcl program structures -> refactor into a
    # dedicated PEntity class or the like
    #

     :public method get_fqn_command_name {} {
	return ${:name}
      }

    :property pdata
    :public method validate {} {
      if {[info exists :pdata] && \
	      [:pinfo get -default complete status] ne "missing"} {
	if {[[:origin] as_list] eq ""} {
	  :pinfo propagate status mismatch
	  :pinfo lappend validation "Provide a short, summarising description!"
	}
      }
    }
    :public method "pinfo get" {{-default ?} args} {
      if {![info exists :pdata] || ![dict exists ${:pdata} {*}$args]} {
	return $default;
      }
      dict get ${:pdata} {*}$args
    } 
    
    :public method "pinfo exists" args {
      if {![info exists :pdata]} {return 0}
      dict exists ${:pdata} {*}$args
    }
    
    :public method "pinfo lappend" args {
      if {![info exists :pdata]} return;
      dict lappend :pdata {*}$args
    }

    :public method "pinfo set" args {
      if {![info exists :pdata]} return;
      dict set :pdata {*}$args
    }

    
    :public method "pinfo propagate" args {
      set path [dict create {*}[:get_upward_path \
				-attribute {set :name}]]
      foreach p [lreverse [dict keys $path]] {
	#
	# For now, we disallow upstream propagation if the receiving
	# entity is missing ... as this would be pointless ...
	#
	if {[$p pinfo get -default "extra" status] eq "missing"} break;
	$p pinfo set {*}$args
      }
    }
    
    :public method get_upward_path {
      -relative:switch 
      {-attribute {set :name}}
      {-type ::nx::doc::Entity}
    } {
      set path [list]
      if {!$relative} {
	lappend path [list [current] [:eval $attribute]]
      }
      
      if {[info exists :partof] && [${:partof} info has type $type]} {	
	set path [concat [${:partof} [current method] -attribute $attribute -type $type] $path]
      }
      return [concat {*}$path]
    }

    :property @doc:0..* {
      set :incremental 1
      set :positional true
      set :position 1
    }

    :property -class ::nx::doc::PartAttribute @see

    :property -class ::nx::doc::SwitchAttribute @deprecated:boolean {
      set :default 0
    }
    :property -class ::nx::doc::SwitchAttribute @stashed:boolean {
      set :default 0
    }
    :property -class ::nx::doc::SwitchAttribute @c-implemented:boolean {
      set :default 0
    }

    # :property @properties -class ::nx::doc::PartAttribute
    :public method @property {props} {
      foreach prop $props {
	:@$prop
      }
    }

    :property @use {
      :public method assign {domain prop value} {
	# @command nx
	#
	# @use ::nsf::command
	
	# or

	# class.method {X foo}
	#
	# @use {Class foo}
	# @use object.method {Object foo}

	lassign $value pathspec pathnames
	if {$pathnames eq ""} {
	  set pathnames $pathspec
	  # puts stderr PATH=[$domain get_upward_path \
	  # 				    -attribute {[:info class] tag}]
	  # puts stderr "dict create {*}[$domain get_upward_path \
	  # 				    -attribute {[:info class] tag}]"
	  set pathspec [dict create {*}[$domain get_upward_path \
					    -attribute {[:info class] tag}]]
	  set pathspec [dict values $pathspec]
	} else {
	  set pathspec [split $pathspec .]
	}
	lassign [::nx::doc::Tag normalise $pathspec $pathnames] err res
	if {$err} {
	  error "Invalid @use values provided: $res"
	}
	
	lassign $res pathspec pathnames
	#puts stderr "PATHSPEC $pathspec PATHNAMES $pathnames"	
	lassign [::nx::doc::Tag find $pathspec $pathnames] err res
	if {$err} {
	  error "Generating an entity handle failed: $res"
	}
	# puts stderr "NEXT $domain $prop $res"
	next [list $domain $prop $res]
      }
      
    }

    :public method origin {} {
      if {[info exists :@use]} {
	# puts stderr ORIGIN(${:@use})=isobj-[::nsf::object::exists ${:@use}]
	if {![::nsf::object::exists ${:@use}] || ![${:@use} info has type [:info class]]} {
	  error "Referring to a non-existing doc entity or a doc entity of a different type."
	}
	return [${:@use} origin]
      }
      return [current]
    }

    :public method as_list {} {
      if {[info exists :@doc] && ${:@doc} ne ""} {
	set non_empty_elements [lsearch -all -not -exact ${:@doc} ""]
	return [lrange ${:@doc} [lindex $non_empty_elements 0] [lindex $non_empty_elements end]]
      }
    }

    # @method as_text
    #
    # text is used to access the content of doc of an Entity, and
    # performs substitution on it.  The substitution is not essential,
    # but looks for now convenient.

    :public method as_text {} {
      set doc [list]
      set lines [:as_list]
      foreach l $lines {
	lappend doc [string trimleft $l]
      }
      return [subst [join $doc " "]]
    }
  }

  Tag create @glossary -superclass Entity {
    :property @pretty_name
    :property @pretty_plural
    :property @acronym
  }


  Class create StructuredEntity -superclass Entity {

    :public method part_attributes {} {
      set slots [:info lookup slots]
      set attrs [list]
      foreach s $slots {
	if {![$s info has type ::nx::doc::PartAttribute] || ![$s eval {info exists :part_class}]} continue;
	lappend attrs $s [$s part_class]
      }
      return $attrs
    }

    :public method owned_parts {
	{-class:object "::nx::Object"}
	-where
      } {
      set __owned_parts [dict create]
      foreach {s cls} [:part_attributes] {
	#
	# Note: For the time being, we skip over the bottom-most level of
	# entities, i.e. those which are not structured entities
	# themselves.
	#
	if {[info exists class] && \
		[[$s part_class] info superclass -closure $class] eq ""} continue;
	set accessor [$s name]
	if {[info exists :$accessor]} {
	  set items [sorted [:$accessor] name]
	  if {[info exists where]} {
	    set l [list]
	    foreach i $items {
	      if {[$i eval [list expr $where]]} {
		lappend l $i
	      }
	    }
	    set items $l
	  }
	  if {$items ne ""} {
	    dict set __owned_parts $s $items
	  }
	}
      }
      return $__owned_parts
    }
    
    :public method validate {} {
      next
      dict for {s entities} [:owned_parts -where "!\${:@stashed}"] {
	foreach e $entities {
	  # TODO: for now, it is sufficient to escape @use chains
	  # here. review later ...
	  if {![$e eval {info exists :@use}]} {
	    $e [current method]
	  }
	}
      } 
    }
  }


  Class create ContainerEntity -superclass StructuredEntity {
    
    Class create [current]::Resolvable {
      :class property container:object,type=[:info parent]
      :method get_fully_qualified_name {name} {
	set container [[current class] container]
	if {![string match "::*" $name]} {
#	  puts -nonewline stderr "--- EXPANDING name $name"
	  set name [$container @namespace]::$name 
#	  puts stderr " to name $name"
	}
	next $name
      }
    }

    Class create [current]::Containable {
      # TODO: check the interaction of required, per-object property and ::nsf::assertion
      #:object property container:object,type=[:info parent],required
      :property container:object,type=[:info parent]
      :method create args {
	#
	# Note: preserve the container currently set at this callstack
	# level.  [next] will cause the container to change if another
	# container entity is initialised in the following!
	#
	if {[[current class] eval {info exists :container}]} {
	  set container [[current class] container]
	  set obj [next]
	  if {![$obj eval {info exists :partof}]} {
	    $container register $obj
	  }
	  return $obj
	} else {
	  next
	}
      }
      :method create args {
	#
	# Note: preserve the container currently set at this callstack
	# level.  [next] will cause the container to change if another
	# container entity is initialised in the following!
	#
	if {[info exists :container]} {
	  set cont ${:container}
	  set obj [next]
	  if {![$obj eval {info exists :partof}]} {
	    $cont register $obj
	  }
	  return $obj
	} else {
	  next
	}
      }

    }
    # Note: The default "" corresponds to the top-level namespace "::"!
    :property {@namespace ""}

    :property -class ::nx::doc::PartAttribute @class {
      :pretty_name "Class"
      :pretty_plural "Classes"
      set :part_class ::nx::doc::@class
    }

    :property -class ::nx::doc::PartAttribute @object {
      :pretty_name "Object"
      :pretty_plural "Objects"
      set :part_class ::nx::doc::@object
    }
   
    :property -class ::nx::doc::PartAttribute @command {
      :pretty_name "Command"
      :pretty_plural "Commands"
      set :part_class ::nx::doc::@command
    }

    # :property @class:object,type=::nx::doc::@class,multivalued {
    #   set :incremental 1
    # }

    # :property @object:object,type=::nx::doc::@object,multivalued {
    #   set :incremental 1
    # }

    # :property @command:object,type=::nx::doc::@command,multivalued {
    #   set :incremental 1
    # }

    # :method init {} {
    #   next

    #   QualifierTag mixin add [current class]::Resolvable
    #   [current class]::Resolvable container [current]
    #   foreach {attr part_class} [:part_attributes] {
    #   	$part_class class mixin add [current class]::Containable
    #   	$part_class container [current]
    #   }
    # }

    :method destroy {} {
      foreach {attr part_class} [:part_attributes] {
	#$part_class class mixin add [current class]::Containable
	if {[$part_class eval {info exists :container}] && \
		[$part_class container] eq [current]} {
	  $part_class eval {unset :container}
	}
      }
      next
    }

    :public method register {containable:object,type=::nx::doc::Entity} {
      set tag [[$containable info class] tag]
      if {[:info lookup methods -source application "@$tag"] ne ""} {
	:@$tag $containable
      }
    }
  }

  Tag create @project -superclass ContainerEntity {

    :property sandbox:object,type=::nx::doc::Sandbox
    :property sources

    :property url
    :property license
    :property creationdate
    :property {version ""}
    
    :property {is_validated 0} 
    :property depends:0..*,object,type=[current]
    
    :property -class ::nx::doc::PartAttribute @glossary {
      set :part_class ::nx::doc::@glossary
      :public method get {domain prop} {
	set l [next]
	if {[$domain eval {info exists :depends}]} {
	  foreach d [$domain depends] {
	    lappend l {*}[$d $prop]
	  }
	}
	return [lsort -unique $l]
      }
    }

    :property -class ::nx::doc::PartAttribute @package {
      :pretty_name "Package"
      :pretty_plural "Packages"
      set :part_class ::nx::doc::@package
    }

    :public method destroy {} {
      #
      # TODO: Using the auto-cleanup feature in [Test case ...] does
      # not respect explicit destroy along object relations. Turn the
      # test environment more passive by checking for the existance
      # before calling destroy!
      #
      if {[info exists :sandbox] && [::nsf::object::exists ${:sandbox}]} {
	${:sandbox} destroy
      }
      :current_project ""
      next
    }

    :method init {} {
      #
      # TODO: the way we provide the project as a context object to
      # all entities is not easily restricted. Review later ...
      # 
      :current_project [current]; # sets a per-class-object variable on Entity!
      next
    }
  }

  #
  # Now, define some kinds of documentation entities. The toplevel
  # docEntities are named objects in the ::nx::doc::entities namespace
  # to ease access to it.
  #
  # For now, we define here the following toplevel docEntities:
  #
  # - @package 
  # - @command
  # - @object
  # - ...
  #
  # These can contain multiple parts.
  #  - @method
  #  - @param
  #  - ...
  #

  Tag create @package -superclass ContainerEntity {
    :property -class ::nx::doc::PartAttribute @require
    :property -class ::nx::doc::PartAttribute @version
  }

  QualifierTag create @command -superclass StructuredEntity {
    :property -class ::nx::doc::PartAttribute @parameter {
      set :part_class ::nx::doc::@param
    }
    :property -class ::nx::doc::PartAttribute @return {
      :method require_part {domain prop value} {
	set value [expr {![string match ":*" $value] ? "__out__: $value": "__out__$value"}]
	next [list $domain $prop $value]
      }
      set :part_class ::nx::doc::@param
    }

    :public forward @sub-command %self @command

    :property -class ::nx::doc::PartAttribute @command {
      :pretty_name "Subcommand"
      :pretty_plural "Subcommands"
      :public method id {domain prop value} { 
	# TODO: [${:part_class}] resolves to the property slot
	# object, not the global @command object. is this intended, in
	# line with the intended semantics?
	return [${:part_class} [current method] \
		    -partof_name [$domain name] \
		    -scope ${:scope} -- $value]
      }
      set :part_class ::nx::doc::@command
    }

    :public method validate {} {
      if {[info exists :pdata] && \
	      [:pinfo get -default complete status] ne "missing"} {

	if {![info exists :@command]} {
	  set params [list]
	  set param_names [list]
	  if {[info exists :@parameter]} {
	    foreach p [:@parameter] {
	      set value [$p name]
	      lappend param_names $value
	      if {[$p eval {info exists :default}] || $value eq "args" } {
		set value "?$value?"
	      }
	      lappend params $value
	    }
	  }
	  
	  set ps [:pinfo get -default "" bundle parameter]
	  dict for {actualparam paraminfo} $ps {
	    if {$actualparam ni $param_names} {
	      set p [:@parameter $actualparam]
	      $p pdata [lappend paraminfo status missing]
	    }
	  }
	} 

	if {![:pinfo exists bundle parametersyntax]} {
	  :pinfo set bundle parametersyntax $params
	}
	
	# Note: [next] will cause the missing parameter created to
	# be validated and will have the appropriate status
	# propagated upstream!
	next
      }
    }
  }
  
  QualifierTag create @object \
      -superclass StructuredEntity \
      -mixin ContainerEntity::Containable {

	:property -class ::nx::doc::PartAttribute @author 

	:public forward @object %self @child-object

	:property -class ::nx::doc::PartAttribute @child-object {
	  set :part_class ::nx::doc::@object
	  :public method id {domain prop value} {
#	    puts stderr "CHILD-OBJECT: [current args]"
	    # if {![info exists :part_class]} {
	    #   error "Requested id generation from a simple part property!"
	    # }
	    return [${:part_class} id [join [list [$domain name] $value] ::]]
#	    return [${:part_class} id -partof_name [$domain name] -scope ${:scope} $value]
	  }

	}

	:public forward @class %self @child-class

	:property -class ::nx::doc::PartAttribute @child-class {
	  set :part_class ::nx::doc::@class
	  :public method id {domain prop value} {
	    #puts stderr "CHILD-CLASS: [current args]"
	    # if {![info exists :part_class]} {
	    #   error "Requested id generation from a simple part property!"
	    # }
	    return [${:part_class} id [join [list [$domain name] $value] ::]]
	    #return [${:part_class} id -partof_name [$domain name] -scope ${:scope} $value]
	  }
	}

	:public forward @method %self @object-method

	:property -class ::nx::doc::PartAttribute @object-method {
	  :pretty_name "Object method"
	  :pretty_plural "Object methods"
	  set :part_class ::nx::doc::@method
	}

	:public forward @property %self @object-property
	#:forward @param %self @object-param

	:property -class ::nx::doc::PartAttribute @object-property {
	  set :part_class ::nx::doc::@param
	}

	:method undocumented {} {
	  # TODO: for object methods and class methods
	  if {![::nsf::object::exists ${:name}]} {return ""}
	  foreach m [${:name} info methods -callprotection public] {set available_method($m) 1}
	  set methods ${:@method}
	  if {[info exists :@param]} {set methods [concat ${:@method} ${:@param}]}
	  foreach m $methods {
	    set mn [namespace tail $m]
	    if {[info exists available_method($mn)]} {unset available_method($mn)}
	  }
	  return [lsort [array names available_method]]
	}
      }

  QualifierTag create @class \
      -superclass @object {

	:property -class ::nx::doc::PartAttribute @superclass
	
	:public forward @property %self @class-property

	:property -class ::nx::doc::PartAttribute @class-property {
	  :pretty_name "Per-class attribute"
	  :pretty_plural "Per-class attributes"
	  set :part_class ::nx::doc::@param
	}
	
	:public forward @class-object-method %self @object-method
	:public forward @class-object-property %self @object-property

	:public forward @hook %self @class-hook

	:property -class ::nx::doc::PartAttribute @class-hook {
	  :pretty_name "Hook method"
	  :pretty_plural "Hook methods"
	  set :part_class ::nx::doc::@method
	}

	:public forward @method %self @class-method

	:property -class ::nx::doc::PartAttribute @class-method {
	  :pretty_name "Provided method"
	  :pretty_plural "Provided methods"
	  set :part_class ::nx::doc::@method
	  :method require_part {domain prop value} {
	    # TODO: verify whether these scoping checks are sufficient
	    # and/or generalisable: For instance, is the scope
	    # requested (from the part_attribute) applicable to the
	    # partof object, which is the object behind [$domain name]?
	    
	    # TODO: disable for the moment ... how to rewrite to fit
	    # the sandboxed environment?
	    #	    if {[info exists :scope] && 
	    #		![::nsf::is ${:scope} [$domain name]]} {
	    #	      error "The entity '[$domain name]' does not qualify as '${:scope}'"
	    #	    }
	    next
	  }
	}
	:public method validate {} {
	  next
	  #
	  # TODO: Certain metadata could also be valid in "missing"
	  # state, e.g., paramtersyntax? Re-arrange later ...
	  #
	  if {[info exists :pdata] &&
	      [:pinfo get -default complete status] ne "missing"} {
	    #
	    # Note: Some metadata on classes cannot be retrieved from
	    # within the tracers, as they might not be set local to the
	    # class definition. Hence, we gather them at this point.
	    #
	    set prj [:current_project]
	    set box [$prj sandbox]
	    set statement [list ::nsf::dispatch ${:name} \
		::nsf::methods::class::info::objectparameter \
		parametersyntax]
	    :pinfo set bundle parametersyntax [$box eval $statement]
	  }
	}
      }
  
  Class create PartEntity -superclass Entity {
    :property partof:object,type=::nx::doc::StructuredEntity,required
    :property part_attribute:object,type=::nx::doc::PartAttribute,required
  }
 

  # @object ::nx::doc::@method
  #
  # "@method" is a named entity, which is part of some other
  # docEntity (a class or an object). We might be able to use the
  # "use" parameter for registered aliases to be able to refer to the 
  # documentation of the original method.
  #
  PartTag create @method \
      -superclass StructuredEntity {

	:property -class ::nx::doc::SwitchAttribute @syshook:boolean {
	  set :default 0
	}
	:property -class ::nx::doc::PartAttribute @parameter {
	  set :part_class ::nx::doc::@param
	}
	:property -class ::nx::doc::PartAttribute @return {
	  #
	  # TODO: @return spec fragments should be nameless,
	  # conceptually. They represent "out" parameters with each
	  # @method being allowed to have one only. For now, we fix
	  # this by injecting a dummy name "__out__" which should not
	  # be displayed. I shall fix this later and refactor it to a
	  # shared place between @method and @command.
	  #
	  :method require_part {domain prop value} {
	    set value [expr {![string match ":*" $value] ? "__out__: $value": "__out__$value"}]
	    next [list $domain $prop $value]
	  }
	  set :part_class ::nx::doc::@param
	}

	:public class method new {	       
	  -part_attribute:required
	  -partof:object,type=::nx::doc::Entity
	  -name:any,required
	  args
	} {
	  # 1) Are we in a sub-method?
	  if {[$partof info has type [current]]} {
	    :createOrConfigure [:id [:get_tail_name $partof] "" $name] {*}[current args]
	  } else {
	    next
	  }
	}
	


	:public forward @class-method %self @method
	:public forward @class-object-method %self @method
	:public forward @sub-method %self @method

	:property -class ::nx::doc::PartAttribute @method {
	  set :part_class ::nx::doc::@method
	  :public method id {domain prop name} {
	    # TODO: ${:part_class} resolves to the local slot
	    # [current], rather than ::nx::doc::@method. Why?
	    if {[$domain info has type ::nx::doc::@method]} {
	      set id [::nx::doc::@method id [::nx::doc::@method get_tail_name $domain] "" $name]
	      return $id
	    } else {
	      return [::nx::doc::@method id [$domain name] ${:scope} $name]
	    }
	  }
	}

	:public method get_fqn_command_name {} {
	  set scope [expr {[${:part_attribute} scope] eq "class"?"classes":"objects"}]
	  return ::nsf::${scope}::[string trimleft [[:partof] name] :]::${:name}
	}

	# @method->validate()
	:public method validate {} {
	  set partof [:get_owning_partof]
	  if {[info exists :pdata] &&
	      [:pinfo get -default complete status] ne "missing"} {
	    #
	    # Note: Some information on methods cannot be retrieved from
	    # within the tracers as they might not be set local to the
	    # method definition. Hence, we gather them at this point. I
	    # will review whether there is a more appropriate way of
	    # dealing with this issue ...
	    #
	    set prj [:current_project]
	    set box [$prj sandbox]
	    set obj [$partof name]
	   
	    if {[:pinfo exists bundle handle]} {
	      set handle [:pinfo get bundle handle]
	      :pinfo set bundle redefine-protected [$box eval [list ::nsf::method::property $obj $handle redefine-protected]]
	      :pinfo set bundle call-protected [$box eval [list ::nsf::method::property $obj $handle call-protected]]
	    }
	    
	    set params [list]
	    set param_names [list]
	    if {[info exists :@parameter]} {
	      foreach p [:@parameter] {
		set value [$p name]
		lappend param_names $value
		if {[$p eval {info exists :default}] || $value eq "args" } {
		  set value "?$value?"
		}
		lappend params $value
	      }
	    }
	    
	    dict for {actualparam paraminfo} [:pinfo get -default "" bundle parameter] {
	      if {$actualparam ni $param_names} {
		set p [:@parameter $actualparam]
		$p pdata [lappend paraminfo status missing]
	      }
	    }
	    
	    if {![:pinfo exists bundle parametersyntax]} {
	      :pinfo set bundle parametersyntax $params
	    }
	   
	    # Note: [next] will cause the missing parameter created to
	    # be validated and will have the appropriate status
	    # upstream!
	    next
	  } else {
	    # To realise upward status propagation for submethods, use:
	    # ${:partof} pinfo propagate status mismatch 
	    $partof pinfo propagate status mismatch
	  }
	}
	
	:public method get_sub_methods {} {
	  if {[info exists :@method]} {
	    set leaves [list]
	    foreach m ${:@method} {
	      if {![$m eval {info exists :@method}]} {
		lappend leaves $m
	      } else {
		lappend leaves {*}[$m get_sub_methods]
	      }
	    }
	    return $leaves
	  }
	}

	:public method get_combined {what} {
	  set result [list]
	  if {[info exists :partof] && [${:partof} info has type [current class]]} {
	    set result [${:partof} get_combined $what]
	  }
	  return [lappend result [:$what]]
	}

	:public method get_owning_object {} {
	  return [[:get_owning_partof] name]
	}

	:public method get_owning_partof {} {
	  if {[${:partof} info has type [current class]]} {
	    return [${:partof} [current method]]
	  } else {
	    return ${:partof}
	  }
	}



      }; # @method
  
  # PartTag create @subcommand -superclass {Part @command}
  #  PartTag create @subcommand -superclass {Part @command}

  # @object ::nx::doc::@param
  #
  # The entity type "@param" represents the documentation unit
  # for several parameter types, e.g., object, method, and
  # command parameters.
  #
  PartTag create @param \
      -superclass PartEntity {

	#:property spec
	:property -class ::nx::doc::PartAttribute @spec
	:property default

	:public class method id {partof_name scope name} {
	  next [list [:get_unqualified_name ${partof_name}] $scope $name]
	}
	
	# :class method id {partof_name name} {
	#   # The method contains the parameter-specific name production rules.
	#   #
	#   # @param partof Refers to the entity object which contains this part 
	#   # @param name Stores the name of the documented parameter

	#   set partof_fragment [:get_unqualified_name ${partof_name}]
	#   return [:root_namespace]::${:tag}::${partof_fragment}::${name}
	# }
	
	# @class-object-method new
	#
	# The per-object method refinement indirects entity creation
	# to feed the necessary ingredients to the name generator
	#
	# @param -part_attribute 
	# @param -partof
	# @param -name
	# @param args

	:public class method new {
		-part_attribute 
		-partof:required
		-name:any,required
		args
	      } {
	  lassign $name name def
	  set spec ""
	  regexp {^(.*):(.*)$} $name _ name spec
	  :createOrConfigure [:id $partof [$part_attribute scope] $name] \
	      -@spec $spec \
	      -name $name \
	      -partof $partof \
	      {*}[expr {$def ne "" ? "-default $def" : ""}] \
	      -part_attribute $part_attribute {*}$args
	  
	}

	:public method get_fqn_command_name {} {
	  # ::nx::Object::slot::class
	  if {[${:partof} info has type ::nx::doc::@object]} {
	    return "[${:partof} name]::slot::${:name}"
	  } else {
	    next
	  }
	}

	
	# @param->validate()
	:public method validate {} {
	  #
	  # TODO: For now, we escape from @param validaton on command
	  # parameters. There is no equivalent to [info parameter]
	  # available, so we would need to cook a substitute based on
	  # the parametersyntax. Review later ...
	  #
	  if {${:name} eq "__out__" && \
		  [${:partof} info has type ::nx::doc::@command]} return;

	  #
	  # Here, we escape from any parameter verification for
	  # parameters on forwards & alias, as there is no basis for
	  # comparison!
	  #
	  if {[${:partof} info has type ::nx::doc::@method] && \
		  [${:partof} pinfo get bundle type] in [list forward alias]} {
	    dict set :pdata status ""
	    return;
	  }

	  if {[info exists :pdata] && \
		  [:pinfo get -default complete status] ne "missing"} {
	    
	    # valid for both object and method parameters
	    set pspec [:pinfo get -default "" bundle spec]
	    if {[info exists :spec] && \
		    ${:spec} ne $pspec} {
	      :pinfo propagate status mismatch 
	      :pinfo lappend validation "Specification mismatch. Expected: \
						'${:spec}' Got: '$pspec'."
	    }
	    next
	  } else {
	    ${:partof} pinfo propagate status mismatch 
	  }
	}
      }

  #
  # Provide two interp-wide aliases for @param. This is mere syntactic
  # sugar!
  #
  interp alias {} ::nx::doc::@property {} ::nx::doc::@param
  interp alias {} ::nx::doc::@parameter {} ::nx::doc::@param

  #
  # Providing interp-wide aliases for @glossary. For most processing
  # steps, this is syntactic sugar, however, the aliases cause
  # different rendering behaviour for glossary references and entries.
  #

  interp alias {} ::nx::doc::@gls {} ::nx::doc::@glossary
  interp alias {} ::nx::doc::@Gls {} ::nx::doc::@glossary
  interp alias {} ::nx::doc::@glspl {} ::nx::doc::@glossary
  interp alias {} ::nx::doc::@Glspl {} ::nx::doc::@glossary
  interp alias {} ::nx::doc::@acr {} ::nx::doc::@glossary
  interp alias {} ::nx::doc::@acrfirst {} ::nx::doc::@glossary  

  namespace export CommentBlockParser @command @object @class @package \
      @project @method @property @parameter @ MixinLayer
}



namespace eval ::nx::doc {

  Class create TemplateData {
    
    :class property renderer
    :public forward renderer [current] %method

    :public forward rendered [current] %method
    :class method "rendered push" {e:object,type=::nx::doc::Entity} {
      if {![info exists :__rendered_entity]} {
	set :__rendered_entity [list]
      }
      set :__rendered_entity [concat $e {*}${:__rendered_entity}]
    }

    :class method "rendered pop" {} {
      set :__rendered_entity [lassign ${:__rendered_entity} e]
      return $e
    }

    :class method "rendered top" {} {
      return [lindex ${:__rendered_entity} 0]
    }

    :public method render_start {} {;}
    :public method render_end {} {;}
    
    # This mixin class realises a rudimentary templating language to
    # be used in nx::doc templates. It realises language expressions
    # to verify the existence of variables and simple loop constructs
    :public method render {
      {-initscript ""}
      -theme
      {name:substdefault "[namespace tail [:info class]]"}
    } {
      :rendered push [current]
      # Here, we assume the -nonleaf mode being active for {{{[eval]}}}.
      # set tmplscript [list subst [:read_tmpl $template]]
      set tmplscript [list subst [[:renderer] getTemplate $name \
				      {*}[expr {[info exists theme]?$theme:""}]]]
      #
      # TODO: This looks awkward, however, till all requirements are
      # figured out (as for the origin mechanism) we so keep track
      # of the actual rendered entity ... review later ...
      #
      :render_start
      set content [:eval [subst -nocommands {
	$initscript
	$tmplscript
      }]]
      :render_end
      :rendered pop
      return [string trim $content \n]
    }
    
    
    #
    # some instructions for a dwarfish, embedded templating language
    #
    :method !let {var value} {
      # uplevel 1 [list ::set $var [expr {[info exists value]?$value:""}]]
      uplevel 1 [list ::set $var $value]
      return
    }
    
    :method ! {cmd args} {
      uplevel 1 [list ::$cmd {*}$args]
      return
    }
    
    :public method !get {-sortedby -with -where varname} {
      set origin [:origin]
      if {![$origin eval [list info exists :$varname]]} return
      if {[info exists sortedby]} { 
	set r [uplevel 1 [list ::nx::doc::sorted [$origin eval [list ::set :$varname]] $sortedby]]
      } else {
	set r [uplevel 1 [list $origin eval [list ::set :$varname] ]]
      }
      
      set where_clause "!\${:@stashed}"
      if {[info exists where]} {
	append where_clause "&& $where"
      }
      set l [list]
      foreach item $r {
	if {![::nsf::object::exists $item] || ![$item info has type ::nx::doc::Entity]} {
	  lappend l $item
	} else {
	  if {[[$item origin] eval [list expr $where_clause]]} {
	    lappend l $item
	  }
	}
      }
      set r $l  
      
      if {[info exists with]} {
	set l [list]
	foreach item $r {
	  lappend l [[$item origin] eval [list set :$with]] $item
	}
	set r $l
      }
      
      return $r
    }

    :method for {var list body} { 
      set rendered ""
      ::foreach $var $list {
	uplevel 1 [list ::set $var [set $var]]
	#uplevel 1 [list ::lassign [set $var] {*}$var]
	append rendered [uplevel 1 [list subst $body]]
      }
      return $rendered
    }

    :method ?objvar {obj varname args} {
      uplevel 1 [list :? -ops [list [::nsf::current method] -] \
		     "\[$obj eval {info exists :$varname}\]" {*}$args]
    }

    :public method ?var {varname args} {
      set cmd [expr {[string match ":*" $varname]?"\[[:origin] eval {info exists $varname}\]":"\[info exists $varname\]"}]
      uplevel 1 [list :? -ops [list [::nsf::current method] -] \
		     $cmd {*}$args]
    } 
    :method ? {
      {-ops {? -}}
      expr 
      then
      next:optional 
      args
    } {
      if {[info exists next] && $next ni $ops} {
	return -code error "Invalid control operator '$next', we expect one of $ops"
      }
      if {[uplevel 1 [list expr $expr]]} {
	return [uplevel 1 [list subst $then]]
      } elseif {[info exists next]} {
	if {$next eq "-"} {
	  set args [lassign $args next_then]
	  if {$next_then eq ""} {
	    return -code error "A then script is missing for '-'"
	  }
	  if {$args ne ""} {
	    return -code error "Too many arguments: $args"
	  }
	  return [uplevel 1 [list subst $next_then]]
	}
	return [uplevel 1 [list [current] $next {*}$args]]
      }
    }
    
    :method include {
      -theme
      {name:substdefault "[namespace tail [:info class]]"}
    } {
      uplevel 1 [list subst [[:renderer] getTemplate $name \
				 {*}[expr {[info exists theme]?$theme:""}]]]
    }
    
    :method listing {{-inline true} script} {
      set iscript [join [list [list set inline $inline] [list set script $script]] \n]
      :render -initscript $iscript [current method]
    }
    
    :method link args {
      error "Subclass responsibility: You must provide a method definition of '[current method]' in a proper subclass"
    }
    
    set :markup_map(sub) { 
      "'''" "\[:listing \{" 
      "'''" "\}\]"
      "<<" "\[:link " 
      ">>" "\]" 
    }
    
    set :markup_map(unescape) {
      "\\{" "{"
      "\\}" "}"
      "\\#" "#"
      "\\<" "<"
      "\\>" ">"
      "\\'" "'"
    }
    
    :method unescape {line} {
      set line [string map [[::nsf::current class] eval [list set :markup_map(unescape)]] $line]
    }

    :method map {line} {
      regsub -all -- {('''([^']+?)''')} $line {[:listing {\2}]} line
      regsub -all -- {(<<([^<]+?)>>)} $line {[:link \2]} line
      return $line
    }


    :method as_list {} {
	set preprocessed [list]
	set is_code_block 0
	foreach line [next] {
	  if {(!${is_code_block} && [regsub -- {^\s*(''')\s*$} $line "\[:listing -inline false \{" line]) || \
		  (${is_code_block} && [regsub -- {^\s*(''')\s*$} $line "\}\]" line])} {
	    set is_code_block [expr {!$is_code_block}]
	    append line \n
	  } elseif {${is_code_block}} {
	    # set line [:map $line unescape]
	    append line \n
	  } else {
	    # set line [:map $line sub]
	    # set line [:map $line unescape]
	    set line [string trimleft $line]
	    if {$line eq {}} {
	      set line "\n\n"
	    }
	  } 
	  lappend preprocessed $line
	}
      return $preprocessed
    }

    :public method as_text {} {
      set preprocessed [join [:as_list] " "]
      set preprocessed [:map $preprocessed]
      set preprocessed [:unescape $preprocessed]
      # TODO: For now, we take a passive approach: Some docstrings
      # might fail because they contain substitution characters
      # ($,[]); see nx.tcl. The same goes for legacy xodoc docstrings,
      # and their code listing (see langRef.xotcl). Catching
      # evaluations errors here makes it unnecessary to
      # escape/unescape evaluation chars; at the same time, we can't
      # distinguish errors on unintended and intended evaluations.
      # ...
      if {[catch {set preprocessed [subst $preprocessed]} msg]} {
	puts stderr SELF=[current]
	puts stderr MSG=$msg
	puts stderr IN->$preprocessed
	puts stderr errorInfo->$::errorInfo
      }
      return $preprocessed
    }

  }

  #
  # A Renderer base class ...
  #
  Class create Renderer -superclass MixinLayer {
    
    :property {extension "[namespace tail [current]]"}
    :property extends:object,type=[current]
    
    #
    # mixin-layer management
    #
    
    :method init args {
      set :prefix "::nx::doc"
      next
    }
    
    :public method apply {} {
      if {[info exists :extends]} {
	${:extends} [current method]
      }
      next
    }
    
    :public method revoke {} {
      next
      if {[info exists :extends]} {
	${:extends} [current method]
      }
    }
    
    #
    # template management
    #
    
    :property current_theme
    :protected property {templates {[dict create]}}
    
    :public method addTemplate {name theme body} {
      dict set :templates $theme $name $body
      return $body
    }
    :public method deleteTemplate {name theme} {
      dict remove ${:templates} $theme $name
    }
    :public method getTemplate {
	name 
	{theme:substdefault "${:current_theme}"}
      } {
      if {[dict exists ${:templates} $theme $name]} {
	return [dict get ${:templates} $theme $name]
      } else {
	#
	# 1) if available, read-in template file lazily
	#
	set templateName $name.${:extension}.$theme
	set body [:readAsset $templateName]
	if {$body ne ""} {
	  return [:addTemplate $name $theme $body]
	}
	#
	# 2) resolve the template along the "extends" chain
	#
	if {[info exists :extends]} {
	  return [${:extends} [current method] $name $theme]
	}
	#
	# 3) if ending up here, report a missing template!
	#
	error "The template '$templateName' requested for \
	        renderer '[namespace tail [current]]' is \
		not available."
      }
    }
				
    :method readAsset {assetName} {
      set assetDir [find_asset_path]
      set assetPath [file join $assetDir $assetName]
      return [:read $assetPath]
    }

    :method read {-binary:switch path} {
      if {[file exists $path] && [file isfile $path]} {
	set fh [open $path r]
	if {$binary} {
	  fconfigure $fh -encoding binary -translation binary
	}
	set body [read $fh]
	catch {close $fh}
	return $body
      }
    }

    #
    # rendering
    # 

    :method write {content path} {
      set fh [open $path a]
      puts $fh $content
      catch {close $fh}
    }
    :method remove {{-nocomplain:switch} path} {
      if {![file exists $path] && !$nocomplain} {
	error "Path does not exists: '$path'."
      }
      file delete -force $path
    }

    :method installAssets {project theme targetDir} {
      error "Not implemented. Instance responsibility!"
    }
    
    :method "layout many-to-1" {
      project 
      theme
      {-outdir [::nsf::tmpdir]}
    } {
      set fn [file join $outdir "[$project name].${:extension}"]
      :remove -nocomplain $fn
      
      set values [concat {*}[dict values [$project navigatable_parts]]]
      lappend values $project
      
      set output [list]
      foreach e $values {
	lappend output [:render $project $e $theme]
      }
      :write [join $output \n\n] $fn
      :installAssets $project $theme $fn
      puts stderr "$e written to $fn"
    }
    
    :method "layout many-to-many" {
      project 
      theme
      {-outdir [::nsf::tmpdir]}
    } {
      set ext ${:extension}
      
      #
      # 1) provide a per-project output directory
      #
      set project_path [file join $outdir [string trimleft [$project name] :]]
      :remove -nocomplain $project_path
      
      if {![catch {file mkdir $project_path} msg]} {
	#
	# 2) place the theme-specifc assets into the project directory
	#
	set target $project_path/assets
	:installAssets $project $theme $target

	#
	# 3) Set-up the list of entities to be processed. Note that in
	# this layout, the @project entity is processed along with all
	# the other entities, but *last*.
	#
	set values [concat {*}[dict values [$project navigatable_parts]]]
	lappend values $project

	foreach e $values {
	  #
	  # TODO: For now, in templates we (silently) assume that we act
	  # upon structured entities only ...
	  #
	  set content [:render $project $e $theme @project]
	  :write $content [file join $project_path "[$e filename].$ext"]
	  puts stderr "$e written to [file join $project_path [$e filename].$ext]"
	}
      }
    }

    :method "layout 1-to-1" {
      project
      theme
      {-outdir "[::nsf::tmpdir]"}
    } {      
      set ext ${:extension}
      set fn [file join $outdir "[$project name].$ext"]
      
      :remove -nocomplain $fn
      set content [:render $project $project $theme]
      :installAssets $project $theme $outdir
      :write $content $fn
      puts stderr "$project written to $fn"
    }

    :public method run {
	-project 
	{-layout many-to-many} 
	{-theme yuidoc} 
	args
      } {
      # TODO: Relocate trigger validation!
      $project validate
      # --
      :apply
      :current_theme $theme
      :layout $layout $project $theme {*}$args
      :revoke
    }
    
    :method render {project entity theme {tmplName ""}} {
      error "Not implemented. Instance responsibility!"
    }
  }
}  

#
# sandboxing
#

namespace eval ::nx::doc {
  namespace import -force ::nx::*
  Class create Sandbox {

    :public class method type=in {name value arg} {
      if {$value ni [split $arg |]} {
	error "The value '$value' provided for parameter $name not permissible."
      }
      return $value
    }

    :public class method type=fqn {name value} {
      if {[string first "::" $value] != 0} {
	error "The value '$value' must be a fully-qualified Tcl name."
      }
      return $value
    }

    :public class method type=fpathtype {name value arg} {
      #
      # Note: We might receive empty strings in case of [eval]s!
      #
      set pt [file pathtype $value]
      if {$value ne "" && $pt ne $arg} {
	error "The filepath '$value' must be $arg, rather than $pt."
      }
      return $value
    }

    :public class method type=nonempty {name value} {
      if {$value eq ""} {
	return \
	    -code error \
	    "An empty value is not allowed for parameter '$name'."
      }
      return $value
    }

    :protected property {current_packages "*"}
    :property {permissive_pkgs:1..* "*"} {
      set :incremental 1
    }

    #
    # some callbacks invoked from within the sandbox interp
    #

    :public method "cpackage pop" {} {
      set :current_packages [lrange ${:current_packages} 0 end-1]
    }
    :public method "cpackage push" {p} {
      lappend :current_packages [string tolower $p]
    }
    :public method "cpackage top" {} {
      return [lindex ${:current_packages} end]
    }

    :public method at_source {filepath} {
      set cpackage [:cpackage top]
      if {$cpackage in ${:permissive_pkgs}} {
	lappend :source $cpackage $filepath
      } else {
	dict set :deps $filepath $cpackage
      }
    }

    :public method at_load {filepath} {
      set cpackage [:cpackage top]
      if {$cpackage ne ${:permissive_pkgs}} {
	dict set :deps $filepath $cpackage
      }
    }


    :public method at_register_package {pkg_name version} {
      dict set :registered_packages $pkg_name version $version
    }
#    :public method at_deregister_package {} {
#      set :current_packages [lrange ${:current_packages} 0 end-1]
#    }
    # [list ->status:in,arg=complete|missing|prototype|mismatch,slot=[current] missing]
    :public method at_register_command [list \
	name:fqn,slot=[current] \
	->cmdtype:in,arg=@object|@class|@command|@method,slot=[current] \
        ->source:fpathtype,arg=absolute,slot=[current] \
	{->nsexported:boolean 0} \
	{->nsimported:boolean 0} \
        ->docstring:optional,slot=[current] \
	->bundle
     ] {
      # peek the currently processed package (if any)
      set storable_vars [info vars >*]
      # set cpackage [lindex ${:current_packages} end]
      set cpackage [:cpackage top]
      if {$cpackage in ${:permissive_pkgs}} {
	dict set :registered_commands $name package $cpackage
	foreach svar $storable_vars {
	  dict set :registered_commands $name [string trimleft $svar >] [set $svar]
	}
      }
    }

    :public method at_deregister_command [list name:fqn,slot=[current]] {
      set cpackage [:cpackage top]
      if {$cpackage in ${:permissive_pkgs}} {
	dict unset :registered_commands $name
      }
    }

    :public method init args {
      :do {

	#
	# hide selected built-in Tcl commands and put simple
	# forwarding proxies in place ...
	#
	# TODO: refactor the proxy handling ...
	#
	interp hide "" proc
	interp hide "" namespace
	interp hide "" source
	interp hide "" load
	interp hide "" package
	interp hide "" auto_import

	interp invokehidden "" proc ::proc args {
	  #set ns [uplevel [list interp invokehidden "" namespace current]]
	  uplevel [list interp invokehidden "" proc {*}$args]
	}

	proc ::namespace args {
	  #set ns [uplevel [list interp invokehidden "" namespace current]]
	  #interp invokehidden "" -namespace $ns namespace {*}$args
	  uplevel [list interp invokehidden "" namespace {*}$args]
	}

	proc ::source args {
	  uplevel [list interp invokehidden "" source {*}$args]
	}

	proc ::load args {
	  # set ns [uplevel [list interp invokehidden "" namespace current]]
	  # interp invokehidden "" -namespace $ns load {*}$args
	  uplevel [list interp invokehidden "" load {*}$args]

	}

	proc ::package args {
	  # set ns [uplevel [list interp invokehidden "" namespace current]]
	  # interp invokehidden "" -namespace $ns package {*}$args
	  uplevel [list interp invokehidden "" package {*}$args]
	}

	proc ::auto_import args {
	  # set ns [uplevel [list interp invokehidden "" namespace current]]
	  # interp invokehidden "" -namespace $ns auto_import {*}$args
	  uplevel [list interp invokehidden "" auto_import {*}$args]
	}
	
	namespace eval ::nx::doc {
	  
	  proc is_exported {name} {
	    #
	    # ! ISSUE: The built-in [namespace] command is hidden in our
	    # ! sandbox interp when [is_exported] is used during a
	    # ! 2pass!!!!
	    #
	    set calling_ns [uplevel [list interp invokehidden "" namespace current]]
	    set ns [interp invokehidden "" namespace current]::_?_
	    interp invokehidden "" namespace eval $ns \
		[list interp invokehidden "" namespace import -force $name]
	    set is [expr {[info commands ${ns}::[interp invokehidden "" namespace tail $name]] ne ""}]
	    interp invokehidden "" namespace delete $ns
	    return $is
	  }

	  ::interp invokehidden "" proc ::nx::doc::paraminfo {
		value {default ""}
	      } {
	    set colon [string first : $value]
		set spec ""
		if {$colon == -1} {
		  set name $value
		} else {
		  set spec [string range $value [expr {$colon+1}] end]
		  set name [string range $value 0 [expr {$colon -1}]]
		}
		return [list $name [list $spec $default]]
	      }

	  proc __trace_pkg {} {

	    #    ::interp hide "" source
	    ::proc ::source {path} {
	      set ns [uplevel [list namespace current]]
	      if {[file tail $path] ne "pkgIndex.tcl"} {
		::nx::doc::__at_source [file normalize $path]
	      }
	      uplevel [list interp invokehidden "" source $path]
	    }
	    
	    proc list_commands {{parent ""}} {
	      set ns [dict create]
	      #set cmds [string trim "[join [info commands ${parent}::*] \" 0 \"] 0" 0]
	      #
	      # Note: We trigger a [namespace import] for the
	      # currently processed namespace before requesting the
	      # command list in order to have the auto_load feature
	      # initialise commands otherwise found too late,
	      # i.e. after having computed the [info
	      # commands] snapshot!
	      #
#	      namespace eval ::nx::doc::__x [list namespace import -force ${parent}::*]
	      set cmds [info commands ${parent}::*]

	      set exported [list]
	      foreach cmd $cmds {
		dict set ns ::[string trimleft $parent :] $cmd [is_exported $cmd]
		    
#[expr {[info commands ::nx::doc::__x::[namespace tail $cmd]] ne ""}]
	      }

	      foreach nsp [namespace children ${parent}::] {
		set ns [dict merge $ns [list_commands ${nsp}]]
	      }
	      return $ns
	    }


	    ::proc ::load args {

	      set ns [uplevel [list namespace current]]

	      # 
	      # pre-state
	      #
	      # set pre_loaded [dict values \
	      # 			  [dict create {*}[concat {*}[info loaded ""]]]]
	      set pre_loaded [lreverse [concat {*}[info loaded ""]]]
	      set pre [::nx::doc::list_commands]
	      set pre_commands [dict create {*}[concat {*}[dict values $pre]]]
	      set pre_namespaces [dict keys $pre]

	      interp invokehidden "" -namespace $ns load {*}$args
	      
	      #
	      # post-state
	      #
	      #set post_loaded [dict create {*}[concat {*}[info loaded ""]]]
	      set post_loaded [lreverse [concat {*}[info loaded ""]]]
	      set post [::nx::doc::list_commands]
	      set post_commands [dict create {*}[concat {*}[dict values $post]]]
	      set post_namespaces [dict keys $post]
	      
	      #
	      # deltas
	      #
	      set delta_commands [dict remove $post_commands {*}[dict keys $pre_commands]]

	      set delta_namespaces [dict keys [dict remove [dict create {*}"[join $post_namespaces " _ "] _"] {*}$pre_namespaces]]

	      set delta_pkg [dict remove \
				 [dict create {*}$post_loaded] \
				 [dict keys [dict create {*}$pre_loaded]]]

	      #puts stderr "DELTAS pkg $delta_pkg"
	      #puts stderr "DELTAS namespace $delta_namespaces"
	      #puts stderr "DELTAS commands $delta_commands"
	      
	      lassign $delta_pkg pkg_name filepath
	      set filepath [file normalize $filepath]

	      ::nx::doc::__at_load $filepath

	      # TODO: Temporary hack to reflect that we provide for a
	      # helper objsys to retrieve command parameter specs and
	      # parametersyntax prints.
	      if {[info commands ::nsf::objectsystem::create] ne "" && \
		      [::nsf::configure objectsystem] eq ""} {
		set rootclass ::nx::doc::_%&obj
		set rootmclass ::nx::doc::_%&cls
		::nsf::objectsystem::create $rootclass $rootmclass
	      } else {
		lassign {*}[::nsf::configure objectsystem] rootclass rootmclass
	      }

	      foreach {cmd isexported} $delta_commands {
		set bundle [dict create]
		set infoMethod ::nsf::methods::object::info::method
		if {[::nsf::object::exists $cmd]} {
		  #
		  # TODO: Only classes are provided with parametersyntax
		  # info. Is this sufficient?!
		  #
		  if {[::nsf::is class $cmd]} {

		    dict set bundle parametersyntax [::nsf::dispatch $cmd \
			::nsf::methods::class::info::objectparameter \
			parametersyntax]
		    #
		    # TODO: Are the parameters needed for objects???
		    #
		    # dict set bundle parameter [::nsf::dispatch $cmd \
		    # 	::nsf::methods::class::info::objectparameter \
		    # 	parameter]
		  }
		} else {
		  if {![catch {set syntax [::nsf::dispatch $rootclass $infoMethod \
			 parametersyntax $cmd]} _]} {
		    dict set bundle parametersyntax $syntax
		  }
		  
		  if {![catch {set pa [::nsf::dispatch $rootclass $infoMethod \
					parameter $cmd]} _]} {
		    foreach pspec $pa {
		      dict set bundle parameter {*}[::nx::doc::paraminfo {*}$pspec]
		    }
		  }
		}

		::nx::doc::__at_register_command $cmd \
		    ->cmdtype @command \
		    ->source $filepath \
		    ->nsexported $isexported \
		    ->bundle $bundle
	      }
	    }

	    ::proc ::package {subcmd args} {
	      set ns [uplevel [list namespace current]]
	      set was_registered 0
	      switch -glob -- $subcmd {
		ifneeded {
		  lassign $args pkg_name version script
		  append wrapped_script "::nx::doc::__cpackage push $pkg_name;\n" $script "\n::nx::doc::__cpackage pop;"
		  set args [list $pkg_name $version $wrapped_script]
		  ::nx::doc::__at_register_package $pkg_name $version
		}
	      } 
	      interp invokehidden "" -namespace $ns package $subcmd {*}$args
	      # uplevel [list interp invokehidden "" package $subcmd {*}$args]
#	      if {$was_registered} {
#		::nx::doc::__at_deregister_package
#	      }
	    }

	    #
	    # Note that we have to wrap up Tcl's auto_import due to
	    # our practise of [namespace import]'ing application
	    # namespaces to verify whether commands are actually
	    # exported; see list_commands. Currently, we escape to a
	    # generic package called TCL_LIBRARY to filter out
	    # commands lazily acquired through the auto_load
	    # mechanism, triggered by the [namespace import]
	    # probing.
	    #
	    #::interp hide "" auto_import
	    ::proc ::auto_import {pattern} {
	      set ns [uplevel [list namespace current]]
	      ::nx::doc::__cpackage push TCL_LIBRARY;
	      interp invokehidden "" -namespace $ns auto_import $pattern
	      ::nx::doc::__cpackage pop;
	    }
	  }
	  proc __init {} {
	    # 1) provide for tracing NSF objects
	    if {[info commands ::nsf::configure] ne "" && \
		    [::nsf::configure objectsystem] ne ""} {
	      set objsys [lindex [::nsf::configure objectsystem] 0]
	      set m [lassign $objsys rootclass rootmclass]
	      #
	      # TODO: Temporary hack to reflect that we provide for a
	      # helper objsys to retrieve command parameter specs and
	      # parametersyntax prints.
	      # 
	      if {$rootclass ne "::nx::doc::_%&obj"} {
		
		::nsf::configure keepinitcmd true;
	      
	      array set sysmeths [concat {*}$m]
	      set ::nx::doc::rootns [namespace qualifier $rootmclass]
	      $rootmclass $sysmeths(-class.create) ${::nx::doc::rootns}::__Tracer
	      ::nsf::method::create ${::nx::doc::rootns}::__Tracer \
		  $sysmeths(-class.create) {name args} {
		    set obj [::nsf::next];
		    set bundle [dict create]
		    if {[info commands "::nx::Class"] ne ""} {
		      if {[::nsf::dispatch $obj ::nsf::methods::object::info::hastype ::nx::Slot]} {
			dict set bundle objtype slot
			dict set bundle incremental [expr {[::nsf::dispatch $obj ::nsf::methods::object::info::hastype ::nx::RelationSlot] || ([::nsf::dispatch $obj ::nsf::methods::object::info::hastype ::nx::VariableSlot] && [::nsf::var::exists $obj incremental] && [::nsf::var::set $obj incremental])}]
		      }
		      if {[::nsf::dispatch $obj ::nsf::methods::object::info::hastype ::nx::EnsembleObject]} {
			dict set bundle objtype ensemble
		      }
		      dict set bundle ismetaclass [::nsf::is metaclass $obj]
		    }
	      	    set cmdtype [expr {[::nsf::is class $obj]?"@class":"@object"}]
	      	    ::nx::doc::__at_register_command $obj \
	      		->cmdtype $cmdtype \
	      		->source [file normalize [info script]] \
	      		->nsexported [::nx::doc::is_exported $obj] \
			->bundle $bundle \
	      		{*}[expr {[::nsf::var::exists $obj __initcmd] && [::nsf::var::set $obj __initcmd] ne ""?[list ->docstring [::nsf::var::set $obj __initcmd]]:[list]}]
	      	    return $obj
	      	  }
		# ::nsf::relation $rootmclass class-mixin ${::nx::doc::rootns}::__Tracer
	      
	      if {[info commands "::nx::Object"] ne ""} {
		$rootmclass $sysmeths(-class.create) ${::nx::doc::rootns}::__ObjTracer
		::nsf::method::create ${::nx::doc::rootns}::__ObjTracer \
		    __resolve_method_path {
		      -per-object:switch 
		      -verbose:switch 
		      path
		    } {
		      array set "" [::nsf::next]
		      set l [llength $path]
		      if {$l > 1} {
			set target $(object)
			set objects [list]
			for {set j 1} {$j < [expr {$l-1}]} {incr j} {
			  set target [namespace qualifiers $target]
			  lappend objects $target
			}
			lappend objects [::nsf::current object]
			set first 1
			foreach leg [lrange $path 0 end-1] obj [lreverse $objects] {
			  if {$first} {
			    set scope [expr {${per-object}?"object":"class"}]
			    set first 0
			  } else {
			    set scope object
			  }
			 
			  set handle [::nsf::dispatch $obj \
					  ::nsf::methods::${scope}::info::method \
					  handle $leg]
			  if {![::nsf::var::exists [::nsf::current class] handles] || ![[::nsf::current class] eval [concat dict exists \${:handles} $handle]]} {
			    dict set bundle handle $handle
			    dict set bundle handleinfo [::nx::doc::handleinfo $handle]
			    dict set bundle type [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::${scope}::info::method type $handle]
			    if {![catch {set pa [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::${scope}::info::method parameter $handle]} _]} {
			      foreach pspec $pa {
				dict set bundle parameter {*}[::nx::doc::paraminfo {*}$pspec]
			      }
			    }
			    if {![catch {set psyn [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::${scope}::info::method parametersyntax $handle]} _]} {
			      dict set bundle parametersyntax $psyn
			    }
			    ::nx::doc::__at_register_command $handle \
				->cmdtype @method \
				->source [file normalize [info script]] \
				->bundle $bundle
			    [::nsf::current class] eval [list dict set :handles $handle _]			    
			  }
			}
		      }
		      
		      return [array get ""]
		    }
		::nsf::mixin $rootclass ${::nx::doc::rootns}::__ObjTracer
		#::nsf::relation $rootclass class-mixin ${::nx::doc::rootns}::__ObjTracer
	      }

		::nsf::mixin $rootmclass ${::nx::doc::rootns}::__Tracer

	      }
	      ::interp invokehidden "" proc ::nx::doc::handleinfo {handle} {
		set definition [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method definition $handle]
		if {$definition ne ""} {
		  set obj [lindex $definition 0]
		  set modifier [lindex $definition 2]
		  if {[lindex $definition 1] eq "create"} {
		    set obj $modifier 
		    set scope ""
		    set name ""
		  } elseif {$modifier eq "class"} {
		    set scope $modifier
		    set name [lindex $definition 4]
		  } else {
		    set scope ""
		    set name [lindex $definition 3]
		  }
		}
		if {$scope eq ""} {
		  set is_method 0
		  set obj [concat {*}[split [string trimleft $obj :] "::"]]
		  foreach label $obj {
		    if {$label eq "slot"} {set is_method 1; continue;}
		    if {$is_method} {
		      lappend method_name [string trimleft $label _]
		    } else {
		      lappend obj_name $label
		    }
		  }
		  set name [lappend method_name {*}$name]
		  set obj ::[join $obj_name "::"]
		}
		return [list $obj $scope $name]
	      }
	     

	      rename ::nsf::method::create ::nsf::_%&method 
	      ::interp invokehidden "" proc ::nsf::method::create {
		object
		args
	      } {
		set handle [uplevel [list ::nsf::_%&method $object {*}$args]]
		if {$handle ne ""} {
		  set bundle [dict create]
		  dict set bundle handle $handle
		  dict set bundle handleinfo [::nx::doc::handleinfo $handle]
		  foreach pspec [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method parameter $handle] {
		    dict set bundle parameter {*}[::nx::doc::paraminfo {*}$pspec]
		  }
		  dict set bundle parametersyntax [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method parametersyntax $handle]
		  dict set bundle type [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method type $handle]
		  dict set bundle returns [::nsf::method::property ${::nx::doc::rootns}::__Tracer $handle returns]
		  ::nx::doc::__at_register_command $handle \
		      ->cmdtype @method \
		      ->source [file normalize [info script]] \
		      ->bundle $bundle
		} 
		return $handle
	      }

	      rename ::nsf::method::alias ::nsf::_%&alias 
	      ::interp invokehidden "" proc ::nsf::method::alias {
		args
	      } {
		set handle [uplevel [list ::nsf::_%&alias {*}$args]]
		if {$handle ne ""} {
		  dict set bundle handle $handle
		  dict set bundle handleinfo [::nx::doc::handleinfo $handle]
		  dict set bundle returns [::nsf::method::property ${::nx::doc::rootns}::__Tracer $handle returns]
		  dict set bundle type [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method type $handle]
		  if {![catch {set pa [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method parameter $handle]} _]} {
		    foreach pspec $pa {
		      dict set bundle parameter {*}[::nx::doc::paraminfo {*}$pspec]
		    }
		  }
		  if {![catch {set psyn [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method parametersyntax $handle]} _]} {
		    dict set bundle parametersyntax $psyn
		  }

		  ::nx::doc::__at_register_command $handle \
		      ->cmdtype @method \
		      ->source [file normalize [info script]] \
		      ->bundle $bundle
		} 
		return $handle
	      }

	      	# if {[$object info method type ${:name}] eq "forward"} {
	      	#   set cmd ""
	      	#   foreach w [lrange [$object info method definition ${:name}] 2 end] {
	      	#     if {[string match ::* $w]} {
	      	#       set cmd $w
	      	#       break
	      	#     }
	      	#   }
		#   if {$cmd ne "" && [string match ::nsf::* $cmd]} {
		#     # TODO: we assume here, the cmd is a primitive
	      	#     # command and we intend only to handle cases from
		#     # predefined or xotcl2. Make sure this is working
	      	#     # reasonable for other cases, such as forwards to 
	      	#     # other objects, as well
	      	#     if {![catch {set actualParams [::nx::Object info method parameter $cmd]}]} {
	      	#       # drop usual object
	      	#       set actualParams [lrange $actualParams 1 end]
	      	#       # drop per object ; TODO: always?
	        #             if {[lindex $actualParams 0] eq "-per-object"} {
	      	# 	set actualParams [lrange $actualParams 1 end]
	      	# 	set syntax [lrange [::nx::Object info method parametersyntax $cmd] 2 end]
	      	#       } else {
	      	# 	set syntax [lrange [::nx::Object info method parametersyntax $cmd] 1 end]
	      	#       }
	      	#     }
	      	#   }
		# }
	      
	      
	      rename ::nsf::method::forward ::nsf::_%&forward 
	      ::interp invokehidden "" proc ::nsf::method::forward {
							    args
							  } {
	      	set handle [uplevel [list ::nsf::_%&forward {*}$args]]
	      	if {$handle ne ""} {
	      	  dict set bundle handle $handle
		  dict set bundle handleinfo [::nx::doc::handleinfo $handle]
	      	  dict set bundle type [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method type $handle]
		  if {![catch {set psyn [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method parametersyntax $handle]} _]} {
		    dict set bundle parametersyntax $psyn
		  }

	      	  ::nx::doc::__at_register_command $handle \
	      	      ->cmdtype @method \
	      	      ->source [file normalize [info script]] \
	      	      ->bundle $bundle
	      	} 
		return $handle
	      }

	      rename ::nsf::method::setter ::nsf::_%&setter
	      ::interp invokehidden "" proc ::nsf::method::setter {
	      	args
	      } {
	      	set handle [uplevel [list ::nsf::_%&setter {*}$args]]
	      	if {$handle ne ""} {
	      	  dict set bundle handle $handle
		  dict set bundle handleinfo [::nx::doc::handleinfo $handle]
	      	  dict set bundle type [::nsf::dispatch ${::nx::doc::rootns}::__Tracer ::nsf::methods::object::info::method type $handle]
		  
		  ::nx::doc::__at_register_command $handle \
	      	      ->cmdtype @method \
	      	      ->source [file normalize [info script]] \
		      ->bundle $bundle
	      	}
		return $handle
	      }

	    rename ::nsf::objectsystem::create ::nsf::_%&createobjectsystem 
	      ::interp invokehidden "" proc ::nsf::objectsystem::create {
		rootclass 
		rootmclass 
		args
	      } {
		uplevel [list ::nsf::_%&createobjectsystem $rootclass $rootmclass {*}$args]
		
		foreach r [list $rootclass $rootmclass] {
		  dict set bundle ismetaclass [::nsf::is metaclass $r]
		  ::nx::doc::__at_register_command $r \
		      ->cmdtype @class \
		      ->source [file normalize [info script]] \
		      ->nsexported [::nx::doc::is_exported $r] \
		      {*}[expr {[::nsf::var::exists $r __initcmd] && [::nsf::var::set $obj __initcmd] ne ""?[list ->docstring [::nsf::var::set $r __initcmd]]:[list]}] \
		      ->bundle $bundle
		}
	      }

	    }
	    # 2a) provide for tracing Tcl procs declared at "sourcing time" -> [proc]
	    #::interp hide "" proc
	    ::interp invokehidden "" proc ::proc {name arguments body} {
	      set ns [uplevel [list namespace current]]
	      interp invokehidden "" -namespace $ns proc $name $arguments $body
	      set fqn $name
	      if {[string first "::" $name] != 0} {
		set fqn [string trimright $ns :]::$name
	      }
	      if {$arguments eq "" && $body eq ""} {
		::nx::doc::__at_deregister_command $fqn
	      } else {
		::nx::doc::__at_register_command $fqn \
		    ->cmdtype @command \
		    ->source [file normalize [info script]] \
		    ->nsexported [::nx::doc::is_exported $fqn] \
		    ->docstring $body
	      }

	    }
	    
	    rename ::nsf::proc ::nsf::_%&proc
	    ::interp invokehidden "" proc ::nsf::proc {name arguments body} {
	      set ns [uplevel [list namespace current]]
	      uplevel [list ::nsf::_%&proc $name $arguments $body]	      
	      set fqn $name
	      if {[string first "::" $name] != 0} {
		set fqn [string trimright $ns :]::$name
	      }
	      if {$arguments eq "" && $body eq ""} {
		::nx::doc::__at_deregister_command $fqn
	      } else {
		::nx::doc::__at_register_command $fqn \
		    ->cmdtype @command \
		    ->source [file normalize [info script]] \
		    ->nsexported [::nx::doc::is_exported $fqn] \
		    ->docstring $body
	      }
	    }

	    # 3) provide for tracing commands namespace-imported at "sourcing time"
	    #::interp hide "" namespace
	    ::interp invokehidden "" proc ::namespace {subcmd args} {
	      set ns [uplevel [list interp invokehidden "" namespace current]]
	      switch -glob -- $subcmd {
		imp* {
		  foreach pattern $args {
		    if {[string match "-*" $pattern]} continue;
		    foreach cmd [info commands $pattern] {
		      if {![::nx::doc::is_exported $cmd]} continue;
		      set type @command
		      if {[info commands ::nsf::object::exists] ne "" &&\
			      [::nsf::object::exists $cmd]} {
			set type [expr {[::nsf::is class $cmd]?"@class":"@object"}]
		      }
		      set imported_name [string trimright $ns :]::[namespace tail $cmd]
		      ::nx::doc::__at_register_command $imported_name \
			  ->cmdtype $type \
			  ->source [file normalize [info script]] \
			  ->nsexported [::nx::doc::is_exported $imported_name] \
			  ->nsimported 1
		    }
		  }
		}
	      } 
	      interp invokehidden "" -namespace $ns namespace $subcmd {*}$args
	    }
	  }
	}
      }
      ::interp alias ${:interp} ::nx::doc::__at_register_command \
	  "" [current] at_register_command
      ::interp alias ${:interp} ::nx::doc::__at_deregister_command \
	  "" [current] at_deregister_command
      ::interp alias ${:interp} ::nx::doc::__cpackage \
	  "" [current] cpackage
      ::interp alias ${:interp} ::nx::doc::__at_register_package \
	  "" [current] at_register_package
      ::interp alias ${:interp} ::nx::doc::__at_source \
	  "" [current] at_source
      ::interp alias ${:interp} ::nx::doc::__at_load \
	  "" [current] at_load

      next
    }
    :protected property {interp ""}; # the default empty string points to the current interp

    :public property registered_commands

    :public method getCompanions {identifiers} {
      set scripts [list]
      dict for {source pkg} $identifiers {
	set rootname [file rootname $source]
	set dir [file dirname $source]
	set companion $rootname.nxd
	set srcs [dict create {*}"[join [list $source $rootname.nxd [file join $dir $pkg].nxd] " _ "] _"]
	foreach src [dict keys $srcs] {
	  if {![file isfile $src] || ![file readable $src]} continue;
	  if {[file extension $src] eq [info sharedlibextension]} continue;
	  set fh [open $src r]
	  if {[catch {lappend scripts [read $fh]} msg]} {
	    catch {close $fh}
	    :log "error reading the file '$thing', i.e.: '$msg'"
	  }
	  catch {close $fh}
	}
      }
      return $scripts

    }

    :public method get_companions {} {
      set companions [dict create]
      dict for {cmd props} ${:registered_commands} {
	dict with props {
	  # $source, $package
	  dict set companions $source $package
	}
      }
      return [:getCompanions $companions]
    }

    :public method get_registered_commands {
	-exported:switch
	-types
	-not:switch
	nspatterns:optional
      } {
      if {[info exists nspatterns]} {
	set opts [join $nspatterns |]
	# set nspatterns "^($opts)\[^\:\]*\$"
	set nspatterns "^($opts)\$"
      }
      dict filter ${:registered_commands} script {cmd props} {
	dict with props {
	  expr {[expr {[info exists nspatterns]?[expr {[regexp -- $nspatterns $cmd _] != $not}]:1}] && \
		    [expr {$exported?[expr {$nsexported == $exported}]:1}] && \
		    [expr {[info exists types]?[expr {$cmdtype in $types}]:1}]}
	}
      }
      #lsearch -inline -all -regexp $additions {^::nsf::[^\:]+$}]
  }


#    :forward do ::interp %1 {% set :interp}
    :public method do {script} {
      ::interp eval ${:interp} $script
    } 

    :public method destroy {} {
      #
      # TODO: Why am I called twice in doc.test? Because of the test
      # enviroment (the auto-cleanup feature?)
      #
      # puts stderr "SELF [current object] interp ${:interp}"
      # ::nsf::__db_show_stack
      if {${:interp} ne ""} {
	if {[interp exists ${:interp}]} {
	  interp delete ${:interp}
	}
      } else {
	:do {
	  if {[info commands ::nsf::configure] ne ""} {
	    ::nsf::configure keepinitcmd false;
	    array set sysmeths [concat {*}[lassign {*}[::nsf::configure objectsystem] rootclass rootmclass]]
	    # TODO: some cleanup is only needed if __init has been called
	    # (which is not always the case). refactor the code
	    # accordingly.
	    set ::nx::doc::rootns [namespace qualifier $rootmclass]
	    if {[::nsf::object::exists ${::nx::doc::rootns}::__Tracer]} {
	      ${::nx::doc::rootns}::__Tracer $sysmeths(-object.destroy)
	      ::nsf::relation $rootmclass class-mixin {}
	    }
	    if {[info commands ::nsf::_%&createobjectsystem] ne ""} {
	      rename ::nsf::_%&createobjectsystem ::nsf::objectsystem::create
	    }
	    unset ::nx::doc::rootns
	  }
	  rename ::proc ""
	  interp expose "" proc
	  rename ::namespace ""
	  interp expose "" namespace
	  rename ::source ""
	  interp expose "" source
	  rename ::load ""	  
	  interp expose "" load
	  rename ::package ""
	  interp expose "" package
	  rename ::auto_import ""
	  interp expose "" auto_import

	  proc ::nx::doc::__at_register_command {} {}
	  proc ::nx::doc::__at_deregister_command {} {}
	  proc ::nx::doc::__at_register_package {} {}
	  proc ::nx::doc::__at_deregister_package {} {}
	}
      }
      next
    }
  }
  namespace export Sandbox
}


namespace eval ::nx::doc::xodoc {

  namespace import -force ::nx::*
  namespace import -force ::nx::doc::*

  # xodoc		->	nxdoc
  # - - - - - - - - - - - - - - - -
  # MetadataToken	Entity
  # FileToken		@package 
  # PackageToken	@package
  # ConstraintToken	n/a
  # MethodToken		n/a
  # ProcToken		@method (scope = object)
  # InstprocToken	@method (scope = class)
  # ObjToken		@object
  # ClassToken		@class
  # MetaClassToken	n/a

  Class create MetadataToken {
    :class property analyzer
    :public forward analyzer [current] %method
    :method as {partof:object,type=::nx::doc::StructuredEntity} \
        -returns object,type=::nx::doc::Entity {
          error "Subclass responsibility"
        } 
    :public method emit {partof:object,type=::nx::doc::StructuredEntity} \
        -returns object,type=::nx::doc::Entity {
          set entity [:as $partof]
          set props [:get_properties]
          if {[dict exists $props description]} {
            $entity @doc [dict get $props description]
          }
          return $entity
        }
    :method get_properties {} {
      if {[info exists :properties]} {
	set props [dict create]
	foreach p ${:properties} {
	  if {[info exists :$p]} {
	    dict set props [string tolower $p] \
		[:format [set :$p]]
	  }
	}
	return $props
      }
    }
    :method format {value} {
      #
      # 1. replace @-prefixed tags etc.
      #
      set value [[:analyzer] replaceFormatTags $value]
      
      #
      # 2. escape Tcl evaluation chars in code listings
      #     
      set value [string map {
	"\\" "\\\\" 
	"{" "\\{" 
	"}" "\\}" 
	"\"" "\\\"" 
	"[" "\\[" 
	"]" "\\]" 
	"$" "\\$"
      } $value]
 
      #
      # 3. box the prop value in a list (this avoids unwanted
      # interactions with the line-by-line as_text post-processor)
      #
      return [list $value]
    }
  }
  
  Class create PackageToken -superclass MetadataToken
  Class create FileToken -superclass MetadataToken {
    :method as {partof:object,type=::nx::doc::StructuredEntity} \
        -returns object,type=::nx::doc::Entity {
          #
          # TODO: Where to retrieve the package name from?
          #
          return [@package new -name XOTcl]
        } 
    :public method emit {partof:object,type=::nx::doc::StructuredEntity} \
        -returns object,type=::nx::doc::Entity {
          set entity [next]
          set props [dict remove [:get_properties] description]
          dict for {prop value} $props {
            $entity @doc add "<h1>$prop</h1>[join $value]" end
          }
          $entity @namespace [[$entity current_project] @namespace]
          return $entity
        }
  }
  
  #
  # Note: For whatever reason, InstprocToken is provided but never
  # used, at least in XOTcl-langRef. while most probably due to a lack
  # of attention or a silent revocation of a design decision in xodoc,
  # it forces us into code replication for differentiating the
  # per-class and per-object scopes ... in xodoc, these scopes are
  # double-encoded, both in proper token subclassifications as well as
  # aggregation properties: procList, instprocList ... well, I will
  # have to live with it.
  #

  Class create MethodToken -superclass MetadataToken
  
  Class create ProcToken -superclass MethodToken {
    :method as {scope partof:object,type=::nx::doc::StructuredEntity} \
        -returns object,type=::nx::doc::Entity {
      return [$partof @${scope}-method [:name]]
    } 
    :public method emit {scope partof:object,type=::nx::doc::StructuredEntity} {
      set entity [:as $scope $partof]      
      set props [:get_properties]
      if {[dict exists $props description]} {
        $entity @doc [dict get $props description]
      }
      if {[dict exists $props return]} {
	$entity @return [dict get $props return]
      }
      return $entity
    }
  }
  
  Class create InstprocToken -superclass MethodToken
  
  Class create ObjToken -superclass MetadataToken {
    :method as {partof:object,type=::nx::doc::ContainerEntity} \
        -returns object,type=::nx::doc::Entity {
      return [@object new -name [:name]]
    } 
    :public method emit {entity:object,type=::nx::doc::Entity} \
        -returns object,type=::nx::doc::Entity {
          set entity [next]
          foreach p [:procList] {
            $p emit object $entity
          }
          return $entity
        }
  }
  
  Class create ClassToken -superclass ObjToken {
    :method as {partof:object,type=::nx::doc::ContainerEntity} \
        -returns object,type=::nx::doc::Entity {
      return [@class new -name [:name]]
    }
    :public method emit {entity:object,type=::nx::doc::Entity} \
        -returns object,type=::nx::doc::Entity {
          set entity [next]
          foreach iproc [:instprocList] {
            $iproc emit class $entity
          }
          return $entity
        }
  }
  
  Class create MetaClassToken -superclass ClassToken
  
  namespace export MetadataToken FileToken MethodToken ProcToken \
      InstprocToken ObjToken ClassToken MetaClassToken
}


#
# post processor for initcmds and method bodies
#
namespace eval ::nx {
  
  namespace import -force ::nx::doc::*
  
  MixinLayer create processor -prefix ::nx::doc {
    namespace eval ::nx::doc {
      namespace eval ::nx::doc::MixinLayer {
	namespace export Mixin
      }
      namespace import -force ::nx::doc::MixinLayer::*
      namespace export Mixin
    }
    
    namespace import -force ::nx::doc::*
    
    Mixin create [current]::Entity {
      :public method init args {
	next
	set prj [:current_project]
	if {$prj ne ""} {
	  set box [$prj sandbox]	  
	  set cmdname [:get_fqn_command_name]
	  if {[$box eval {info exists :registered_commands}] && \
		  [$box eval [concat dict exists \${:registered_commands} $cmdname]]} {
	    :pdata [$box eval [concat dict get \${:registered_commands} $cmdname]]
	  }
	}
	[[current class] info parent] at_processed [current]
      }
    }

    Mixin create [current]::ContainerEntity {
      :method init {} {
	next
	::nx::doc::QualifierTag mixin add ::nx::doc::ContainerEntity::Resolvable
	::nx::doc::ContainerEntity::Resolvable container [current]
	foreach {attr part_class} [:part_attributes] {
	  $part_class class mixin add ::nx::doc::ContainerEntity::Containable
	  $part_class container [current]
	}
      }
    }    

    Mixin create [current]::@package {
      :public method init args {
	next
	set prj [:current_project]
	if {$prj ne ""} {
	  set box [$prj sandbox]
	  if {[$box eval [concat dict exists \${:registered_packages} ${:name}]]} {
	    :pdata [$box eval [concat dict get \${:registered_packages} ${:name}]]
	  }
	}
      }
    }

    Mixin create [current]::@method -superclass [current]::Entity {
      :method init args {
	next
	set scope [expr {[${:part_attribute} scope] eq "class"?"class":"object"}]
	set obj [:get_owning_object]
	set method_name [:get_combined name]
	set prj [:current_project]
	if {$prj ne ""} {
	  set box [$prj sandbox]	  
	  set script "if {\[::nsf::object::exists $obj\]} {array set \"\" \[$obj eval {:__resolve_method_path \"$method_name\"}\]; ::nsf::dispatch \$(object) ::nsf::methods::${scope}::info::method handle \$(methodName)}"
	  set cmdname [$box do $script]
	  if {$cmdname ne "" && [$box eval [concat dict exists \${:registered_commands} $cmdname]]} {
	    :pdata [$box eval [concat dict get \${:registered_commands} $cmdname]]
	  }
	}
	
      }
    }

    Mixin create [current]::@param -superclass [current]::Entity {
      :public method init args {
	next
	if {${:name} eq "__out__"} {
	  if {[${:partof} pinfo exists bundle returns]} {
	    :pdata [list bundle [list spec [${:partof} pinfo get bundle returns]]]
	  }
	} elseif {[${:partof} pinfo exists bundle parameter ${:name}]} {
	  lassign [${:partof} pinfo get bundle parameter ${:name}] spec default
	  :pdata [list bundle [list spec $spec default $default]]
	}
      }
    }

        
    #
    # mixin layer interface
    #

    :method apply {} {
      unset -nocomplain :processed_entities
      next
    }

    :method revoke {} {
      next
      if {[info exists :processed_entities]} {
	return [dict keys ${:processed_entities}]
      }
    }
    
    :public method at_processed {entity} {
      dict set :processed_entities $entity _
    }

    #
    # processor interface
    #

    :method log {msg} {
      puts stderr "[current]->[uplevel 1 [list ::nsf::current method]]: $msg"
    }

    :public method process {
	-sandboxed:switch 
	-validate:switch
	{-type project}
	-include
	-exclude
	thing
      } {
      if {$type ne "project"} {
	# TODO: Fix the naming requirements ...
	set project [@project new -name "_%@"]
	$project sources [list $type $thing]
      } else {
	set project $thing
      }

      set box [$project sandbox [Sandbox new \
				     -interp [expr {$sandboxed?[interp create]:""}]]]
      set sources [dict create]
      foreach {type name} [$project sources] {
	dict lappend sources $type $name
      }


      set nsFilters [list]
      if {[info exists include] && $include ne ""} {
	set nsFilters [list $include]
      }
      if {[info exists exclude] && $exclude ne ""} {
	set nsFilters [list -not $exclude]
      }


      set provided_entities [list]
      dict for {type instances} $sources {
	lappend provided_entities {*}[:[current method]=$type $project $instances {*}$nsFilters]
      }

      if {$validate} {
	#
	# TODO: is_validated to later to become a derived/computed
	# property ... for now, we just need to escape from setting
	# validation-related info in non-validated projects!
	#
	$project is_validated $validate; # is_validated = 1

	set present_entities [::nx::doc::filtered $provided_entities {[[:origin] eval {info exists :pdata}]}]
	# TODO: the nspatterns should be consumed from the source
	# specification and should not be hardcoded here ... review
	# later ...
	#puts stderr "NSF: [join [dict keys [$box get_registered_commands -exported -types @command]] \n]"
	# ISSUE: -exported turns out to be a weak filter criterion, it
	# excludes slot objects from being processed!
	
	#
	# TODO: Add support for "generated" packages and their
	# validation later on, i.e. a @package.validate() method.
	#
	
	set generated_commands [dict merge \
				    [$box get_registered_commands -types {
				      @object 
				      @class 
				      @command
				    }] \
				    [$box get_registered_commands -types {
				      @method
				    }]]

	#puts stderr generated_commands=$generated_commands
	#puts stderr present_entities=$present_entities
	set map [dict create]
	foreach pe $present_entities {
	  if {[$pe pinfo exists bundle handle]} {
	    set fqn [$pe pinfo get bundle handle]
	  } else {
	    set fqn [$pe get_fqn_command_name]
	  }
	  dict unset generated_commands $fqn
	  dict set map $fqn $pe
	}
	
	# 2. generated entities (doc[no]->program[yes])
	dict for {cmd info} $generated_commands {
	  dict with info {
	    if {$cmdtype ni [list @command @object @class @method]} continue;
	    if {$cmdtype eq "@object" && [string match *::slot::* $cmd]} {
	      if {[dict exists $info bundle objtype] && [dict get $info bundle objtype] eq "ensemble"} continue;
	      set name [namespace tail $cmd]
	      set scope ""
	      set obj [namespace qualifiers [namespace qualifiers $cmd]]
	      if {![dict exists $map $obj]} continue;
	      set partof_entity [dict get $map $obj]
	      set entity [$partof_entity @[join [list {*}${scope} property] -] $name]
	    } elseif {$cmdtype eq "@method"} {
	      lassign [dict get $bundle handleinfo] obj scope name
	      # ! we assume the partof entity is present or has been generated
	      if {![dict exists $map $obj]} continue;
	      set partof_entity [dict get $map $obj]
	      if {![$partof_entity info has type ::nx::doc::@object]} continue;
	      set owning_entity $partof_entity 
	      foreach subm $name {
		set en [$partof_entity @[join [list {*}${scope} method] -] id $subm]
		if {$en ni $provided_entities} {
		  set partof_entity [$partof_entity @[join [list {*}${scope} method] -] $subm]
		} else {
		  set partof_entity $en
		}
	      }
	      set entity $partof_entity
	      if {[dict exists $info bundle parameter]} {
		dict for {pname paraminfo} [dict get $info bundle parameter] {
		  lassign $paraminfo spec default
		  set paramid [@parameter id $entity "" $pname]
		  set ppdata [list bundle [list spec $spec default $default]]
		  if {$paramid ni $provided_entities} {
		    set paramid [$entity @parameter $pname]
		    lappend ppdata status missing
		  }
		  $paramid pdata $ppdata
		}
	      }
	    } else {
	      set entity [@ $cmdtype $cmd]
	    }
	    
	    #puts stderr "SETTING missing PDATA $entity $cmd"
	    $entity pdata [lappend info status missing]
	    dict set map [$entity get_fqn_command_name] $entity
	  }
	}
      }
      return $project
    }

    :protected method process=@package {project pkgs} {
      set box [$project sandbox]
      $box permissive_pkgs [string tolower $pkgs]
      set 1pass ""
      foreach pkg $pkgs {
	if {[catch {namespace eval :: [list package req $pkg]} _]} {
	  error "Tcl package '$pkg' cannot be found."
	}
	append 1pass "package req $pkg\n"
      }

      #
      # a) 1-pass: requiring the packages first will provide
      # all dependencies (also those not to be documented).
      #
      $box do "::nx::doc::__trace_pkg; $1pass"

      #
      # b) 2-pass: [source] will re-evaluate the package scripts
      # (note, [load]-based extension packages are not covered by this!)
      #"
      if {[$box eval {info exists :source}]} {
	#
	# Note: Expects the XOTcl2 utilities to be in place and
	# accessible by the [package req] mechanism, use e.g.:
	# export TCLLIBPATH=". ./library/xotcl/library/lib"
	#
	package req xotcl::xodoc
	namespace eval :: {namespace import -force ::xotcl::@}
	
	set docdb [XODoc new]
	::@ set analyzerObj $docdb
	foreach {pkg src} [$box eval {set :source}] {
	  $docdb analyzeFile $src
	}
	
	foreach m [namespace eval ::nx::doc::xodoc {namespace export}] {
	  if {[::xotcl::Class info instances -closure ::xotcl::metadataAnalyzer::$m] ne ""} {
	    ::xotcl::metadataAnalyzer::$m instmixin add ::nx::doc::xodoc::$m
	  }
	}
	
	::nx::doc::xodoc::MetadataToken eval [list set :analyzer $docdb]
	set provided_entites [list]
        #
        # as we analyze file by file, there is only one FileToken to
        # be molded into an @package
        # 
        set ft [::xotcl::metadataAnalyzer::FileToken allinstances]
        if {[llength $ft] > 1} {
          error "Too many xodoc file tokens processed. Expecting just one!"
        }

	$project @namespace "::xotcl"
	::nx::doc::QualifierTag mixin add ::nx::doc::ContainerEntity::Resolvable
	::nx::doc::ContainerEntity::Resolvable container $project

	foreach {attr part_class} [$project part_attributes] {
	  $part_class class mixin add ::nx::doc::ContainerEntity::Containable
	  $part_class container $project
	}

        set partof $project
        if {$ft ne ""} {
          set pkg [$ft emit $project]
          lappend provided_entities $pkg
          set partof $pkg
        }

	foreach token [::xotcl::metadataAnalyzer::ObjToken allinstances] {
	  lappend provided_entities [$token emit $partof]
	}

        return $provided_entities
      }
    }
      
    :protected method process=package {project pkgs nsFilters:optional} {
      set box [$project sandbox]
      $box permissive_pkgs $pkgs
      set 1pass ""
      foreach pkg $pkgs {
	if {[catch {package req $pkg} _]} {
	  error "Tcl package '$pkg' cannot be found."
	}
	append 1pass "package req $pkg\n"
      }

      #
      # a) 1-pass: requiring the packages first will provide
      # all dependencies (also those not to be documented).
      #
      $box do "::nx::doc::__trace_pkg; $1pass"

      #
      # b) 2-pass: [source] will re-evaluate the package scripts
      # (note, [load]-based extension packages are not covered by this!)
      #"
      if {[$box eval {info exists :source}]} {
	foreach {pkg src} [$box eval {set :source}] {
	  #
	  # TODO: 2-pass [source]s should not trigger transitive [source]s. we
	  # have flattened the relevant [source] hierarchy in the
	  # 1-pass.
	  #
	  append 2pass \
	      "::nx::doc::__cpackage push $pkg;\n" \
	      "source $src;\n" \
	      "::nx::doc::__cpackage pop;\n"
	}
	$box do "::nx::doc::__init; $2pass" 
      }

      #
      # filter registered commands for includes/excludes 
      #
      if {[info exists nsFilters]} {
	$box registered_commands [$box get_registered_commands $nsFilters]
      }

      # puts stderr REGISTERED_COMMANDS=[dict keys [$box registered_commands]]

      
      foreach {attr part_class} [$project part_attributes] {
	$part_class class mixin add ::nx::doc::ContainerEntity::Containable
	$part_class container $project
      }

      set deps_entities [list]
      foreach dep [$box getCompanions [$box eval {set :deps}]] {
	lappend deps_entities {*}[:readin $dep]
      }
      foreach de $deps_entities {
	$de @stashed
      }

      set scripts [$box get_companions]
      set provided_entities [list]

      foreach script $scripts {
	lappend provided_entities {*}[:readin $script] 
      }
      return $provided_entities
    }

    :protected method process=source {project filepath} {;}

    :protected method process=eval {project scripts} {
      set box [$project sandbox]
      #
      # 1a) 1pass ... TODO: should tracing be enabled in this scenario? ...
      #
      foreach script $scripts {
	$box do $script
      }

      #
      # 2) 2pass ... 
      # 
      $box do [list ::nx::doc::__init]

      foreach script $scripts {
	$box do $script
      }
      #
      # 3) documentation processing
      #

      # 3a) top-level processing
      foreach script $scripts {
	:readin $script
      }

      # 3b) initcmds, proc bodies ...

      dict for {cmd info} [$box get_registered_commands] {
	dict with info {
	  #
	  # TODO: for now, we assume objects beyond this point
	  # ... relax later!
	  #
	  if {$cmdtype ni [list @object @class]} continue;
	  if {[info exists docstring]} {
	    lassign [:readin \
			    -docstring \
			    -tag $cmdtype \
			    -name $cmd \
			    -parsing_level 1 \
			    $docstring] entity processed_entities
	    unset docstring
	  } else {
	    set entity [@ $cmdtype $cmd]
	  }
	  :process=$cmdtype $project $entity
	}
      }
    }
        
    :public method readin {
	-docstring:switch 
	-tag
	-name
	-partof_entity:object,type=::nx::doc::StructuredEntity
	{-parsing_level:integer 0}
	script
      } {

      set blocks [:comment_blocks $script]
      set first_block 1
      set processed_entities [list]
      foreach {line_offset block} $blocks {
	array set arguments [list -initial_section context \
				 -parsing_level $parsing_level]

	if {$docstring} {
	  if {[info exists partof_entity]} {
	    set arguments(-partof_entity) $partof_entity
	  }
	  if {![info exists tag] || ![info exists name]} {
	    error "In docstring mode, provide the tag and the name of
	      a docstring-owning documentation entity object."
	  }
	  if {$first_block} {
	    #
	    # TODO: Note that the two "creation procedures" are not
	    # idempotent; the relative one overwrites description
	    # blocks of pre-exisiting entities, the freestanding @
	    # does not ... fix later when reviewing these parts of the
	    # program ...
	    # 
	    set docentity [expr {[info exists partof_entity]?\
				     [$partof_entity $tag $name]:[@ $tag $name]}]
	    set arguments(-partof_entity) $docentity
	    if {$line_offset <= 1} {
	      set arguments(-initial_section) description
	      set arguments(-entity) $docentity
	    }
	  }
	}
	
	set args [array get arguments]
	lappend args $block
	# puts stderr "::nx::doc::CommentBlockParser process {*}$args"
	#::nx::doc::Entity mixin add [current]::Entity
	:apply
	::nx::doc::CommentBlockParser process {*}$args
	lappend processed_entities {*}[:revoke]
	set first_block 0
      }
      if {$docstring && [info exists arguments(-partof_entity)]} {
	return [list $arguments(-partof_entity) $processed_entities]
      } else {
	return $processed_entities
      }
    }

    :public method analyze_line {line} {
      set regex {^[\s#]*#+(.*)$}
      if {[regexp -- $regex $line --> comment]} {
	return [list 1 [string trimright $comment]]
      } else {
	return [list 0 $line]
      }
    }
    
    :public method comment_blocks {script} {
      set lines [split $script \n]
      set comment_blocks [list]
      set was_comment 0
      
      set spec {
	0,1	{
	  set line_offset $line_counter; 
	  set comment_block [list]; 
	  lappend comment_block $text}
	1,0	{
	  lappend comment_blocks $line_offset $comment_block; 
	  unset comment_block
	}
	1,1	{lappend comment_block $text}
	0,0	{}
      }
      array set do $spec 
      set line_counter -1
      foreach line $lines {
	incr line_counter
	# foreach {is_comment text} [:analyze_line $line] break;
	lassign [:analyze_line $line] is_comment text;
	eval $do($was_comment,$is_comment)
	set was_comment $is_comment
      }
      if {[info exists comment_block]} {
	lappend comment_blocks $line_offset $comment_block
      }
      return $comment_blocks
    }
    
    # TODO: how can I obtain some reuse here when later @class is
    # distinguished from @object (dispatch along the inheritance
    # hierarchy?)

    :public method process=@command {project entity} {;}

    :public method process=@class {project entity} {
      set name [$entity name]
      set box [$project sandbox]
      # attributes
      foreach slot [$box do [list $name info slot objects]] {
	if {[$box do [list $slot eval {info exists :__initcmd}]]} {
	  #
	  # TODO: Here, we eagerly create doc entities, is this an issue?
	  # Should we mark them for removal if not further processed?
	  # This might be contradicting to the requirement of
	  # identifying documented/undocumented program structures.
	  #
	  # There are two alternatives:
	  # -> use a freestanding identity generator (preferred!)
	  # -> mark the entity for deletion
	  #
	  # set id [$entity @${scope}-attribute [$box do [list $slot name]]]
	 
	  set scope [expr {[$box do [list $slot per-object]]?"class-object":"class"}]
	  :readin \
	      -partof_entity $entity \
	      -docstring \
	      -tag @${scope}-property \
	      -name [$box do [list $slot name]] \
	      -parsing_level 2 \
	      [$box do [list $slot eval {set :__initcmd}]]

	}
      }

      foreach methodName [$box do [list $name info methods \
				       -methodtype scripted \
				       -callprotection public]] {
	:readin \
	    -partof_entity $entity \
	    -docstring \
	    -tag @class-method \
	    -name $methodName \
	    -parsing_level 2  \
	    [$box do [list ${name} info method body $methodName]]
      }
      
      :process=@object $project $entity class
      
    }
    
    #
    # TODO: how to resolve to the current project's context. For now,
    # we pass a parameter value, revisit this decision once we decide
    # on a location for this behaviour.
    #
    :public method process=@object {project entity {scope ""}} {
      set name [$entity name]
      set box [$project sandbox]
      # methods

      foreach methodName [$box do [list ${name} {*}$scope info methods\
				       -methodtype scripted \
				       -callprotection public]] {
	
	set tag [join [list {*}[expr {$scope eq "class"?"class-object":""}] method] -]
	# set id [$entity @$tag $methodName]
	:readin \
	    -partof_entity $entity \
	    -docstring \
	    -tag @$tag \
	    -name $methodName \
	    -parsing_level 2  \
	    [$box do [list ${name} {*}$scope info method body $methodName]]
      }
    }
    
  }
}
	  

#
# toplevel interface
#   ::nx::doc::make all
#   ::nx::doc::make doc
#
namespace eval ::nx::doc {

  Object create make  {
    
    :method all {{-verbose:switch} {-class ::nx::Class}} {
      foreach c [$class info instances -closure] {
	if {$verbose} {puts "postprocess $c"}
	::nx::doc::postprocessor process $c
      }
    }
       
    :method write {content path} {
      set fh [open $path w]
      puts $fh $content
      catch {close $fh}
    }

    :public method doc {
      {-format html}
      project:object,type=::nx::doc::@project
      args
    } {
      package req nx::doc::$format
      $format run -project $project {*}$args
    }
  }
  
  #
  # This is a mixin class which adds comment block parsing
  # capabilities to documentation entities (Entity, ...), once
  # identified.
  #
  # It acts as the event source external to the modal parser (i.e.,
  # the parsed entity). Expressing a modal behavioural design itself
  # (around the line queue of a comment block), it produces certain
  # events which are then signalled to the parsed entity.
  #
  Class create CommentBlockParser {

    :property {parsing_level:integer 0}

    :property {message ""}
    :property {status:in "COMPLETED"} {

      set :incremental 1
      
      set :statuscodes {
	COMPLETED
	INVALIDTAG
	MISSINGPARTOF
	STYLEVIOLATION
	LEVELMISMATCH
      }
      
      :public method type=in {name value} {
	if {$value ni ${:statuscodes}} {
	  error "Invalid statuscode '$code'."
	}
	return $value
      }
      
      :public method ? [list obj var value:in,slot=[current object]] {
	return [expr {[:get $obj $var] eq $value}]
      }

      :public method is {obj var value} {
	return [expr {$value in ${:statuscodes}}]
      }
    }

    :property processed_section  {
      set :incremental 1
      :public method assign {domain prop value} {
	set current_entity [$domain current_entity]
	set scope [expr {[$current_entity info is class]?"class mixin":"mixin"}]
	#	puts stderr "Switching: [$current_entity {*}$scope] --> target $value"
	if {[$domain eval [list info exists :$prop]] && [:get $domain $prop] in [$current_entity {*}$scope]} {
	  $current_entity {*}$scope delete [:get $domain $prop]
	}
	$current_entity {*}$scope add [next [list $domain $prop $value]]
      }
    }
    :property current_entity:object
    
    :public class method process {
			      {-partof_entity ""}
			      {-initial_section context}
			      {-parsing_level 0}
			      -entity
			      block
			    } {
	
	if {![info exists entity]} {
	  set entity [Entity]
	}
      
	set parser_obj [:new -current_entity $entity -parsing_level $parsing_level]
	$parser_obj [current proc] \
	    -partof_entity $partof_entity \
	    -initial_section $initial_section \
	    $block
	return $parser_obj
      }
    
    :public forward has_next expr {${:idx} < [llength ${:comment_block}]}
    :public method dequeue {} {
      set r [lindex ${:comment_block} ${:idx}]
      incr :idx
      return $r
    }
    :public forward rewind incr :idx -1
    :public forward fastforward set :idx {% llength ${:comment_block}}

    :public method cancel {statuscode {msg ""}} {
      :fastforward
      :status $statuscode
      :message $msg
      uplevel 1 [list ::return -code error $statuscode]
    }
    #
    # everything below assumes that the current class is an active mixin
    # on an instance of an Entity subclass!
    #

    :public method process {
      {-partof_entity ""}
      {-initial_section context}
      block
    } {

      set :comment_block $block
      set :idx 0

      :processed_section [$initial_section]

      # TODO: currently, default values are not initialised for
      # property slots defined in mixin classes; so do it manually
      # for the time being.
      ${:current_entity} current_comment_line_type ""

      ${:current_entity} block_parser [current]      
      ${:current_entity} eval [list set :partof_entity $partof_entity]
      
      set is_first_iteration 1
#      set failure ""
      
      #
      # Note: Within the while-loop, two object variables constantly
      # change (as "wanted" side-effects): processed_section: reflects
      # the currently processed comment section; see event=next()
      # current_entity: reflects the currently documentation entity
      # (once resolved); see context->event=parse@tag()
      #
      while {[:has_next]} {
	set line [:dequeue]	
	if {$is_first_iteration} {
	  ${:current_entity} on_enter $line
	  set is_first_iteration 0
	}

	if {[catch {
	 # puts stderr "PROCESS ${:current_entity} event=process $line"
	  ${:current_entity} event=process $line
	} failure]} {
	  if {![:status is $failure]} {
	    ::return -code error -errorinfo $::errorInfo
	  }
	} 
      }
      if {!$is_first_iteration} {
	${:current_entity} on_exit $line
      }

      # ISSUE: In case of some sub-method definitions (namely "info
      # mixin"), the sub-method entity object for "mixin" replaces the
      # forward handlers of the mixin relation slot. So, any slot-like
      # interactions such as delete() won't work anymore. We need to
      # bypass it by using ::nsf::relation, for the time being. This
      # is a clear con of the explicit naming of entity objects (or at
      # least the current scheme)!

      # if {[${:processed_section} info mixinof -scope object ${:current_entity}] ne ""} {
      # 	${:current_entity} {*}$scope mixin delete ${:processed_section}
      # }

      set scope [expr {[${:current_entity} info is class]?"class":""}]
      set mixins [${:current_entity} {*}$scope info mixin classes]
      if {${:processed_section} in $mixins} {
	set idx [lsearch -exact $mixins ${:processed_section}]
	set mixins [lreplace $mixins $idx $idx]
	::nsf::relation ${:current_entity} object-mixin $mixins
      }
                  
    }; # CommentBlockParser->process()
    
  }
  
  Class create CommentBlockParsingState -superclass Class {
    
    :property next_comment_section
    :property comment_line_transitions:required
    
  }
  
  Class create CommentSection {

    :property block_parser:object,type=::nx::doc::CommentBlockParser
    :property {current_comment_line_type ""}

    set :line_types {
      tag {regexp -- {^\s*@[^[:space:]@]+} $line}
      text {regexp -- {^\s*([^[:space:]@]+|@[[:space:]@]+)} $line}
      space {expr {$line eq {}}}
    }

    :method get_transition {src_line_type tgt_line} {
      set section [${:block_parser} processed_section]
      array set transitions [$section comment_line_transitions]
      # expected outcome
      # 1. new state -> becomes current_comment_line
      # 2. actions to be triggered from the transition
      
      foreach {line_type expression} [[current class] eval {set :line_types}] {
	set line $tgt_line
	if {[eval $expression]} {
	  set tgt_line_type $line_type
	  break
	}
      }

      if {![info exists tgt_line_type]} {
	error "Could not resolve the type of line '$line'"
      }

      if {![info exists transitions(${src_line_type}->${tgt_line_type})]} {
	set msg "Style violation in a [namespace tail [:info class]] section:\n"
	if {$src_line_type eq ""} {
	  append msg "Invalid first line ('${tgt_line_type}')"
	} else {
	  append msg "A ${src_line_type} line is followed by a ${tgt_line_type} line"
	}
	${:block_parser} cancel STYLEVIOLATION $msg
	# [StyleViolation new -message $msg] throw
      }
      return [list $tgt_line_type $transitions(${src_line_type}->${tgt_line_type})]
    }

    # the actual events to be signalled to and sensed within the
    # super-states and sub-states

    :public method event=process {line} {
      lassign [:get_transition ${:current_comment_line_type} $line] \
	  :current_comment_line_type actions
      foreach action $actions {
	:event=$action $line
      }
    }

    :public forward event=parse %self {% subst {parse@${:current_comment_line_type}}} 
    :method event=next {line} {
      set next_section [[${:block_parser} processed_section] next_comment_section]
      :on_exit $line
      
      ${:block_parser} rewind
      :current_comment_line_type ""
    
      ${:block_parser} processed_section [$next_section]
      :on_enter $line
    }

   
    # realise the sub-state (a variant of METHOD-FOR-STATES) and their
    # specific event handling
    # set :lineproc {{tag args} {return [concat {*}$args]}}
    # set :lineproc {{tag args} {puts stderr LINE=[list $tag {*}$args]; return [list $tag {*}$args]}}
    set :lineproc {{tag args} {return [list $tag [expr {$args eq ""?$args:[list $args]}]]}}
    :method parse@tag {line} {
      lassign [apply [[current class] eval {set :lineproc}] {*}$line] tag line
      #set line [lassign [apply [[current class] eval {set :lineproc}] {*}$line] tag]
      if {[:info lookup methods -source application $tag] eq ""} {
	set msg "The tag '$tag' is not supported for the entity type '[namespace tail [:info class]]"
	${:block_parser} cancel INVALIDTAG $msg
      }
      #:$tag [lrange $line 1 end]
      #:$tag {*}[expr {$line eq ""?$line:[list $line]}]
      #:$tag $line
      :$tag {*}$line
    }

    :method parse@text {line} {
      #puts stderr "ADDLINE([current]) :@doc add $line end"
      :@doc add $line end
    }
    :method parse@space {line} {;}
    
    #
    # so far, we only need enter and exit handlers at the level of the
    # superstates: context, description, part
    #
    :public method on_enter {line} {;}
    :public method on_exit {line} {;}
  }

  # NOTE: add these transitions for supporting multiple text lines for
  # the context element
  #	tag->text	parse
  #	text->text	parse
  #	text->space	""
  
  
  CommentBlockParsingState create context -superclass CommentSection \
      -next_comment_section description \
      -comment_line_transitions {
	->tag		parse
	tag->space	""
	space->space	""
	space->text	next
	space->tag	next
      } {
	
	:method resolve_partof_entity {tag name} {
	  # a) unqualified: attr1
	  # b) qualified: Bar#attr1
	  if {[regexp -- {([^\s#]*)#([^\s#]*)} $name _ qualifier nq_name]} {
	    # TODO: Currently, I only foresee @object and @command as
	    # possible qualifiers; however, this should be fixed asap, as
	    # soon as the variety of entities has been decided upon!
	    foreach entity_type {@class @command @object} {
	      set partof_entity [$entity_type id $qualifier]
	      # TODO: Also, we expect the qualifier to resolve against an
	      # already existing entity object? Is this intended?
	      if {[::nsf::is object $partof_entity]} {
		return [list $nq_name $partof_entity]
	      }
	    }
	    return [list $nq_name ${:partof_entity}]
	  } else {      
	    return [list $name ${:partof_entity}]
	  }
	}

	set :lineproc {{tag name args} {return [list $tag $name $args]}}
	:method parse@tag {line} {
	  lassign [apply [[current class] eval {set :lineproc}] {*}$line] axes names args
	  set entity ${:partof_entity}
	  set axes [split [string trimleft $axes @] .]

	  # 1) get the parsing level from the comment block parser
	  set start_idx [lindex [lsearch -all -not -exact $axes ""] 0]
	  
	  set pl [${:block_parser} parsing_level]
	  if {$pl != $start_idx} {
	    ${:block_parser} cancel LEVELMISMATCH "Parsing level mismatch: Tag is meant for level '$start_idx', we are at '$pl'."
	  }
	  
	  # 2) stash away a number of empty axes according to the parsing level 
	  set axes [lrange $axes $pl end]
	  
	  lassign [::nx::doc::Tag normalise $axes $names] err res
	  if {$err} {
	     ${:block_parser} cancel STYLEVIOLATION $res
	  }

	  lassign $res tagpath names
	  
	  set leaf(axis) [lindex $tagpath end]
	  set tagpath [lrange $tagpath 0 end-1]
	  set leaf(name) [lindex $names end]
	  set names [lrange $names 0 end-1]
	  
	  lassign [::nx::doc::Tag find -strict $tagpath $names $entity] err res
	  if {$err} {
	    ${:block_parser} cancel INVALIDTAG $res
	  }
	  
	  set entity $res
	  
	  if {$entity eq ""} {
	    set cmd [info commands @$leaf(axis)]
	   
	    # TODO interp-aliasing objects under different command names
	    # is currently not transparent to some ::nsf::* helpers,
	    # such as ::nsf::object::exists. Should this be changed?
	    #
	    if {$cmd ne ""} {
	      set cmd [namespace origin $cmd]
	      set target [interp alias {} $cmd]
	      if {$target ne ""} {
		set cmd $target
	      }
	    }
	    
	    if {$cmd eq "" || ![::nsf::object::exists $cmd] || \
		    ![$cmd info has type Tag]} {
	      
	      ${:block_parser} cancel INVALIDTAG "The entity type '@$leaf(axis)' is not available."
	    }

	    # VERIFY! Still an issue? TODO: @object-method raises some
	    # issues (at least when processed without a resolved
	    # context = its partof entity).  It is not an entity type,
	    # because it merely is a "scoped" @method. It won't
	    # resolve then as a proper instance of Tag, hence we
	    # observe an InvalidTag exception. For now, we just ignore
	    # and bypass this issue by allowing InvalidTag exceptions
	    # in analyze()

	    set entity [@$leaf(axis) new -name $leaf(name) {*}$args]
	  } else {
	    if {[$entity info lookup methods -source application @$leaf(axis)] eq ""} {
	      ${:block_parser} cancel INVALIDTAG \
		  "The tag '$leaf(axis)' is not supported for the entity type '[namespace tail [$entity info class]]'"
	    }
	    set entity [$entity @$leaf(axis) [list $leaf(name) {*}$args]]
	  }
	  
	  ${:block_parser} current_entity $entity
	  ${:block_parser} processed_section [current class]
	  $entity current_comment_line_type ${:current_comment_line_type}
	  $entity block_parser ${:block_parser}
	}
	
	# :method parse@text {line} { next }
	# :method parse@space {line} { next }
	
      }
  
  CommentBlockParsingState create description -superclass CommentSection \
      -next_comment_section part \
      -comment_line_transitions {
	->text		parse
	->tag		next
	text->text	parse
	text->space	parse
	space->text	parse
	space->space	parse
	space->tag	next
    } {
      
      :public method on_enter {line} {
	unset -nocomplain :@doc
	next
      }

      # tag lines are not allowed in description blocks!
      # :method parse@tag {line} {;}
      :method parse@space {line} {
	:@doc add "" end
	next
      }
      
    }

  CommentBlockParsingState create part -superclass CommentSection  \
      -next_comment_section part \
      -comment_line_transitions {
	->tag		parse
	tag->text	parse
	text->text	parse
	text->tag	next
	text->space	""
	space->space	""
	tag->space	""
	space->tag	next
	tag->tag	next
      } {
	# realise the parse events specific to the substates of description
	:public method on_enter {line} {
#	  puts stderr "ENTERING part $line, current section [${:block_parser} processed_section]"
	  unset -nocomplain :current_part
	  next
	}
	:method parse@tag {line} {
	  set r [next]
#	  puts stderr GOT=$r
	  if {[::nsf::object::exists $r] && [$r info has type ::nx::doc::Entity]} {
	    set :current_part $r
	  }
	  return $r
	}
	:method parse@text {line} {
	  if {[info exists :current_part]} {
	    ${:current_part} @doc add $line end
	  } else {
	    :event=next $line
	  }
	}
	# :method parse@space {line} {;}
      }

  ::nsf::proc mkIndex {{-documentAll:switch 0} {-indexfiles:0..* ""} {-outdir "[pwd]"} args} {

    if {![llength $args]} {
      set args *.tcl
    }

    set scripts [list]
    foreach file [glob -- {*}$args] {
      set file [file normalize $file]
      if {[file readable $file]} {
	lappend scripts $file
      }
    }

    if {![llength $scripts]} return;

    set sbox [Sandbox new -interp [interp create]]
    # 1pass
    append scriptBlock "source " [join $scripts "; source "]
    $sbox do [list package req nsf]
    $sbox do $scriptBlock
    # 2pass
    $sbox do [list ::nx::doc::__init]
    $sbox do $scriptBlock
    set cmds [dict keys [$sbox get_registered_commands -types {@command @object @class}]]
    
    append index "# NXDoc index file, version [package require nx::doc]\n"
    append index "# This file was generated by the \"::nx::doc::mkIndex\" command\n"
    append index "# and is optionally sourced by nxdoc to filter the command population\n"
    append index "# to be documented.  Typically each line is a command that\n"
    append index "# sets an element in the ::nxdoc::include array, where the\n"
    append index "# element name is the name of a command and the value indicates whether\n"
    append index "# the command is to be documented (1) or not (0).\n"
    append index \n

    if {[llength $indexfiles]} {
      append index "# Source external (e.g., auto-generated) index files\n"
    }

    foreach idx $indexfiles {
      append index {source [file join [file dirname [info script]] } $idx {]} "\n"
    }

    foreach cmd $cmds {
      append index "set ::nxdoc::include($cmd) $documentAll\n"
    }

    set fid [open [file join [file normalize $outdir] nxdocIndex] w]
    puts -nonewline $fid $index
    close $fid
  }  
}

# puts stderr "Doc Tools loaded: [info command ::nx::doc::*]"