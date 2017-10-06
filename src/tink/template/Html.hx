package tink.template;

abstract Html(String) from String to String {
  public inline function new(v:String) this = v;
    
  @:from static function ofMultiple(parts:Array<Html>):Html 
    return new Html(parts.join(''));
    
  @:from static public function of<A>(a:A):Html
    return Std.string(a);

  static public function buffer():HtmlBuffer 
    return new HtmlBuffer();
}

abstract HtmlBuffer(Array<Html>) {
  public inline function new() this = [];
  
  public function collapse():Html
    return this;
  
  @:to public inline function toString():String
    return this.join('');
  
  public inline function add(b:Html)
    this.push(b);
    
}