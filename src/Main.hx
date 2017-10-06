import haxe.DynamicAccess;

import thx.Set;

using tink.CoreApi;
using thx.Strings;
using thx.Arrays;

typedef TypeData = {
  name:String,
  base_class:String,
  api_type:String,
  singleton:Bool,
  instanciable:Bool,
  is_reference:Bool,
  constants:DynamicAccess<Int>,
  properties:Array<PropertyData>,
  signals:Array<SignalData>,
  methods:Array<MethodData>,
  enums:Array<EnumData>
}

typedef PropertyData = {
  name:String,
  type:String,
  getter:String,
  setter:String,
  ?hasGetterOrSetter:Bool,
}
typedef SignalData = {
  name:String,
  arguments:Array<SignalArgumentData>
}
typedef MethodData = {
  native:String,
  name:String,
  return_type:String,
  is_editor:Bool,
  is_noscript:Bool,
  is_const:Bool,
  is_reverse:Bool,
  is_virtual:Bool,
  has_varargs:Bool,
  is_from_script:Bool,
  arguments:Array<ArgumentData>
}
typedef EnumData = {
  name:String,
  values:DynamicAccess<Int>
}

typedef ArgumentData = {
  name:String,
  type:String,
  has_default_value:Bool,
  default_value:String
}

typedef SignalArgumentData = {
  name:String,
  type:String,
  default_value:String,
}

typedef KV<T> = {
  key:String,
  value:T,
}

class Main {

  static function main() {
    var file = sys.io.File.getContent("api.json");
    var types:Array<TypeData> = haxe.Json.parse(file);
    var classes:Array<Cls> = [];
    var foundTypes:Set<String> = Set.createString();
    for(type in types) {
      type.name = Util.baseTypeToHaxe(type.name);
      type.base_class = Util.baseTypeToHaxe(type.base_class);
      foundTypes.add(type.name);
      foundTypes.add(type.base_class);
      type.properties = type.properties.map((p) -> {
        p.name = Util.sanitize(p.name);
        p.type = Util.baseTypeToHaxe(p.type);
        foundTypes.add(p.type);
        p.hasGetterOrSetter = p.getter != null || p.setter != null;
        p.getter = Util.sanitize(p.getter);
        p.setter = Util.sanitize(p.setter);
        p;
      });
      type.methods.each((m) -> {
        m.return_type = Util.baseTypeToHaxe(m.return_type);
        foundTypes.add(m.return_type);
        m.arguments.each((arg) -> {
          arg.name = Util.sanitize(arg.name);
          
          if(arg.has_default_value) {
            arg.default_value = Util.defaultValueToHaxe(arg.type, arg.default_value);
          } else {
            if(!arg.default_value.isEmpty()) {
              trace('${type.name}::${m.name} ${arg.name} ${arg.type} ${arg.default_value}');
            }
            arg.default_value = "";
            arg.has_default_value = false;
          }
          arg.type = Util.baseTypeToHaxe(arg.type);
          

          foundTypes.add(arg.type);
        });
      });

      {
        var c = new Cls();
        c.instanciable = type.instanciable;
        c.singleton = type.singleton;
        c.packagePath = 'godot';
        c.className = '${type.name}';
        c.rawClassName = '${type.name}';
        c.properties = type.properties;
        var skip_methods = [];
        for(p in type.properties.filter(f -> f.hasGetterOrSetter)) {
          if(!p.getter.isEmpty()) skip_methods.push(p.getter);
          if(!p.setter.isEmpty()) skip_methods.push(p.setter);
        }
        c.imports.push("godot.core.*");
        if(!type.base_class.isEmpty()) {
          c.extendsClass = '${type.base_class}';
        }
        for(method in type.methods) {
          var m = new Method();
          m.native = method.name;
          m.name = '__${method.name}';
          m.returnType = method.return_type;
          if(method.is_const) m.metadata.push("const");
          if(method.is_editor) m.metadata.push("editor");
          if(method.is_from_script) m.metadata.push("from_script");
          if(method.is_noscript) m.metadata.push("noscript");
          if(method.is_reverse) m.metadata.push("reverse");
          if(method.is_virtual) m.metadata.push("virtual");

          m.arguments = method.arguments;

          c.native_methods.push(m);

          if(skip_methods.contains(method.name)) continue;

          var m = new Method();
          m.name = Util.sanitize(method.name);
          m.isPrivate = m.name.startsWith("_");
          m.native = '__${method.name}';
          m.returnType = method.return_type;
          m.isStatic = type.singleton;

          m.arguments = method.arguments;

          c.methods.push(m);
        }

        for(e in type.enums) {
          var ecls = new EnumClass();
          ecls.name = e.name;
          for(key in e.values.keys()) {
            ecls.values.push({key: key, value: e.values.get(key)});
          }
          ecls.values.sort((a, b) -> a.value - b.value);
          c.enums.push(ecls);
        }

        for(key in type.constants.keys()) {
          c.constants.push({
            key: key,
            value: type.constants.get(key),
          });
          c.constants.sort((a, b) -> a.value - b.value);
        }

        classes.push(c);
      }
    }

    if(!sys.FileSystem.exists("godot")) {
      sys.FileSystem.createDirectory("godot");
    }

    for(cls in classes) {
      sys.io.File.saveContent('godot/${cls.className}.hx', cls.renderClass());
    }

    //trace(foundTypes);
  }
}

class Cls {
  public var instanciable:Bool = false;
  public var singleton:Bool = false;
  public var rawClassName:String;
  public var className:String;
  public var packagePath:String;
  public var extendsClass:String;

  public var enums:Array<EnumClass> = [];

  public var imports:Array<String> = [];

  public var constants:Array<KV<Int>> = [];
  public var properties:Array<PropertyData> = [];
  public var methods:Array<Method> = [];
  public var native_methods:Array<Method> = [];

  public function new() {

  }


  @:template("Class.tt") public function renderClass();
}

class Method {
  public var isStatic:Bool = false;
  public var isPrivate:Bool = false;
  public var native:String;
  public var name:String;
  @:isVar public var returnType(default, set):String;
  public var canReturn:Bool = false;
  public var returnValue:String = "null";

  public var metadata:Array<String> = [];
  @:isVar public var arguments(default, set):Array<ArgumentData> = [];
  public var args:String;
  public var callArgs:String;
  public function new() {

  }
  function set_arguments(v:Array<ArgumentData>) {
    if(v.length > 0) {
      callArgs = v.map(a -> a.name).join(", ");
      args = v.map(a -> '${a.name}:${a.type}${(a.has_default_value) ? ' = ${a.default_value}' : ""}').join(", ");
    }
    return arguments = v;
  }
  function set_returnType(v:String) {
    canReturn = v != "Void";
    returnValue = switch(v) {
      case "Bool": "false";
      case "Int": "0";
      case "Float": "0";
      case _: "null";
    }
    return returnType = v;
  }
}

class EnumClass {
  public var name:String;
  public var values:Array<KV<Int>> = [];

  public function new() {

  }
}

class Util {
  static var keywords = ["public", "private", "static", "override", "dynamic", "inline", "macro", "function", "class", "static", "var", "if", "else", "while", "do", "for", "break", "return", "continue", "extends", "implements", "import", "switch", "case", "default", "private", "public", "try", "catch", "new", "this", "throw", "extern", "enum", "in", "interface", "untyped", "cast", "override", "typedef", "dynamic", "package", "inline", "using", "null", "true", "false", "abstract", "macro"];
  public static function sanitize(v:String):String {
    return ((keywords.contains(v) ? '${v}_' : v):String).replace("/", "_");
  }

  public static function defaultValueToHaxe(type:String, v:String) {
    return switch(type) {
      case "bool", "int": v.toLowerCase();
      case "String": '"${v}"';
      case "Color": 'new Color(${v})';
      case "Array": 'new haxe.ds.Vector<Dynamic>()';
      case "PoolColorArray": "new haxe.ds.Vector<Color>()";
      case "PoolVector3Array": "new haxe.ds.Vector<Vector3>()";
      case "PoolVector2Array": "new haxe.ds.Vector<Vector2>()";
      case "PoolStringArray": "new haxe.ds.Vector<String>()";
      case "PoolRealArray": "new haxe.ds.Vector<Float>()";
      case "PoolIntArray": "new haxe.ds.Vector<Int>()";
      case "PoolByteArray": "new haxe.ds.Vector<Int>()";
      case "Vector2": 'new Vector2${v}';
      case "Vector3": 'new Vector3${v}';
      case "Transform": 'new Transform()';
      case "Transform2D": 'new Transform2D()';
      case "Rect2": 'new Rect2${v}';
      case "Variant": 'new Variant(${v})';
      case "RID": 'new RID()';
      case _:
        if(v == "Null" || v == "[Object:null]")
          "null";
        else
          v;
    }
  }

  public static function baseTypeToHaxe(t:String) {
    return switch(t) {
      case "int": "Int";
      case "string": "String";
      case "float": "Float";
      case "Array": "haxe.ds.Vector<Dynamic>";
      case "PoolColorArray": "haxe.ds.Vector<Color>";
      case "PoolVector3Array": "haxe.ds.Vector<Vector3>";
      case "PoolVector2Array": "haxe.ds.Vector<Vector2>";
      case "PoolStringArray": "haxe.ds.Vector<String>";
      case "PoolRealArray": "haxe.ds.Vector<Float>";
      case "PoolIntArray": "haxe.ds.Vector<Int>";
      case "PoolByteArray": "haxe.ds.Vector<Int>";
      case "bool": "Bool";
      case "void": "Void";
      case x if (x.startsWith("enum")): 
         var t = x.after(".");
         t = t.replace("::", ".");
        t;
      case _: 
        //trace(t);
        t;
    }
  }
}