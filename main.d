import jsonx;
import std.stdio;

void main() {
    static struct MyConfig {
        string encoding;
        string[] plugins;
        int indent = 2;
        bool indentSpaces;
    }

    static class X {
        enum foos { Bar, Baz };

        real[] reals;
        int[string] ints;
        MyConfig conf;
        foos foo;

        void qux() { }
    }

    auto xjson = `{
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

    auto x = jsonDecode!X(xjson);

    auto f = File("test.txt", "w");
    auto fw = File.LockingTextWriter(f);

    foreach(i; 0..200000) {
        jsonEncode(x, fw);
        fw.put("\n");
    }
}
