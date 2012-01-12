d-json
======

```d
import jsonx;
import std.stdio;
import std.variant;

void main() {
    auto json = `{
        "reals" : [ 3.4, 7.2e+4, 5, 0, -33 ],
        "conf" : {
            "plugins" : [ "d", "java" ],
            "bar" : true
        }
    }`;

    // jsonDecode gives you a Variant by default, but
    // you can ask it for specific types if you like.

    auto obj = jsonDecode(json);

    writeln("your plugins are:");
    foreach(Variant plugin; obj["conf"]["plugins"]) {
        writeln("- ", plugin);
    }

    writeln("back to json: ", jsonEncode(obj));
}
```

DECODING
--------

Without special arguments, `jsonDecode` takes an input range and gives you a
[Variant](http://d-programming-language.org/phobos/std_variant.html) set to
one of these types:

- JSON arrays become `Variant[]`
- JSON objects become `Variant[string]`
- JSON strings become `string`
- JSON numbers become `real`
- JSON booleans become `bool`
- JSON nulls become `JsonNull`

You can ask for a particular type, in which case you get that instead of a
Variant. Here's an example using a struct:

```d
struct MyConfig {
    string encoding;
    string[] plugins;
    int indent = 2;
    bool indentSpaces;
}

auto json = `{
    "encoding" : "UTF-8",
    "indent" : 4,
    "plugins" : [ "d", "c++" ],
    "indentSpaces" : true
}`;

// myconf will be a MyConfig struct
auto myconf = decodeJson!MyConfig(json);
```

Builtin types like `int[]` and `string[string]` work as well.

ENCODING
--------

`jsonEncode` takes either a Variant from jsonDecode or a regular type and gives
you a `string`. Here's an example with a simple array:

```d
auto json = jsonEncode([1, 2, 3]); // "[1,2,3]"
```

You can also pass in an output range:

```d
auto f = File("test.txt", "w");
auto fw = File.LockingTextWriter(f);
jsonEncode([1, 2, 3], fw); // write to test.txt
```
