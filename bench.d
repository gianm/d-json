/*
 * Copyright 2011-2016 Gian Merlino
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import jsonx;
import std.datetime;
import std.json;
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

    writeln("Decode string into struct -> ", bench({jsonDecode!X(xjson);}, 50000));
    writeln("Decode string into variant -> ", bench({jsonDecode(xjson);}, 50000));
    writeln("Decode string with std.json -> ", bench({parseJSON(xjson);}, 50000));

    writeln("Decode dstring into struct -> ", bench({jsonDecode!X(dxjson);}, 50000));
    writeln("Decode dstring into variant -> ", bench({jsonDecode(dxjson);}, 50000));

    auto x = jsonDecode!X(xjson);
    auto v = jsonDecode(xjson);
    auto j = parseJSON(xjson);

    writeln("Encode struct into string -> ", bench({jsonEncode!string(x);}, 50000));
    writeln("Encode struct into dstring -> ", bench({jsonEncode!dstring(x);}, 50000));

    writeln("Encode variant into string -> ", bench({jsonEncode!string(v);}, 50000));
    writeln("Encode variant into dstring -> ", bench({jsonEncode!dstring(v);}, 50000));
    writeln("Encode with std.json -> ", bench({toJSON(&j);}, 50000));

    writeln("Decode string into string -> ", bench({jsonDecode!string(xstring);}, 500000));
    writeln("Decode dstring into dstring -> ", bench({jsonDecode!dstring(dxstring);}, 500000));
    writeln("Decode dstring into string -> ", bench({jsonDecode!string(dxstring);}, 500000));
    writeln("Decode string into dstring -> ", bench({jsonDecode!dstring(xstring);}, 500000));

    writeln("Decode string into string[] -> ", bench({jsonDecode!(string[])(xstringarray);}, 500000));
    writeln("Decode dstring into dstring[] -> ", bench({jsonDecode!(dstring[])(dxstringarray);}, 500000));

    writeln("Encode string into string -> ", bench({jsonEncode!string(xstring);}, 500000));
    writeln("Encode dstring into dstring -> ", bench({jsonEncode!dstring(dxstring);}, 500000));
    writeln("Encode dstring into string -> ", bench({jsonEncode!string(dxstring);}, 500000));
    writeln("Encode string into dstring -> ", bench({jsonEncode!dstring(xstring);}, 500000));
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
