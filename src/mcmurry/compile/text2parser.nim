
import os

import
    strutils,
    sequtils,
    algorithm,
    strformat

import
    sets,
    tables

import ast_pattern_matching

import regex

import private/parserdef
import private/core
import private/utils

# export parserdef

var parser = Parser()

const license = """
MIT License

Copyright (c) 2019 chocobo333

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

"""

template log(variable: untyped): untyped =
    stderr.write astToStr(variable) & ":\n" & ($variable).indent(4) & "\n"

template ladd(self: string, val: string) =
    self.add val.indent(ind*spi) & lf

template section(name: untyped, body: untyped) =
    block name:
        let
            pind = ind
        defer:
            ind = pind
        body
    
template secblock(sec: untyped, title: string, body: untyped) =
    sec.ladd title
    block:
        let
            pind = ind
        defer:
            ind = pind
            sec.ladd ""
        ind += 1
        body

proc compile_parser*(src: string, classname: openArray[string], typsec: string) =
    type
        N = Parser.Node
        NK = Parser.NodeKind
        T = Parser.Token
        TK = Parser.TokenKind

    let
        parsertypename = classname[0]
        nodetypename = classname[1]
        nodekindtypename = nodetypename & "Kind"
        tokentypename = classname[2]
        tokenkindtypename = tokentypename & "Kind"
        treetypename = classname[3]
        treekindtypename = treetypename & "Kind"

        imports = ["mcmurry/compile/core", "re", "strutils", "sequtils"]
        exports = ["core"]

    var
        ret: seq[string]

        lic: string
        input: string
        typsec = typsec
        imprtsec: string
        nimsec: string
        resec: string
        lexerproc: string
        tmp: string
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

        toplevel = ""

        str_annons: Table[string, int]
        rstr_annons: Table[string, int]
        str_token: seq[(string, T)]
        rstr_token: seq[(string, T)]

        ignores: seq[string]

        rules: seq[Rule]
        annon_rules: seq[seq[seq[string]]]
        nimcodes: Table[int, seq[string]]

    proc parse_rules(self: N): seq[seq[string]] =
        case self.kind
        of ruledef:
            var
                ret: seq[Rule]
            for e in self.children:
                var
                    res = parse_rules(e)
                for e in res:
                    if e == @[]:
                        raise newException(ValueError, "The patter that allows empty is invalid.")
                    ret.add Rule(left: self.tokens[0].val, right: e)
            rules.add ret
        of ruleright:
            var
                alias: string
                nimcode: seq[string]
            for i, e in self.tokens:
                if e.val == "->":
                    alias = self.tokens[i+1].val
                elif e.val == "=":
                    nimcode = self.tokens[i+1].val.splitLines[1..^2]
            result = @[newSeq[string]()]
            for e in self.children:
                var
                    res = parse_rules(e)
                    tmp = result
                result = @[]
                for e in tmp:
                    for ee in res:
                        result.add e & ee
            if alias != "":
                for e in result:
                    rules.add Rule(left: alias, right: e)
                result = @[@[alias]]
        of pattern:
            case self.tokens[0].kind
            of STR:
                result.add @[fmt"ANNON{str_annons[self.tokens[0].val]}"]
            of RSTR:
                result.add @[fmt"ANNON{rstr_annons[self.tokens[0].val]}"]
            else:
                raise newException(ValueError, "cannot reach.")
        of NK.name:
            result.add @[self.tokens[0].val]
        of repeat_expr:
            var
                res = parse_rules(self.children[0])
                ret: seq[Rule]
                nannon = annon_rules.len
            if res in annon_rules:
                nannon = annon_rules.find(res)
            else:
                annon_rules.add res
                var
                    ann = fmt"annon{nannon}"
                    tmp = @[@[], @[ann]]
                for e in tmp:
                    for ee in res:
                        if (e & ee) == @[]:
                            raise newException(ValueError, "The patter that allows empty is invalid.")
                        ret.add Rule(left: ann, right: e & ee)
            var
                ann = fmt"annon{nannon}"
            case self.tokens[0].val
            of "*":
                result = @[@[], @[ann]]
            of "+":
                result = @[@[ann]]
            else:
                raise newException(ValueError, "cannot reach.")
            rules.add ret
        of atom_expr:
            result = @[newSeq[string]()]
            for e in self.children:
                var
                    res = parse_rules(e)
                    tmp = result
                result = @[]
                for e in tmp:
                    for ee in res:
                        result.add e & ee
        of expression:
            result = @[newSeq[string]()]
            for e in self.children:
                var
                    res = parse_rules(e)
                    tmp = result
                result = @[]
                for e in tmp:
                    for ee in res:
                        result.add e & ee
            result.add @[]
        else:
            raise newException(ValueError, "cannot reach.")

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
            of "toplevel":
                toplevel = self.children[1].tokens[0].val
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
            # TODO: parse rules
            discard parse_rules(self)
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
    # echo rules
    # echo nimcodes

    var
        dfa = makeDFA(rules, toplevel)
    block:
        var f = open("output.csv", fmWrite)
        defer:
            f.close()
        f.write(dfa.table)
        # echo dfa

    block IMPRTSEC:
        for e in imports:
            imprtsec.ladd fmt"import {e}"
        imprtsec.add lf
        for e in exports:
            imprtsec.ladd fmt"export {e}"
        imprtsec.add lf

    block TYPSEC:
        defer:
            typsec.add "\n"
            ind = 0
        typsec &= "\ntype\n"
        ind = 1
        section parserdef:
            typsec.ladd fmt"{parsertypename}* = ref object"
            ind += 1
            typsec.ladd "i*: int"
            typsec.ladd "program: string"
            typsec.ladd "programlen*: int"
            typsec.ladd "pos*: (int, int)"
        ind -= 1
        typsec.add lf
        typsec.ladd fmt"tree2String({treetypename}, {tokentypename}, {nodetypename})"
        typsec.ladd fmt"node_utils({treetypename}, {tokentypename}, {nodetypename})"

    block NIMSEC:
        discard

    block RESEC:
        if rstr_annons.len == 0 and rstr_token.len == 0:
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
            lexerproc.ladd fmt"elif self.program[self.i..^1].startsWith({key}):"
            lexerproc.ladd fmt"{indent}result = {treetypename}(kind: {tokentypename}, tokenkind: {tokenkindtypename}.ANNON{value}, val: {key}, pos: self.pos)"
            lexerproc.ladd fmt"{indent}self.pos[1] += {key.len-2}"
            lexerproc.ladd fmt"{indent}self.i += {key.len-2}"
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

    section TEMPLATE:
        tmp.ladd lf
        tmp.secblock "template shift(sh: int) =":
            tmp.ladd "stack.add sh"
            tmp.ladd "retstack.add tk"
            tmp.ladd "break"

        tmp.secblock "template goto(gt: int) =":
            tmp.ladd "stack.add gt"
            tmp.ladd "t = tmpt"

        tmp.secblock "template reduce(rd: seq[bool], nk: untyped) =":
            tmp.ladd fmt"result = Tree(kind: {nodetypename}, nodekind: {nodekindtypename}.nk)"
            tmp.secblock "for e in rd:":
                tmp.secblock "if e:":
                    tmp.ladd "discard stack.pop()"
                    tmp.ladd "result.children.insert retstack.pop.children, 0"
                tmp.secblock "else:":
                    tmp.ladd "discard stack.pop()"
                    tmp.ladd "result.children.insert retstack.pop, 0"
            tmp.ladd "retstack.add result"
            tmp.ladd "tmpt = t"
            tmp.ladd fmt"t = ${nodekindtypename}.nk"
        
        tmp.secblock "template reduce_annon(rd: seq[bool], nk: untyped) =":
            tmp.ladd fmt"result = Tree(kind: {nodetypename})"
            tmp.secblock "for e in rd:":
                tmp.secblock "if e:":
                    tmp.ladd "discard stack.pop()"
                    tmp.ladd "result.children.insert retstack.pop.children, 0"
                tmp.secblock "else:":
                    tmp.ladd "discard stack.pop()"
                    tmp.ladd "result.children.insert retstack.pop, 0"
            tmp.ladd "retstack.add result"
            tmp.ladd "tmpt = t"
            tmp.ladd fmt"t = astToStr(nk)"

    block PARSERPROC:
        defer:
            parserproc.add lf
            ind = 0
        ind = 0
        parserproc.ladd fmt"proc parse*(self: {parsertypename}, src: string): {treetypename} ="
        ind += 1
        # var section
        section varsec:
            parserproc.ladd "var"
            ind += 1
            parserproc.ladd "stack: seq[int] = @[0]"
            parserproc.ladd fmt"retstack: seq[{treetypename}]"

        # make dfa code.
        block makedfa:
            parserproc.ladd "for tk in self.lex(src):"
            ind += 1
            section varsec:
                parserproc.ladd "var"
                ind += 1
                parserproc.ladd "t = $tk.tokenkind"
                parserproc.ladd "tmpt = $tk.tokenkind"

            parserproc.ladd "while true:"
            ind += 1
            parserproc.ladd "case stack[^1]"
            for i, node in dfa.nodes:
                section outerof:
                    parserproc.ladd fmt"of {i}:"
                    ind += 1
                    parserproc.ladd "case t"
                    # shift and goto
                    var
                        expected: seq[string]
                    for edge in filter(dfa.edges, proc(self: Edge): bool = self[0] == i):
                        var
                            key = edge[2]
                            op = key.isUpper(true)
                        if op:
                            section innerof:
                                parserproc.ladd fmt"of ""{key}"":"
                                ind += 1
                                # parserproc.ladd fmt"stack.add {edge[1]}"
                                # parserproc.ladd fmt"retstack.add tk"
                                # parserproc.ladd "break"
                                parserproc.ladd fmt"shift({edge[1]})"

                                # resolve ANNON token
                                if key.startsWith("ANNON"):
                                    var
                                        n = parseInt(key[5..^1])
                                    for ke, val in str_annons:
                                        if val == n:
                                            key = ke.escape()[1..^2]
                                            break
                                    for ke, val in rstr_annons:
                                        if val == n:
                                            key = ke.escape()[1..^2]
                                            break
                                expected.add key
                        else:
                            section innerof:
                                parserproc.ladd fmt"of ""{key}"":"
                                ind += 1
                                # parserproc.ladd fmt"stack.add {edge[1]}"
                                # parserproc.ladd fmt"t = tmpt"
                                parserproc.ladd fmt"goto({edge[1]})"
                    # reduce                   
                    for item in filter(node, proc(self: LRItem): bool = self.rule.right.len == self.index):
                        if item.rule.left == top:
                            section innerof:
                                parserproc.ladd fmt"of ""{eof}"":"
                                ind += 1
                                parserproc.ladd "break"
                            continue
                        var
                            ofs = '"' & join(toSeq(item.la), "\", \"") & '"'
                        for e in item.la:
                            var key = e
                            # resolve ANNON token
                            if key.startsWith("ANNON"):
                                var
                                    n = parseInt(key[5..^1])
                                for ke, val in str_annons:
                                    if val == n:
                                        key = ke.escape()[1..^2]
                                        break
                                for ke, val in rstr_annons:
                                    if val == n:
                                        key = ke.escape()[1..^2]
                                        break
                            expected.add key
                        section innerof:
                            var
                                annsec: seq[bool]
                            for i in countdown(item.rule.right.len-1, 0):
                                var
                                    e = item.rule.right[i]
                                if e.startsWith("annon"):
                                    annsec.add true
                                else:
                                    annsec.add false
                            parserproc.ladd fmt"of {ofs}:"
                            ind += 1
                            if item.rule.left.startsWith("annon"):
                                # parserproc.ladd fmt"result = {treetypename}(kind: {nodetypename})"
                                parserproc.ladd fmt"reduce_annon({annsec}, {item.rule.left})"
                            else:
                                # parserproc.ladd fmt"result = {treetypename}(kind: {nodetypename}, nodekind: {nodekindtypename}.{item.rule.left})"
                                parserproc.ladd fmt"reduce({annsec}, {item.rule.left})"
                            
                            # for i in countdown(item.rule.right.len-1, 0):
                            #     var
                            #         e = item.rule.right[i]
                            #     parserproc.ladd "discard stack.pop()"
                            #     if e.startsWith("annon"):
                            #         parserproc.ladd "result.children.insert retstack.pop.children, 0"
                            #     else:
                            #         parserproc.ladd "result.children.insert retstack.pop, 0"
                            # parserproc.ladd "retstack.add result"
                            # parserproc.ladd "tmpt = t"
                            # parserproc.ladd fmt"t = ""{item.rule.left}"""
                    section elsesec:
                        parserproc.ladd "else:"
                        ind += 1
                        section varsec:
                            var
                                ofs = join(expected, ", ")
                            parserproc.ladd "var"
                            ind += 1
                            parserproc.ladd fmt"msg = ""Expected [{ofs}].\nbut got "" & $tk"
                        parserproc.ladd "raiseSyntaxError(src, tk.pos, msg)"
            section elsesec:
                parserproc.ladd "else:"
                ind += 1
                parserproc.ladd "raiseSyntaxError(src, tk.pos, \"Unreachable. : \" & $tk)"

    block RETADD:
        ret.add lic             # add license
        ret.add input           # add input
        ret.add imprtsec        # add import section
        ret.add typsec          # add type section
        ret.add nimsec          # add nim section
        ret.add resec           # add regex section
        ret.add lexerproc       # add lexer section
        ret.add tmp             # add tmplate section
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

import macros

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

        used_rule: seq[NimNode]
        used_token: seq[NimNode]
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
                error fmt"Allowed directives only are {directives}", directive
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
            of `e`@ident"END":
                if b_nimcode:
                    b_nimcode = false
                else:
                    error "`END` markar must be after NIM block.", e
            of nnkCall(ident"NIM", `statement2`@nnkStmtList):
                parsersec.add statement2
                b_nimcode = true
            of `rule`@nnkIdent:
                var
                    m: RegexMatch
                if not b_nimcode:
                    if rule.strVal.match(re(r"[a-z][a-z_0-9]*"), m):
                        if rule notin used_rule:
                            used_rule.add rule
                    elif rule.strval.match(re(r"[A-Z][A-Z0-9]*"), m):
                        if rule notin used_token:
                            used_token.add rule
            of `annon`@{nnkStrLit, nnkRStrLit}:
                annons.incl annon.strVal
            if b_nimcode:
                error "`END` is needed after NIM block.", ast
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

    # check existance of used rules and tokens
    for e in used_rule:
        if e notin rules:
            error "Undefined rule.", e
    for e in used_token:
        if e notin tokens:
            error "Undefined token.", e
    
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
            newIdentDefs(postfix(ident"val", "*"), bindSym"string"),
            newIdentDefs(postfix(ident"pos", "*"), nnkPar.newTree(bindSym"int", bindSym"int"))
        )
        token_reccase = nnkRecCase.newTree(newIdentDefs(postfix(ident"tokenkind", "*"), ident(tokenname & "Kind")))
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
                        token_inner_rec.add newIdentDefs(postfix(field, "*"), typ)
                    else:
                        error $MatchingError[0], e
                token_of_branch.add token_inner_rec
                token_reccase.add token_of_branch
            else:
                error $TokenMatchingError[0], e
        token_reccase.add nnkElse.newTree(nnkRecList.newTree(newNilLit()))
        token_rec.add token_reccase
    else:
        token_rec.add newIdentDefs(postfix(ident"tokenkind", "*"), ident(tokenname & "Kind"))


    # Node
    var
        node_rec = nnkRecList.newTree(
            newIdentDefs(postfix(ident"children", "*"), nnkBracketExpr.newTree(bindSym"seq", ident(treename)))
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
                        node_inner_rec.add newIdentDefs(postfix(field, "*"), typ)
                    else:
                        error $MatchingError[0], e
                node_of_branch.add node_inner_rec
                node_reccase.add node_of_branch
            else:
                error $NodeMatchingError[0], e
        node_reccase.add nnkElse.newTree(nnkRecList.newTree(newNilLit()))
        node_rec.add node_reccase
    else:
        node_rec.add newIdentDefs(postfix(ident"nodekind", "*"), ident(nodename & "Kind"))

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
                        newIdentDefs(postfix(ident"kind", "*"), ident(treename & "Kind")),
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
    