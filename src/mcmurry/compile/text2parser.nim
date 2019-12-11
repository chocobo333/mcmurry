
import os

import
    strutils,
    sequtils,
    algorithm,
    strformat

import
    sets,
    tables

import macros
import ast_pattern_matching

import regex

import private/parserdef
import private/core

# export parserdef

var parser = Parser()

const license = staticRead("."/".."/".."/".."/"LICENSE")

# TODO: fix
proc raiseSyntaxError*(program: string, pos: int, msg: string = "") =
    var
        str: string = "\n"
        n: int = min(pos, 5)
    for i, c in program[max(pos-5, 0)..pos]:
        if c == '\n':
            n = min(pos, 5)-i-1
    str &= "$1\n$2^\n" % @[program[max(pos-5, 0)..min(pos+5, program.len-1)], ' '.repeat(n)]
    raise newException(SyntaxError, str & msg)


template log(variable: untyped): untyped =
    stderr.write astToStr(variable) & ":\n" & ($variable).indent(4) & "\n"


# module@[]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="]]
#     └---directive@[[ ANNON5  : "filename"]]
#     └---name@[[RULENAME : "parser"]]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="]]
#     └---directive@[[ ANNON4  : "toplevel"]]
#     └---name@[[RULENAME : "module"]]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  integer:\x0A    intval:\x0A      int\x0AEND"]]
#     └---directive@[[ ANNON2  : "node"]]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  INT:\x0A    intval:\x0A      int\x0AEND"]]
#     └---directive@[[ ANNON3  : "token"]]
# └---statement@[[   LF    : "\x0A"]]
# └---ruledef@[[RULENAME : "module"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---repeat_expr@[[ ANNON12 : "+"]]
#         └---name@[[RULENAME : "statement"]]
# └---ruledef@[[RULENAME : "statement"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "simple_stmt"]]
#     └---name@[[RULENAME : "compound_stmt"]]
#     └---name@[[TOKENNAME: "LF"]]
# └---ruledef@[[RULENAME : "simple_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---name@[[RULENAME : "small_stmt"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---pattern@[[   STR   : "\";\""]]
#                 └---name@[[RULENAME : "small_stmt"]]
# └---ruledef@[[RULENAME : "small_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "pass_stmt"]]
#     └---name@[[RULENAME : "expr_stmt"]]
# └---ruledef@[[RULENAME : "compound_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "if_stmt"]]
#     └---name@[[RULENAME : "while_stmt"]]
# └---ruledef@[[RULENAME : "if_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---pattern@[[   STR   : "\"if\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\":\""]]
#         └---name@[[RULENAME : "suite"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---pattern@[[   STR   : "\"elif\""]]
#                 └---name@[[RULENAME : "expression"]]
#                 └---pattern@[[   STR   : "\":\""]]
#                 └---name@[[RULENAME : "suite"]]
#         └---expression@[[ ANNON15 : "["], [ ANNON14 : "]"]]
#             └---pattern@[[   STR   : "\"else\""]]
#             └---pattern@[[   STR   : "\":\""]]
#             └---name@[[RULENAME : "suite"]]
# └---ruledef@[[RULENAME : "while_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---pattern@[[   STR   : "\"while\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\":\""]]
#         └---name@[[RULENAME : "suite"]]
# └---ruledef@[[RULENAME : "suite"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "simple_stmt"]]
#     └---ruleright@[]
#         └---name@[[TOKENNAME: "INDENT"]]
#         └---repeat_expr@[[ ANNON12 : "+"]]
#             └---name@[[RULENAME : "statement"]]
#         └---name@[[TOKENNAME: "DEDENT"]]
# └---ruledef@[[RULENAME : "pass_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---pattern@[[   STR   : "\"pass\""]]
# └---ruledef@[[RULENAME : "expr_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "simple_expr"]]
# └---ruledef@[[RULENAME : "expression"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "simple_expr"]]
#     └---name@[[RULENAME : "if_expr"]]
# └---ruledef@[[RULENAME : "simple_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "arrow_expr"]]
# └---ruledef@[[RULENAME : "arrow_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---name@[[RULENAME : "assign_expr"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---name@[[TOKENNAME: "OP0"]]
#                 └---name@[[RULENAME : "assign_expr"]]
# └---ruledef@[[RULENAME : "assign_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---name@[[RULENAME : "plus_expr"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---name@[[TOKENNAME: "OP1"]]
#                 └---name@[[RULENAME : "plus_expr"]]
# └---ruledef@[[RULENAME : "plus_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---name@[[RULENAME : "atom"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---name@[[TOKENNAME: "OP8"]]
#                 └---name@[[RULENAME : "atom"]]
# └---ruledef@[[RULENAME : "atom"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [   LF    : "\x0A  "], [   LF    : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[[ ANNON16 : "->"], [RULENAME : "ident"]]
#         └---name@[[TOKENNAME: "NAME"]]
#     └---ruleright@[[ ANNON16 : "->"], [RULENAME : "integer"], [ ANNON6  : "="], [ NIMCODE : "NIM:\x0A    result.intval = parseInt([0].val)\x0A  END"]]
#         └---name@[[TOKENNAME: "INT"]]
#     └---ruleright@[[ ANNON16 : "->"], [RULENAME : "true"]]
#         └---pattern@[[   STR   : "\"true\""]]
#     └---ruleright@[[ ANNON16 : "->"], [RULENAME : "false"]]
#         └---pattern@[[   STR   : "\"false\""]]
#     └---ruleright@[]
#         └---pattern@[[   STR   : "\"(\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\")\""]]
# └---ruledef@[[RULENAME : "if_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---pattern@[[   STR   : "\"if\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\":\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\"else\""]]
#         └---pattern@[[   STR   : "\":\""]]
#         └---name@[[RULENAME : "expression"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  import\x0A    strutils\x0A\x0A  var nIndent: seq[int] = @[0]\x0AEND"]]
#     └---directive@[[ ANNON0  : "nim"]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  if str in [\"aa\"]:\x0A    aiueo\x0A  TOKEN\x0AEND"], [   LF    : "\x0A"]]
#     └---pattern@[[   STR   : "\"aa\""]]
# └---tokendef@[[ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  if str in [\"+\", \"-\"]:\x0A    OP8\x0A  elif str in [\"==\", \"<=\", \">=\", \"<\", \">\"]:\x0A    OP5\x0A  elif str.endsWith(\"=\"):\x0A    OP1\x0A  elif str == \"=>\" or str == \"->\":\x0A    OP0\x0A  else:\x0A    OP10\x0AEND"], [   LF    : "\x0A"]]
#     └---pattern@[[  RSTR   : "r\"[\\+\\-\\*\\/\\^\\=\\~\\>]+\""]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "NAME"]]
#     └---pattern@[[  RSTR   : "r\"[a-zA-Z_][a-zA-z_0-9]*\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "INT"]]
#     └---pattern@[[  RSTR   : "r\"[1-9][0-9]*\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "STRING"]]
#     └---pattern@[[  RSTR   : "r\"(\"\")[^\"\"\\\\]*(\\\\.[^\"\"\\\\]*)*(\"\")\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "DOCSTR"]]
#     └---pattern@[[  RSTR   : "r\"\\n?\\s*##[^\\n]*\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "COMMENT"]]
#     └---pattern@[[  RSTR   : "r\"\\n?\\s*#[^\\n]*\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  if len - 1 > nIndent[^1]:\x0A    nIndent.add len - 1\x0A    INDENT\x0A  elif len - 1 < nIndent[^1]:\x0A    while len - 1 != nIndent[^1]:\x0A      discard nIndent.pop()\x0A      kind_stack.add DEDENT\x0A      if nIndent.len == 0:\x0A        raise newException(SyntaxError, \"Invalid indent.\")\x0A    discard kind_stack.pop()\x0A    DEDENT\x0A  else:\x0A    LF\x0AEND"], [   LF    : "\x0A"]]
#     └---pattern@[[  RSTR   : "r\"\\n[ ]*\""]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "SPACE"]]
#     └---pattern@[[  RSTR   : "r\"\\s+\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="], [ ANNON8  : "/"]]
#     └---directive@[[ ANNON1  : "ignore"]]
#     └---name@[[TOKENNAME: "SPACE"]]
#     └---name@[[TOKENNAME: "COMMENT"]]

template ladd(self: string, val: string) =
    self.add val.indent(ind*spi) & lf


proc compile_parser*(src: string, classname: openArray[string], typsec: string) =
    type
        N = Parser.Node
        NK = Parser.NodeKind
        T = Parser.Token
        TK = Parser.TokenKind

    let
        parsertypename = classname[0]
        nodetypename = classname[1]
        tokentypename = classname[2]
        tokenkindtypename = tokentypename & "Kind"
        treetypename = classname[3]
        treekindtypename = treetypename & "Kind"

        imports = ["mcmurry/compile/importance", "re", "strutils"]

    var
        ret: seq[string]

        lic: string
        input: string
        typsec = typsec
        imprtsec: string
        nimsec: string
        resec: string
        lexerproc: string
        parserproc: string

    block LICENCE:
        lic = "#[ LICENSE:\n"
        lic &= license.indent(4)
        lic &= "\n"
        lic &= "Created by mcmurry; module for generating lexer/parser.".indent(4)
        lic &= "\n]#\n\n"

    block INPUT:
        input = "# INPUT:\n"
        for e in src.splitLines:
            input.add "# $1\n" % [e]
        input.add "\n"

    let
        lf = "\n"
        indent = "\n    "
        spi = 4
    var
        node = parser.parse(src).simplify()
        ind = 0
        

        filename = ""
        str_annons: Table[string, int]
        rstr_annons: Table[string, int]
        str_token: seq[(string, T)]
        rstr_token: seq[(string, T)]

        ignores: seq[string]

        rules: seq[Rule]

    Visitor(Parser, findannon):
        proc pattern(self: N) =
            let
                b_str = self.tokens[0].kind == STR
                key = self.tokens[0].val
            if b_str:
                if key notin str_annons:
                    str_annons[key] = str_annons.len + rstr_annons.len
            else:
                if key notin rstr_annons:
                    rstr_annons[key] = str_annons.len + rstr_annons.len
        proc name(self: N) =
            discard

    Visitor(Parser, visit):
        var
            cur_rule: seq[Rule]
        proc name(self: N) =
            discard
        proc magic(self: N) =
            # directive
            case self.children[0].tokens[0].val
            of "filename":
                # name
                filename = self.children[1].tokens[0].val
            of "nim":
                nimsec.add "\n"
                for e in self.tokens[2].val.splitLines()[1..^2]:
                    nimsec.add e.unindent(2) & "\n"
                nimsec.add "\n"
            of "ignore":
                for e in self.children[1..^1]:
                    ignores.add e.tokens[0].val
        proc ruledef(self: N) =
            discard self.findannon()
            
        proc tokendef(self: N) =
            var
                key = self.children[0].tokens[0]
            if key.kind == STR:
                for e in str_token:
                    if e[0] == key.val:
                        raise newException(SyntaxError, "A same pattern appears twice.")
                str_token.add (key.val, self.tokens[1])
            else:
                for e in rstr_token:
                    if e[0] == key.val:
                        raise newException(SyntaxError, "A same pattern appears twice.")
                rstr_token.add (key.val, self.tokens[1])
    discard node.visit()

    block IMPRTSEC:
        for e in imports:
            imprtsec.add "import $1\n" % [e]
        imprtsec.add "\n"

    block TYPSEC:
        defer:
            typsec.add "\n"
            ind = 0
        typsec &= "\ntype\n"
        ind = 1
        typsec.add "$1* = ref object".indent(ind*4) % [parsertypename] & "\n"
        ind += 1
        typsec.ladd "i: int"
        typsec.ladd "program: string"
        typsec.ladd "programlen: int"
        typsec.ladd "pos: (int, int)"
        ind -= 1
        ind -= 1
        typsec.ladd fmt"tree2String({treetypename}, {tokentypename}, {nodetypename})"

    block NIMSEC:
        discard

    block RESEC:
        if rstr_annons.len == 0:
            break
        resec.add "let\n"
        for key, value in rstr_annons:
            resec.add "    reAnnon$1 = re($2)\n" % [$value, key]
        resec.add "\n"
        for i, e in rstr_token:
            resec.add "    re$1 = re($2)\n" % [$i, e[0]]
        resec.add "\n"

    block LEXERPROC:
        defer:
            lexerproc.add "\n"
            ind = 0
        var
            b_var = false
            typ = re(r": [\w0-9_\[\]]+ = ")
        lexerproc.add "var kind_stack: seq[$1] = @[]\n\n" % [tokenkindtypename]

        # proc program (setter, getter)
        lexerproc.add "proc program*(self: $1): string = self.program" % [parsertypename] & "\n"
        lexerproc.add "proc `program=`*(self: $1, val: string) =\n" % [parsertypename]
        lexerproc.add "    self.program = val\n"
        lexerproc.add "    self.programlen = val.len\n"
        lexerproc.add "    self.i = 0\n"
        lexerproc.add "    self.pos = (1, 1)\n"
        for e in nimsec.splitLines:
            if e == "var":
                b_var = true
                continue
            if b_var and e.startsWith("  "):
                lexerproc.add e.replace(typ, " = ").indent(2) & "\n"
            else:
                b_var = false
        lexerproc.add "\n"

        lexerproc.add "proc next*(self: $1): $2 =\n" % [parsertypename, treetypename]
        ind = 1
        lexerproc.ladd fmt"if kind_stack.len != 0:{indent}return {treetypename}(kind: {tokentypename}, tokenkind: kind_stack.pop(), pos: self.pos)"
        # lexerproc.add "var m: RegexMatch".indent(ind*4) & "\n"
        lexerproc.ladd fmt"if self.i >= self.programlen:{indent}return {treetypename}(kind: {tokentypename}, tokenkind: {tokenkindtypename}.EOF, val: ""$"", pos: self.pos)"
        for key, value in str_annons:
            lexerproc.ladd fmt"elif self.program[self.i..^1].startsWith({key}):{indent}result = {treetypename}(kind: {tokentypename}, tokenkind: {tokenkindtypename}.ANNON{value}, val: {key}, pos: self.pos){lf}    self.pos[1] += {key.len-2}"
        for key, value in rstr_annons:
            lexerproc.ladd fmt"elif self.program.matchLen(reAnnon{value}, start=self.i) != -1:"
            ind += 1
            lexerproc.ladd "var"
            ind += 1
            lexerproc.ladd fmt"len: int = self.program.matchLen(reAnnon{value}, start=self.i)"
            lexerproc.ladd fmt"str: string = self.program[self.i..self.i+len-1]"
            lexerproc.ladd fmt"lines = splitLines(str)"
            ind -= 1
            lexerproc.ladd fmt"result = {treetypename}(kind: {tokentypename}, tokenkind: {tokenkindtypename}.ANNON{value}, val: str, pos: self.pos)"
            lexerproc.ladd "self.i += len"
            lexerproc.ladd "self.pos[0] += lines.len - 1"
            lexerproc.ladd fmt"if lines.len == 1:{indent}self.pos[1] += len{lf}else:{indent}self.pos[1] = 1 + lines[^1].len"
            ind -= 1
        for i, e in str_token:
            var
                kind: string
            if e[1].kind == TOKENNAME:
                kind = e[1].val
            elif e[1].kind == NIMCODE:
                for e in e[1].val.splitLines()[1..^2]:
                    kind &= e.unindent(2) & "\n"
            lexerproc.ladd fmt"elif self.program[self.i..^1].startsWith({e[0]}):"
            ind += 1
            lexerproc.ladd "var"
            ind += 1
            lexerproc.ladd fmt"len: int = {e[0].len-2}"
            lexerproc.ladd fmt"str: string = {e[0]}"
            lexerproc.ladd fmt"lines = splitLines({e[0]})"
            lexerproc.ladd fmt"kind = block:"
            ind += 1
            lexerproc.ladd kind
            ind -= 1
            ind -= 1
            lexerproc.ladd fmt"result = {treetypename}(kind: {tokentypename}, tokenkind: kind, val: str, pos: self.pos)"
            lexerproc.ladd "self.i += len"
            lexerproc.ladd "self.pos[0] += lines.len - 1"
            lexerproc.ladd fmt"if lines.len == 1:{indent}self.pos[1] += len{lf}else:{indent}self.pos[1] = 1 + lines[^1].len"
            ind -= 1
        for i, e in rstr_token:
            var
                kind: string
            if e[1].kind == TOKENNAME:
                kind = e[1].val
            elif e[1].kind == NIMCODE:
                for e in e[1].val.splitLines()[1..^2]:
                    kind &= e.unindent(2) & "\n"
            lexerproc.ladd fmt"elif self.program.matchLen(re{i}, start=self.i) != -1:"
            ind += 1
            lexerproc.ladd "var"
            ind += 1
            lexerproc.ladd fmt"len: int = self.program.matchLen(re{i}, start=self.i)"
            lexerproc.ladd fmt"str: string = self.program[self.i..self.i+len-1]"
            lexerproc.ladd fmt"lines = splitLines(str)"
            lexerproc.ladd fmt"kind = block:"
            ind += 1
            lexerproc.ladd kind
            ind -= 1
            ind -= 1
            lexerproc.ladd fmt"result = {treetypename}(kind: {tokentypename}, tokenkind: kind, val: str, pos: self.pos)"
            lexerproc.ladd "self.i += len"
            lexerproc.ladd "self.pos[0] += lines.len - 1"
            lexerproc.ladd fmt"if lines.len == 1:{indent}self.pos[1] += len{lf}else:{indent}self.pos[1] = 1 + lines[^1].len"
            ind -= 1
        lexerproc.ladd fmt"else:{indent}raiseTokenError(self.program, self.pos, ""Unexpected characters."")"
        var
            ignore = block:
                var
                    ret = "{"
                for i, e in ignores:
                    ret.add (if i==0: "" else: ", ") & fmt"{tokenkindtypename}.{e}"
                ret.add "}"
                ret
        if ignore != "{}":
            lexerproc.ladd fmt"if result.tokenkind in {ignore}:{indent}return self.next()"
        ind -= 1
        lexerproc.add lf
        lexerproc.ladd fmt"iterator lex*(self: {parsertypename}, program: string): {treetypename} ="
        ind += 1
        lexerproc.ladd "`program=`(self, program)"
        lexerproc.ladd fmt"var ret: {treetypename}"
        lexerproc.ladd "while true:"
        ind += 1
        lexerproc.ladd "ret = self.next"
        lexerproc.ladd "yield ret"
        lexerproc.ladd fmt"if ret.tokenkind == {tokenkindtypename}.EOF:{indent}break"
        ind -= 1
        ind -= 1

    block PARSERPROC:
        defer:
            parserproc.add lf
            ind = 0

    block RETADD:
        ret.add lic             # add license
        ret.add input           # add input
        ret.add imprtsec        # add import section
        ret.add typsec          # add type section
        ret.add nimsec          # add nim section
        ret.add resec           # add regex section
        ret.add lexerproc       # add lexer section
        ret.add parserproc      # add parser section

    block OUTPUT:
        if filename == "":
            stdout.write(ret)
        else:
            var
                f = open((filename & ".nim"), fmWrite)
            defer:
                f.close()
            f.write(ret)

macro Mcmurry*(body: untyped): untyped =
    ##[
        This macro does not create a parser at compile-time but does a source file of the parser module.
    ]##

    # echo treeRepr body
    # echo repr body
    
    let
        directives = ["filename", "toplevel", "node", "token", "nim", "ignore", "parsername", "nodename", "tokenname", "treename"]
        directives_allow_nim_code = ["node", "token", "tree", "nim"]

    # Checking structure of AST.
    var
        b_nimcode = false

        tokentype: NimNode = nil
        nodetype: NimNode = nil
        treetype: NimNode = nil

        nimsec: NimNode = newStmtList()
        lexersec: seq[NimNode]
        parsersec: seq[NimNode]

        rules: seq[NimNode] = @[newEmptyNode()]
        tokens: seq[NimNode] = @[newEmptyNode(), ident"EOF"]

        typsec = nnkTypeSection.newNimNode()

        parsername = "Parser"
        nodename = "Node"
        tokenname = "Token"
        treename = "Tree"

        delast: seq[int]

        annons: HashSet[string]

        ignores: seq[NimNode]
    body.expectKind(nnkStmtList)
    for astind, ast in body:
        ast.matchAst(MatchingErrors):
        # magic
        of nnkAsgn(nnkPrefix(ident"%", `directive`@nnkIdent), `call`@{nnkIdent, nnkCall, nnkInfix}):
            if b_nimcode:
                error "`END` marker is needed.", directive
            if directive.strVal notin directives:
                error "Allowed directives only are $1" % [$directives], directive
            # NIMCODE
            if directive.strVal in directives_allow_nim_code:
                # parsing NIMCODE
                call.matchAst(CallMatchingErrors):
                of nnkCall(ident"NIM", `statement`@nnkStmtList):
                    case directive.strVal
                    of "node":
                        nodetype = statement
                    of "token":
                        tokentype = statement
                    of "tree":
                        treetype = statement
                    of "nim":
                        nimsec.add statement
                    else:
                        # cannot reach.
                        assert false
                else:
                    error $CallMatchingErrors[0], call
                b_nimcode = true
            # RULENAME
            else:
                let err = call.matchLengthKind(nnkIdent, 0)
                if err.kind != NoError:
                    if directive.strVal == "ignore":
                        call.expectKind(nnkInfix)
                        call.matchAstRecursive:
                        of `name`@nnkIdent:
                            if name.strVal == "/":
                                break
                            var
                                m: RegexMatch
                            if not name.strVal.match(re(r"[A-Z][A-Z0-9]*"), m):
                                error "Only token name can be placed here.", name
                            ignores.add name
                    else:
                        error $err, call
                else:
                    case directive.strVal
                    of "filename":
                        discard
                    of "toplevel":
                        discard
                    of "ignore":
                        ignores.add call
                    # cut ast node.
                    of "parsername":
                        parsername = call.strVal
                        delast.add astind
                    of "nodename":
                        nodename = call.strVal
                        delast.add astind
                    of "tokenname":
                        tokenname = call.strVal
                        delast.add astind
                    of "treename":
                        treename = call.strVal
                        delast.add astind
                    else:
                        # cannot reach
                        assert false
        # tokendef
        of nnkAsgn({nnkStrLit, nnkRStrLit}, `call`@{nnkIdent, nnkCall}):
            if b_nimcode:
                error "`END` marker is needed.", ast
            case call.kind
            # TOKENNAME
            of nnkIdent:
                var
                    m: RegexMatch
                if not call.strVal.match(re(r"[A-Z][A-Z0-9]*"), m):
                    error "Token name must consist of upper case character or number.", call
                if call.strVal == "EOF":
                    error "EOF is predefined.", call
                tokens.add call
            # NIMCODE
            of nnkCall:
                call.matchAst(CallMatchingErrors):
                of nnkCall(ident"NIM", `statement`@nnkStmtList):
                    b_nimcode = true
                    statement.matchAstRecursive:
                    of `tokenname`@nnkIdent:
                        var
                            m: RegexMatch
                        if tokenname.strVal.match(re(r"[A-Z][A-Z0-9]*"), m):
                            if tokenname.strVal == "EOF":
                                error "EOF is predefined.", tokenname
                            tokens.add tokenname
                    lexersec.add statement
                else:
                    error $CallMatchingErrors[0], call
            else:
                # cannot reach
                assert false
        # ruledef
        of nnkCall(`rulename`@nnkIdent, `statement`@nnkStmtList):
            if b_nimcode:
                error "`END` marker is needed.", rulename
            var
                m: RegexMatch
            if not rulename.strVal.match(re(r"[a-z][a-z_0-9]*"), m):
                error "Rule name must consist of lower case character or number.", rulename
            rules.add rulename

            # -> RULENAME
            statement.matchAstRecursive:
            of nnkInfix(ident"->", _, `rulename2`@nnkIdent):
                rules.add rule_name2
            # = NIMCODE
            statement.matchAstRecursive:
            of nnkCall(ident"NIM", `statement2`@nnkStmtList):
                parsersec.add statement2
            of `annon`@{nnkStrLit, nnkRStrLit}:
                annons.incl annon.strVal
        # `END` marker
        of ident"END":
            let err = ast.matchIdent("END")
            if err.kind != NoError:
                if b_nimcode:
                    error $err, ast
            else:
                if not b_nimcode:
                    error "`END` marker is only allowed after `NIM` section.", ast
                else:
                    b_nimcode = false
        else:
            if b_nimcode:
                error $MatchingErrors[^1], ast
            error $MatchingErrors, ast

    # Checking Nim code section.
    for i, j in delast:
        body.del(j-i)

    # nimsec: NimNode = newStmtList()
    # lexersec: seq[NimNode]
    nimsec.add nnkVarSection.newTree(
        newIdentDefs(ident"pos", nnkPar.newTree(bindSym"int", bindSym"int")),
        newIdentDefs(ident"len", bindSym"int"),
        newIdentDefs(ident"str", bindSym"string"),
        newIdentDefs(ident"kind", ident(tokenname & "Kind")),
        newIdentDefs(ident"kind_stack", nnkBracketExpr.newTree(bindSym"seq", ident(tokenname & "Kind")))
    )
    var se = ident"SyntaxError"
    nimsec.add quote do:
        type
            `se` = object of Exception
    for e in lexersec:
        nimsec.add nnkAsgn.newTree(
            ident"kind",
            nnkBlockStmt.newTree(
                newEmptyNode(),
                e
            )
        )
    
    # tokentype: NimNode
    # nodetype: NimNode
    # treetype: NimNode
    # typsec: NimNode
    # rules: seq[NimNode]
    # tokens: seq[NimNode]
    # parsersec: seq[NimNode]

    var
        pure = nnkPragma.newTree(ident"pure")

    # TreeKind
    typsec.add nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            postfix(ident(treename & "Kind"), "*"),
            pure
        ),
        newEmptyNode(),
        nnkEnumTy.newTree(newEmptyNode(), ident(tokenname), ident(nodename))
    )
    # NodeKind
    typsec.add nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            postfix(ident(nodename & "Kind"), "*"),
            pure
        ),
        newEmptyNode(),
        nnkEnumTy.newTree(rules.deduplicate)
    )
    # TokenKind
    for i in 0..<annons.len:
        tokens.add ident("ANNON" & $i)
    typsec.add nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            postfix(ident(tokenname & "Kind"), "*"),
            pure
        ),
        newEmptyNode(),
        nnkEnumTy.newTree(tokens.deduplicate)
    )
    # TODO: add procedure
    # proc intval(self: Tree): auto =
    #     if self.kind == TK:
    #         result = self.tkintval
    #     elif self.kind == ND:
    #         result = self.ndintval
    # Token
    var
        token_rec = nnkRecList.newTree(
            # newIdentDefs(ident"tokenkind", ident(tokenname & "Kind")),
            newIdentDefs(ident"val", bindSym"string"),
            newIdentDefs(ident"pos", nnkPar.newTree(bindSym"int", bindSym"int"))
        )
        token_reccase = nnkRecCase.newTree(newIdentDefs(ident"tokenkind", ident(tokenname & "Kind")))
    if not tokentype.isNil:
        for e in tokentype:
            e.matchAst(TokenMatchingError):
            of nnkCall(`tokenname`@nnkIdent, `statement`@nnkStmtList):
                var
                    m: RegexMatch
                if not tokenname.strVal.match(re(r"[A-Z][A-Z0-9]*"), m):
                    error "Only token name can be placed here.", tokenname
                if tokenname notin tokens:
                    error "Undefined token.", tokenname
                var
                    token_inner_rec = nnkRecList.newNimNode()
                    token_of_branch = nnkOfBranch.newTree(tokenname)
                for ee in statement:
                    ee.matchAst(MatchingError):
                    of nnkCall(`field`@nnkIdent, nnkStmtList(`typ`@nnkIdent)):
                        token_inner_rec.add newIdentDefs(field, typ)
                    else:
                        error $MatchingError[0], e
                token_of_branch.add token_inner_rec
                token_reccase.add token_of_branch
            else:
                error $TokenMatchingError[0], e
        token_reccase.add nnkElse.newTree(nnkRecList.newTree(newNilLit()))
        token_rec.add token_reccase

    # Node
    var
        node_rec = nnkRecList.newTree(
            # newIdentDefs(ident"nodekind", ident(nodename & "Kind")),
            newIdentDefs(ident"children", nnkBracketExpr.newTree(bindSym"seq", ident(treename)))
            # newIdentDefs(ident"pos", nnkPar.newTree(bindSym"int", bindSym"int"))
        )
        node_reccase = nnkRecCase.newTree(newIdentDefs(ident"nodekind", ident(nodename & "Kind")))
    if not nodetype.isNil:
        for e in nodetype:
            e.matchAst(NodeMatchingError):
            of nnkCall(`rulename`@nnkIdent, `statement`@nnkStmtList):
                var
                    m: RegexMatch
                if not rulename.strVal.match(re(r"[a-z][a-z_0-9]*"), m):
                    error "Only rule name can be placed here.", rulename
                if rulename notin rules:
                    error "Undefined rule.", rulename
                var
                    node_inner_rec = nnkRecList.newNimNode()
                    node_of_branch = nnkOfBranch.newTree(rulename)
                for ee in statement:
                    ee.matchAst(MatchingError):
                    of nnkCall(`field`@nnkIdent, nnkStmtList(`typ`@nnkIdent)):
                        node_inner_rec.add newIdentDefs(field, typ)
                    else:
                        error $MatchingError[0], e
                node_of_branch.add node_inner_rec
                node_reccase.add node_of_branch
            else:
                error $NodeMatchingError[0], e
        node_reccase.add nnkElse.newTree(nnkRecList.newTree(newNilLit()))
        node_rec.add node_reccase

    # Tree
    typsec.add nnkTypeDef.newTree(
        postfix(ident(treename), "*"),
        newEmptyNode(),
        nnkRefTy.newTree(
            nnkObjectTy.newTree(
                newEmptyNode(),
                newEmptyNode(),
                nnkRecList.newTree(
                    nnkRecCase.newTree(
                        newIdentDefs(ident"kind", ident(treename & "Kind")),
                        nnkOfBranch.newTree(
                            ident(tokenname),
                            token_rec
                        ),
                        nnkOfBranch.newTree(
                            ident(nodename),
                            node_rec
                        )
                    )
                )
            )
        )
    )

    for e in ignores:
        if e notin tokens:
            error "Undefined token.", e

    # for e in statement:
    #     e.matchAst(StatementMatchingErros):
    #     of nnkCall(`rulename`@nnkIdent, _):
    #         var
    #             m: RegexMatch
    #         if not rulename.strVal.match(re(r"[a-z][a-z_0-9]*"), m):
    #             error "Rule name must consist of lower case character or number.", rulename
    #     else:
    #         error $StatementMatchingErros[0], statement
    
    # returns: 
    # for e in compile_parser(astToStr(body)):
    #     echo e
    # when nimvm:
    #     when nimvm:
    #         discard
    #     else:
    #         typsec
    # else:
    #     discard
    result = newStmtList()
    result.add newCall(bindSym"compile_parser", newLit(repr(body)), newLit([parsername, nodename, tokenname, treename]), newLit(repr(typsec)))

    result.add nnkWhenStmt.newTree(
        nnkElifBranch.newTree(
            ident"nimvm",
            newStmtList(
                nnkWhenStmt.newTree(
                    nnkElifBranch.newTree(
                        ident"nimvm",
                        newStmtList(nnkDiscardStmt.newTree(newEmptyNode()))
                    ),
                    nnkElse.newTree(
                        newStmtList(
                            typsec,
                            nimsec
                        )
                    )
                )
            )
        ),
        nnkElse.newTree(
            newStmtList(nnkDiscardStmt.newTree(newEmptyNode()))
        )
    )
    