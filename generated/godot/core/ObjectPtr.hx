package godot.core;

#if hl
typedef ObjectPtr = hl.Abstract<"godot_object">;
#else
typedef ObjectPtr = Dynamic;
#end