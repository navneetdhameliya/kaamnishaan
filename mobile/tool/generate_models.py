#!/usr/bin/env python3
"""Generate the app's API models from the backend contract, in the Neho model style.

    python3 mobile/tool/generate_models.py          # write lib/infrastructure/models/api_models.g.dart
    python3 mobile/tool/generate_models.py --check  # fail if the file is out of date (CI)

Each schema `SessionOut` becomes `class SessionOutModel` with `fromJson` / `toJson`, plus
`sessionOutModelFromJson(String)` and `sessionOutModelToJson(...)`. Fields the contract marks as
required are non-nullable; the others are nullable. Dates become DateTime.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "shared/api/openapi.generated.json"
OUT = ROOT / "mobile/lib/infrastructure/models/api_models.g.dart"
SKIP = {"HTTPValidationError", "ValidationError"}
RESERVED = {
    "abstract", "as", "assert", "async", "await", "break", "case", "catch", "class", "const", "continue",
    "default", "do", "dynamic", "else", "enum", "export", "extends", "external", "factory", "false", "final",
    "finally", "for", "get", "if", "implements", "import", "in", "is", "late", "library", "new", "null",
    "operator", "part", "required", "rethrow", "return", "set", "static", "super", "switch", "this", "throw",
    "true", "try", "var", "void", "while", "with", "yield", "hashCode", "runtimeType", "toString",
}


def model(name: str) -> str:
    return f"{name}Model"


def camel(name: str) -> str:
    parts = [p for p in re.split(r"[_\W]+", name) if p]
    out = parts[0][:1].lower() + parts[0][1:] + "".join(p[:1].upper() + p[1:] for p in parts[1:])
    if out[0].isdigit():
        out = "v" + out
    return out + "Value" if out in RESERVED else out


def lower_first(s: str) -> str:
    return s[:1].lower() + s[1:]


class Kind:
    """How one JSON value is typed in Dart and how it is read and written."""

    def __init__(self, dart: str, read: str = "{v}", write: str = "{v}", ref: str | None = None):
        self.dart, self.read_t, self.write_t, self.ref = dart, read, write, ref

    def read(self, v: str) -> str:
        return self.read_t.format(v=v)

    def write(self, v: str) -> str:
        return self.write_t.format(v=v)


def kind(s: dict) -> tuple[Kind, bool]:
    """(Dart kind, nullable)"""
    if "anyOf" in s:
        options = [o for o in s["anyOf"] if o.get("type") != "null"]
        nullable = len(options) < len(s["anyOf"])
        if len(options) == 1:
            k, _ = kind(options[0])
            return k, nullable
        return Kind("dynamic"), True
    if "$ref" in s:
        name = s["$ref"].rsplit("/", 1)[-1]
        return Kind(model(name), f"{model(name)}.fromJson({{v}} as Map<String, dynamic>)", "{v}.toJson()", ref=name), False
    t = s.get("type")
    if t == "string":
        if s.get("format") == "date-time":
            return Kind("DateTime", "DateTime.parse({v} as String)", "{v}.toIso8601String()"), False
        return Kind("String", "{v} as String"), False
    if t == "integer":
        return Kind("int", "({v} as num).toInt()"), False
    if t == "number":
        return Kind("double", "({v} as num).toDouble()"), False
    if t == "boolean":
        return Kind("bool", "{v} as bool"), False
    if t == "array":
        inner, inner_null = kind(s.get("items", {}))
        q = "?" if inner_null and inner.dart != "dynamic" else ""
        if inner.dart == "dynamic":
            return Kind("List<dynamic>", "List<dynamic>.from({v} as List)"), False
        rd = inner.read("e")
        wr = inner.write("e")
        if inner_null:
            rd = f"e == null ? null : {rd}"
            wr = f"e == null ? null : {inner.write('e!')}" if wr != "e" else "e"
        read = f"({{v}} as List).map((e) => {rd}).toList()" if rd != "e" else "List<" + inner.dart + q + ">.from({v} as List)"
        write = f"{{v}}.map((e) => {wr}).toList()" if wr != "e" else "{v}"
        return Kind(f"List<{inner.dart}{q}>", read, write), False
    if t == "object" or "additionalProperties" in s:
        return Kind("Map<String, dynamic>", "Map<String, dynamic>.from({v} as Map)"), False
    return Kind("dynamic"), True


def gen_class(name: str, s: dict) -> str:
    props = s.get("properties", {})
    required = set(s.get("required", []))
    fields = []
    for key, ps in props.items():
        k, nullable = kind(ps)
        optional = nullable or key not in required
        fields.append((key, camel(key), k, optional, ps))
    cls = model(name)
    L = []
    if s.get("description"):
        for line in s["description"].strip().splitlines():
            L.append(f"/// {line}".rstrip())
    L.append(f"{cls} {lower_first(cls)}FromJson(String str) => {cls}.fromJson(json.decode(str) as Map<String, dynamic>);")
    L.append("")
    L.append(f"String {lower_first(cls)}ToJson({cls} data) => json.encode(data.toJson());")
    L.append("")
    L.append(f"class {cls} {{")
    for key, f, k, optional, ps in fields:
        if ps.get("description"):
            L.append(f"  /// {ps['description'].splitlines()[0]}")
        enum = ps.get("enum") or next((o.get("enum") for o in ps.get("anyOf", []) if o.get("enum")), None)
        if enum:
            L.append(f"  /// One of: {', '.join(map(str, enum))}")
        q = "?" if optional and k.dart != "dynamic" else ""
        L.append(f"  final {k.dart}{q} {f};")
    if fields:
        L.append("")
        L.append(f"  const {cls}({{")
        for key, f, k, optional, _ in fields:
            L.append(f"    {'' if optional else 'required '}this.{f},")
        L.append("  });")
    else:
        L.append("")
        L.append(f"  const {cls}();")
    L.append("")
    L.append(f"  factory {cls}.fromJson(Map<String, dynamic> json) => {cls}(")
    for key, f, k, optional, _ in fields:
        v = f"json['{key}']"
        simple = re.fullmatch(r"\{v\} as (\w+)", k.read_t)
        if optional and simple:
            L.append(f"        {f}: {v} as {simple.group(1)}?,")
        elif optional and k.read(v) != v:
            L.append(f"        {f}: {v} == null ? null : {k.read(v)},")
        else:
            L.append(f"        {f}: {k.read(v)},")
    L.append("      );")
    L.append("")
    L.append("  Map<String, dynamic> toJson() => {")
    for key, f, k, optional, _ in fields:
        w = k.write(f)
        if optional and w != f:
            w = k.write(f + "?")  # every converter starts with "{v}." so ?. keeps nulls as null
        L.append(f"        '{key}': {w},")
    L.append("      };")
    L.append("}")
    return "\n".join(L)


def main() -> None:
    spec = json.loads(SPEC.read_text())
    schemas = spec["components"]["schemas"]
    parts = [
        "// GENERATED by mobile/tool/generate_models.py from shared/api/openapi.generated.json — do not edit.",
        "import 'dart:convert';",
        "",
    ]
    for name in sorted(schemas):
        if name not in SKIP:
            parts.append(gen_class(name, schemas[name]))
            parts.append("")
    body = "\n".join(parts)
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text() != body:
            sys.exit("Stale API models, run: python3 mobile/tool/generate_models.py")
        print(f"API models up to date ({len(schemas) - len(SKIP & set(schemas))} models)")
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(body)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
