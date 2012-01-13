module jsonx;

import std.algorithm : find;
import std.ascii : isControl, isUpper, isDigit, isHexDigit;
import std.uni : isWhite;
import std.conv;
import std.range;
import std.traits;
import std.exception : enforceEx;
import std.variant;
import std.stdio;

// TODO: recursion depth limit
// TODO: option for sorted object keys when encoding
// TODO: option for pretty-print when encoding
// TODO: option for ascii safety when encoding
// TODO: support for comments
// TODO: more spec compliant handling of numeric types
// TODO: tests for type validation failure
// TODO: ddoc

public:

struct JsonNull { /* empty type... */ }

/* Encode to a string in memory */
R jsonEncode(T, R = string)(T obj) if(isSomeString!R) {
    auto app = appender!R;
    jsonEncode_impl(obj, app);
    return app.data;
}

/* Encode to any output range */
R jsonEncode(T, R)(T obj, R range) if(isOutputRange!(R, dchar)) {
    jsonEncode_impl(obj, range);
    return range;
}

T jsonDecode(T = Variant, R)(R input) if(isInputRange!R && isSomeChar!(ElementType!R)) {
    auto val = jsonDecode_impl!T(input);
    enforceEx!JsonException(input.empty, "garbage at end of stream");
    return val;
}

private:

void enforceChar(R)(ref R input, dchar c, bool sw) if (isInputRange!R && isSomeChar!(ElementType!R)) {
    enforceEx!JsonException(!input.empty, "premature end of input");
    enforceEx!JsonException(input.front == c, "expected " ~ to!string(c) ~ ", saw " ~ to!string(input.front));
    input.popFront;
    if(sw)
        skipWhite(input);
}

void skipWhite(R)(ref R input) if (isInputRange!R && isSomeChar!(ElementType!R)) {
    while(!input.empty && isWhite(input.front))
        input.popFront;
}

/* Encode variant. Not able to encode all variants, but should be able to round-trip
 * variants created from jsonDecode. */
void jsonEncode_impl(T : Variant, A)(T v, ref A app) {
    if(v.type() == typeid(string)) {
        jsonEncode_impl(v.get!string, app);
    } else if(v.type() == typeid(Variant[])) {
        jsonEncode_impl(v.get!(Variant[]), app);
    } else if(v.type() == typeid(Variant[string])) {
        jsonEncode_impl(v.get!(Variant[string]), app);
    } else if(v.type() == typeid(real)) {
        jsonEncode_impl(v.get!real, app);
    } else if(v.type() == typeid(bool)) {
        jsonEncode_impl(v.get!bool, app);
    } else if(v.type() == typeid(JsonNull)) {
        jsonEncode_impl(v.get!JsonNull, app);
    } else {
        throw new JsonException("can't encode variant with type " ~ to!string(v.type()));
    }
}

/* Encode string */
void jsonEncode_impl(T, A)(T str, ref A app) if(isSomeString!T) {
    app.put('"');

    /* Iterate dchars so we get unicode points as units */
    foreach(dchar c; str) {
        if(c == '\b') {
            app.put(`\b`);
        } else if(c == '\f') {
            app.put(`\f`);
        } else if(c == '\n') {
            app.put(`\n`);
        } else if(c == '\r') {
            app.put(`\r`);
        } else if(c == '\t') {
            app.put(`\t`);
        } else if(c == '"' || c == '\\') {
            app.put('\\');
            app.put(c);
        } else if(isControl(c)) {
            /* Do unicode escape */
            app.put(`\u`);
            foreach(i; retro(iota(4))) {
                /* Nybble at position i */
                auto n = (c >> (i*4)) & 0x0F;
                auto hex = n < 10 ? '0' + n : 'A' + n - 10;
                app.put(cast(char)hex);
            }
        } else {
            app.put(c);
        }
    }

    app.put('"');
}

/* Encode character */
void jsonEncode_impl(T, A)(T val, ref A app) if(isSomeChar!T) {
    jsonEncode_impl(to!string(val), app);
}

/* Encode number, bool */
void jsonEncode_impl(T, A)(T val, ref A app) if(isNumeric!T || is(T == bool)) {
    app.put(to!string(val));
}

/* Encode enum */
void jsonEncode_impl(T, A)(T val, ref A app) if(is(T == enum)) {
    jsonEncode_impl(to!string(val), app);
}

/* Encode JsonNull */
void jsonEncode_impl(T, A)(T val, ref A app) if(is(T == JsonNull)) {
    app.put("null");
}

/* Encode struct or class */
void jsonEncode_impl(S, A)(S obj, ref A app) if((is(S == struct) || is(S == class)) && !is(S == JsonNull)) {
    static if(is(S == class)) {
        /* A class could be null */
        if(obj is null) {
            app.put("null");
            return;
        }
    }

    app.put('{');
    bool first = true;

    foreach(i, val; obj.tupleof) {
        if(!first)
            app.put(',');
        first = false;

        /* obj.tupleof[i].stringof is something like "obj.member".
         * We just want "member" */
        auto key = obj.tupleof[i].stringof.find('.')[1..$];

        jsonEncode_impl(key, app);
        app.put(':');
        jsonEncode_impl(val, app);
    }

    app.put('}');
}

/* Encode array */
void jsonEncode_impl(S : T[], T, A)(S arr, ref A app) if(!isSomeString!S) {
    app.put('[');
    bool first = true;

    foreach(item; arr) {
        if(!first)
            app.put(',');
        jsonEncode_impl(item, app);
        first = false;
    }

    app.put(']');
}

/* Encode associative array */
void jsonEncode_impl(S : T[K], T, K, A)(S arr, ref A app) if(isSomeString!K) {
    app.put('{');
    bool first = true;

    // XXX provide a way to disable sorting
    foreach(key; arr.keys.sort) {
        if(!first)
            app.put(',');
        jsonEncode_impl(key, app);
        app.put(':');
        jsonEncode_impl(arr[key], app);
        first = false;
    }

    app.put('}');
}

/* Decode anything -> Variant */
Variant jsonDecode_impl(T : Variant, R)(ref R input) if(isInputRange!R && isSomeChar!(ElementType!R)) {
    Variant v;

    enforceEx!JsonException(!input.empty, "premature end of input");

    if(input.front == '"') {
        v = jsonDecode_impl!string(input);
    } else if(input.front == '[') {
        v = jsonDecode_impl!(Variant[])(input);
    } else if(input.front == '{') {
        v = jsonDecode_impl!(Variant[string])(input);
    } else if(input.front == '-' || (input.front >= '0' && input.front <= '9')) {
        v = jsonDecode_impl!real(input);
    } else if(input.front == 't' || input.front == 'f') {
        v = jsonDecode_impl!bool(input);
    } else if(input.front == 'n') {
        v = jsonDecode_impl!JsonNull(input);
    } else {
        throw new JsonException("can't decode into variant");
    }

    return v;
}

/* Decode JSON object -> D associative array, class, or struct */
T jsonDecode_impl(T, R)(ref R input)
  if(isInputRange!R && isSomeChar!(ElementType!R)
    && (is(T == struct) || is(T == class) || isAssociativeArray!T)
    && !is(T : JsonNull))
{
    auto first = true;

    static if(is(T == class)) {
        auto obj = new T;

        /* Classes can be null */
        if(!input.empty && input.front == 'n') {
            jsonDecode_impl!JsonNull(input);
            return null;
        }
    } else static if(is(T == struct) || isAssociativeArray!T) {
        T obj;
    } else static assert(0);

    /* First character should be '{' */
    enforceChar(input, '{', true);

    while(!input.empty) {
        if(input.front == '}') {
            /* } is the last character */
            input.popFront;
            return obj;
        }

        if(!first) {
            /* All key/value pairs after the first should be preceded by commas */
            enforceChar(input, ',', true);
        }

        /* Read key */
        auto key = jsonDecode_impl!string(input);
        skipWhite(input);

        /* Read colon */
        enforceChar(input, ':', true);

        /* Determine type of value */
        static if(isAssociativeArray!T) {
            /* Arrays are composed of only one type */
            obj[key] = jsonDecode_impl!(typeof(obj[key]))(input);
        } else {
            /* Get class and struct members from tupleof */
            bool didRead = false;

            foreach(i, oval; obj.tupleof) {
                /* obj.tupleof[i].stringof is something like "obj.member".
                 * We just want "member" */
                if(key == obj.tupleof[i].stringof.find('.')[1..$]) {
                    /* Assigning to oval doesn't seem to work, but obj.tupleof[i] does */
                    obj.tupleof[i] = jsonDecode_impl!(typeof(obj.tupleof[i]))(input);
                    didRead = true;
                    break;
                }
            }

            if(!didRead) {
                /* eek. Read the value and toss it */
                jsonDecode_impl!Variant(input);
            }
        }

        skipWhite(input);
        first = false;
    }

    /* Premature end of input */
    throw new JsonException("premature end of input");
    assert(0);
}

/* Decode JSON array -> D array */
T[] jsonDecode_impl(A : T[], T, R)(ref R input) if(isInputRange!R && isSomeChar!(ElementType!R) && !isSomeString!A) {
    auto first = true;
    auto app = appender!(T[]);

    /* First character should be '[' */
    enforceChar(input, '[', true);

    while(!input.empty) {
        if(input.front == ']') {
            /* ] is the last character */
            input.popFront;
            return app.data;
        }

        if(!app.data.empty) {
            /* All values after the first should be preceded by commas */
            enforceChar(input, ',', true);
        }

        /* Read value */
        app.put(jsonDecode_impl!T(input));
        skipWhite(input);
    }

    /* Premature end of input */
    throw new JsonException("premature end of input");
    assert(0);
}

/* Decode JSON number -> D number */
T jsonDecode_impl(T, R)(ref R input) if(isInputRange!R && isSomeChar!(ElementType!R) && isNumeric!T) {
    try {
        return parse!T(input);
    } catch(ConvException e) {
        throw new JsonException("ConvException: " ~ e.msg);
    }
}

/* Decode JSON string -> D string */
T jsonDecode_impl(T, R)(ref R input) if(isInputRange!R && isSomeChar!(ElementType!R) && isSomeString!T) {
    auto app = Appender!T();

    /* For strings we can attempt to decode without copying */
    enum canReuseInput = is(T == R);
    static if(canReuseInput) {
        /* If inputSave is set, it means we don't yet need to copy */
        auto inputSave = input.save;
    }

    /* First character should be '"' */
    enforceChar(input, '"', false);

    while(!input.empty) {
        if(input.front == '"') {
            /* End of string */
            input.popFront;

            static if(canReuseInput) {
                if(inputSave)
                    return inputSave[1 .. inputSave.length - input.length - 1];
            }

            return app.data;
        } else if(input.front == '\\') {
            /* Escape sequence */

            static if(canReuseInput) {
                /* We need to use the appender */
                if(inputSave) {
                    app = Appender!T(inputSave[1 .. inputSave.length - input.length]);
                    inputSave = null;                    
                }
            }

            /* Advance to escaped character */
            input.popFront;
            enforceEx!JsonException(!input.empty, "premature end of input");

            switch(input.front) {
                case '"':
                case '\\':
                case '/': app.put(input.front); input.popFront; break;
                case 'b': app.put('\b'); input.popFront; break;
                case 'f': app.put('\f'); input.popFront; break;
                case 'n': app.put('\n'); input.popFront; break;
                case 'r': app.put('\r'); input.popFront; break;
                case 't': app.put('\t'); input.popFront; break;
                case 'u':
                    /* Unicode escape coming up */
                    input.popFront;

                    /* Function to read the next 4 hex digits from "input" into a wchar */
                    wchar nextUnit() {
                        wchar unit = 0;

                        foreach(i; retro(iota(4))) {
                            enforceEx!JsonException(!input.empty, "encountered eof inside unicode escape");

                            /* Read hex digit */
                            dchar hex = input.front;
                            enforceEx!JsonException(isHexDigit(hex), "encountered non-hex digit inside unicode escape");

                            /* Convert to number */
                            auto val = isDigit(hex) ? hex - '0'
                                     : isUpper(hex) ? hex - 'A' + 10
                                     : hex - 'a' + 10;

                            /* Fill in the nybble */
                            unit |= (val << (i * 4));

                            /* Advance stream */
                            input.popFront;
                        }

                        return unit;
                    }

                    /* Unicode escape state */
                    wchar units[2];

                    /* Read first unit */
                    units[0] = nextUnit;
                    if(units[0] < 0xD800 || units[0] > 0xD8FF) {
                        /* Only one utf16 code unit needed */
                        app.put(units[0]);
                    } else {
                        /* units[0] is the first half of a two-unit utf16 code */
                        /* Expect another \u */
                        enforceChar(input, '\\', false);
                        enforceChar(input, 'u', false);

                        /* Read next unit */
                        units[1] = nextUnit;

                        /* units.front will return a dchar merging both units */
                        app.put(units.front);
                    }

                    break;

                default:
                    throw new JsonException("encountered bogus escape sequence");
            }
        } else if(isControl(input.front)) {
            /* Error - JSON strings cannot include raw control characters */
            throw new JsonException("encountered raw control character");
        } else {
            /* Regular character */
            static if(canReuseInput) {
                if(!inputSave) app.put(input.front);
            } else {
                app.put(input.front);
            }
            input.popFront;
        }
    }

    /* Premature end of input */
    throw new JsonException("premature end of input");
    assert(0);
}

/* Decode JSON string -> char, enum */
T jsonDecode_impl(T, R)(ref R input)
  if(isInputRange!R && isSomeChar!(ElementType!R) && (isSomeChar!T || is(T == enum)))
{
    return to!T(jsonDecode_impl!string(input));
}

/* Decode JSON bool -> D bool */
bool jsonDecode_impl(T, R)(ref R input) if(isInputRange!R && isSomeChar!(ElementType!R) && is(T == bool)) {
    enforceEx!JsonException(!input.empty, "premature end of input");
    if(input.front == 't') {
        input.popFront;
        enforceChar(input, 'r', false);
        enforceChar(input, 'u', false);
        enforceChar(input, 'e', false);
        return true;
    } else if(input.front == 'f') {
        input.popFront;
        enforceChar(input, 'a', false);
        enforceChar(input, 'l', false);
        enforceChar(input, 's', false);
        enforceChar(input, 'e', false);
        return false;
    }

    assert(0);
}

/* Decode JSON null -> D null */
JsonNull jsonDecode_impl(T, R)(ref R input) if(isInputRange!R && isSomeChar!(ElementType!R) && is(T == JsonNull)) {
    enforceEx!JsonException(!input.empty, "premature end of input");
    enforceChar(input, 'n', false);
    enforceChar(input, 'u', false);
    enforceChar(input, 'l', false);
    enforceChar(input, 'l', false);
    return JsonNull();
}

class JsonException : Exception {
    this(string s) {
        super(s);
    }
}

unittest {
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

    /* String decodes */
    assert(jsonDecode(`""`) == "");
    assert(jsonDecode(`"\u0391 \u0392\u0393\t\u03B3\u03b4"`) == "\u0391 \u0392\u0393\t\u03B3\u03B4");
    assert(jsonDecode(`"\uD834\uDD1E"`) == "\U0001D11E");

    /* String encodes */
    assert(jsonEncode("he\u03B3l\"lo") == "\"he\u03B3l\\\"lo\"");
    assert(jsonEncode("\U0001D11E and \u0392") == "\"\U0001D11E and \u0392\"");

    /* Structured decode into user-defined type */
    auto x = jsonDecode!X(`null`);
    assert(x is null);

    x = jsonDecode!X(`{}`);
    assert(x !is null);
    assert(x.conf.indent == 2);
    assert(x.foo == X.foos.Bar);

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

    x = jsonDecode!X(xjson);
    assert(x !is null);
    assert(x.foo == X.foos.Baz);
    assert(x.reals == [3.4L, 72000, 5, 0, -33]);
    assert(x.ints["one"] == 1);
    assert(x.ints["two"] == 2);
    assert(x.conf.encoding == "UTF-8");
    assert(x.conf.plugins == ["perl", "d"]);
    assert(x.conf.indent == 4);
    assert(x.conf.indentSpaces == true);

    /* Structured encode */
    assert(jsonEncode(x) ==
        `{"reals":[3.4,72000,5,0,-33],"ints":{"one":1,"two":2},"conf":{"encoding":"UTF-8","plugins":["perl","d"],"indent":4,"indentSpaces":true},"foo":"Baz"}`);

    /* Structured decode into variant */
    auto xv = jsonDecode(`null`);
    assert(xv.type() == typeid(JsonNull));

    xv = jsonDecode(xjson);
    assert(xv["bogus"] == "ignore me");
    assert(xv["foo"] == "Baz");
    assert(xv["reals"][0] == 3.4L);
    assert(xv["reals"][1] == 72000L);
    assert(xv["reals"][2] == 5L);
    assert(xv["reals"][3] == 0L);
    assert(xv["reals"][4] == -33L);
    assert(xv["ints"]["two"] == 2);
    assert(xv["ints"]["two"] == 2);
    assert(xv["conf"]["encoding"] == "UTF-8");
    assert(xv["conf"]["plugins"][0] == "perl");
    assert(xv["conf"]["plugins"][1] == "d");
    assert(xv["conf"]["indent"] == 4);
    assert(xv["conf"]["indentSpaces"] == true);

    /* Encode variant back to JSON */
    assert(jsonEncode(xv) ==
        `{"bogus":"ignore me","conf":{"encoding":"UTF-8","indent":4,"indentSpaces":true,"plugins":["perl","d"]},"foo":"Baz","ints":{"one":1,"two":2},"reals":[3.4,72000,5,0,-33]}`);

    /* All truncated streams should be errors */
    foreach(i;iota(xjson.length)) {
        bool caught;

        if(i < xjson.length) {
            caught = false;
            try {
                jsonDecode(xjson[0..i]);
            } catch(JsonException) {
                caught = true;
            }
            assert(caught);

            caught = false;
            try {
                jsonDecode!X(xjson[0..i]);
            } catch(JsonException) {
                caught = true;
            }
            assert(caught);
        }

        if(i > 0) {
            caught = false;
            try {
                jsonDecode(xjson[i..$]);
            } catch(JsonException) {
                caught = true;
            }
            assert(caught);            

            caught = false;
            try {
                jsonDecode!X(xjson[i..$]);
            } catch(JsonException) {
                caught = true;
            }
            assert(caught);
        }
    }
}
