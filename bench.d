import jsonx;
import std.datetime;
import std.range;
import std.stdio;

void main() {
    static struct MyConfig {
        string encoding;
        string[] plugins;
        int indent = 2;
        bool indentSpaces;
    }

    static struct X {
        real[] reals;
        int[string] ints;
        MyConfig conf;
        string foo;

        void qux() { }
    }

    string xjson = `{
        "foo" : "Baz",
        "reals" : [ 3.4, 7.2e+4, 5, 0, -33 ],
        "ints" : { "one": 1, "two": 2 },
        "bogus" : "ignore me",
        "conf" : {
            "encoding" : "UTF-8",
            "indent" : 4,
            "plugins" : [ "perl", "d" ],
            "indentSpaces" : true
        }
    }`;

    dstring dxjson = `{
        "foo" : "Baz",
        "reals" : [ 3.4, 7.2e+4, 5, 0, -33 ],
        "ints" : { "one": 1, "two": 2 },
        "bogus" : "ignore me",
        "conf" : {
            "encoding" : "UTF-8",
            "indent" : 4,
            "plugins" : [ "perl", "d" ],
            "indentSpaces" : true
        }
    }`;

    string xstring = `"abcdefghijklmnopqrstuvwxyz"`;
    dstring dxstring = `"abcdefghijklmnopqrstuvwxyz"`;

    string xstringarray = `["abcdefghijklmnopqrstuvwxyz"]`;
    dstring dxstringarray = `["abcdefghijklmnopqrstuvwxyz"]`;

    writeln("Decode string into struct -> ", bench({jsonDecode!X(xjson);}, 500000));
    writeln("Decode string into variant -> ", bench({jsonDecode(xjson);}, 500000));

    writeln("Decode dstring into struct -> ", bench({jsonDecode!X(dxjson);}, 500000));
    writeln("Decode dstring into variant -> ", bench({jsonDecode(dxjson);}, 500000));

    writeln("Decode string into string -> ", bench({jsonDecode!string(xstring);}, 5000000));
    writeln("Decode dstring into dstring -> ", bench({jsonDecode!dstring(dxstring);}, 5000000));
    writeln("Decode dstring into string -> ", bench({jsonDecode!string(dxstring);}, 5000000));
    writeln("Decode string into dstring -> ", bench({jsonDecode!dstring(xstring);}, 5000000));

    writeln("Decode string into string[] -> ", bench({jsonDecode!(string[])(xstringarray);}, 5000000));
    writeln("Decode dstring into dstring[] -> ", bench({jsonDecode!(dstring[])(dxstringarray);}, 5000000));

    auto x = jsonDecode!X(xjson);

    writeln("Encode struct into string -> ", bench({jsonEncode!string(x);}, 500000));
    writeln("Encode struct into dstring -> ", bench({jsonEncode!dstring(x);}, 500000));
}

double bench(void delegate() dg, long n) {
    StopWatch sw;
    sw.start;
    foreach(i; iota(n))
        dg();
    sw.stop;
    auto t = sw.peek;
    return cast(double)t.hnsecs / 10000000;
}
