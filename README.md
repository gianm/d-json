d-json
======

Decode JSON to User-Defined Type
--------------------------------

If called with a particular type, `jsonDecode!T(json)` takes an input range
`json` and gives you an instance of the type `T`. It will throw a `JsonException`
if the json is invalid or if the json is valid but cannot be coerced to type `T`.

Here's an example using a user-defined struct:

```d
import jsonx;
import std.stdio;

struct MyConfig {
    string encoding;
    string[] plugins;
    int indent = 2;
    bool indentSpaces;
}

void main() {
    auto json = `{
        "encoding" : "UTF-8",
        "indent" : 4,
        "plugins" : [ "d", "c++" ],
        "indentSpaces" : true
    }`;

    MyConfig myconf = jsonDecode!MyConfig(json);
    writeln("indent = ", myconf.indent); // Prints "4"
}
```

Builtin types like `int[]` and `string[string]` work as well.

Decode JSON to Variant
----------------------

If called without template arguments, `jsonDecode` gives you a generic `JsonValue`
(currently implemented with a [Variant](http://d-programming-language.org/phobos/std_variant.html)).

- JSON arrays are parsed as `JsonValue[]`
- JSON objects are parsed as `JsonValue[string]`
- JSON strings are parsed as `string`
- JSON numbers are parsed as `real`
- JSON booleans are parsed as `bool`
- JSON nulls are parsed as `JsonNull` structs (an empty type)

Here's an example:

```d
import jsonx;
import std.stdio;

void main() {
    auto json = `{
        "reals" : [ 3.4, 7.2e+4, 5, 0, -33 ],
        "conf" : {
            "plugins" : [ "d", "java" ],
            "bar" : true
        }
    }`;

    auto obj = jsonDecode(json);

    writeln("your plugins are:");
    foreach(JsonValue plugin; obj["conf"]["plugins"]) {
        writeln("- ", plugin);
    }

    writeln("back to json: ", jsonEncode(obj));
}
```

Encoding to JSON
----------------

`jsonEncode(v)` takes either a JsonValue from jsonDecode or a regular type
and gives you a `string`. Here's an example with a simple array:

```d
auto json = jsonEncode([1, 2, 3]); // "[1,2,3]"
```

You can ask for a `wstring` or `dstring` if you'd prefer it over a
regular `string`:

```d
auto json = jsonEncode!dstring([1, 2, 3]); // "[1,2,3]"d
```

You can also pass in an output range:

```d
auto f = File("test.txt", "w");
auto fw = File.LockingTextWriter(f);
jsonEncode([1, 2, 3], fw); // write to test.txt
```
