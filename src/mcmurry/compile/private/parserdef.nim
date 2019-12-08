
import sequtils
import strutils
import re

import ../../../mcmurry
import ../../private/core

export mcmurry

# Mcmurry(id=Parser, toplevel=module):
#     parser:
#         module:
#             +statement
#         statement:
#             ruledef
#             tokendef
#             magic
#             LF
#         ruledef:
#             RULENAME r":" INDENT ruleright *(LF ruleright) DEDENT
#         ruleright:
#             +expression [r"->" RULENAME] [r"=" NIMCODE ]
#         expression:
#             or_expr
#             r"\[" +expression r"\]"
#         or_expr:
#             repeat_expr *(r"\|" repeat_expr)
#         repeat_expr:
#             atom_expr
#             r"\+" atom_expr
#             r"\*" atom_expr
#         atom_expr:
#             elem
#             r"\(" +expression r"\)"
#         elem:
#             name
#             pattern
#         tokendef:
#             pattern r"=" TOKENNAME
#             pattern r"=" NIMCODE LF
#         name:
#             RULENAME
#             TOKENNAME
#         pattern:
#             STR
#             RSTR
#         magic:
#             r"%" directive r"=" name *(r"/" name)
#             r"%" directive r"=" NIMCODE
#         directive:
#             r"filename"
#             r"toplevel"
#             r"nodename
#             r"tokenname"
#             r"treename
#             r"token"
#             r"node"
#             r"tree"
#             r"ignore"
#             r"nim"
#     lexer:
#         var
#             nIndent: seq[int] = @[0]

#         r"NIM:\n.*?END": NIMCODE
#         r"("")[^""\\]*(\\.[^""\\]*)*("")": STR
#         r"r("")[^\""]*(("")""[^\""]*)*("")": RSTR
#         r"[a-z][a-z_0-9]*": RULENAME
#         r"[A-Z][A-Z0-9]*":
#             block:
#                 var ret = TOKENNAME
#                 if str.startsWith("ANNON"):
#                     raise newException(SyntaxError, "Token's name must not start from `ANNON`.")
#                 ret
#         r"\n[ ]*":
#             block:
#                 if len-1 > nIndent[^1]:
#                     nIndent.add len-1
#                     INDENT
#                 elif len-1 < nIndent[^1]:
#                     while len-1 != nIndent[^1]:
#                         discard nIndent.pop()
#                         kind_stack.add DEDENT
#                         if nIndent.len == 0:
#                             raise newException(SyntaxError, "Invalid indent.")
#                     discard kind_stack.pop()
#                     DEDENT
#                 else:
#                     LF
#         r"\s+": SPACE
#         %ignore:
#             SPACE


type
    ParserTokenKind* {.pure.} = enum
        SPACE, LF, DEDENT, INDENT, TOKENNAME, RULENAME, RSTR, STR, NIMCODE, EOF, ANNON0,
        ANNON1, ANNON2, ANNON3, ANNON4, ANNON5, ANNON6, ANNON7, ANNON8, ANNON9, ANNON10,
        ANNON11, ANNON12, ANNON13, ANNON14, ANNON15, ANNON16, ANNON17
    ParserToken* = TokenBase[ParserTokenKind]
    ParserNodeKind* {.pure.} = enum
        directive, name, magic, pattern, tokendef, elem, expression, atom_expr, repeat_expr,
        or_expr, ruleright, ruledef, statement, module
    ParserNode* = NodeBase[ParserNodeKind, ParserToken]
    Parser* = ref object
        program: string
        i: int
        pos: (int, int)

template Node*(typ: typedesc[Parser]): untyped =
    ParserNode

template NodeKind*(typ: typedesc[Parser]): untyped =
    ParserNodeKind

template Token*(typ: typedesc[Parser]): untyped =
    ParserToken

template TokenKind*(typ: typedesc[Parser]): untyped =
    ParserTokenKind

var nIndent: seq[int] = @[0]
let
    reParser0 = re(r"NIM:\n.*?END", {reStudy, reDotAll})
    reParser1 = re(r"("")[^""\\]*(\\.[^""\\]*)*("")", {reStudy, reDotAll})
    reParser2 = re(r"r("")[^\""]*(("")""[^\""]*)*("")", {reStudy, reDotAll})
    reParser3 = re(r"[a-z][a-z_0-9]*", {reStudy, reDotAll})
    reParser4 = re(r"[A-Z][A-Z0-9]*", {reStudy, reDotAll})
    # reParser3 = re(r"[a-z0-9]*", {reStudy, reDotAll})
    # reParser4 = re(r"[A-Z0-9]*", {reStudy, reDotAll})
    reParser5 = re(r"\n[ ]*", {reStudy, reDotAll})
    reParser6 = re(r"\s+", {reStudy, reDotAll})
    reParserannon0 = re(r"nim", {reStudy, reDotAll})
    reParserannon1 = re(r"ignore", {reStudy, reDotAll})
    reParserannon2 = re(r"node", {reStudy, reDotAll})
    reParserannon3 = re(r"token", {reStudy, reDotAll})
    reParserannon4 = re(r"toplevel", {reStudy, reDotAll})
    reParserannon5 = re(r"filename", {reStudy, reDotAll})
    reParserannon6 = re(r"=", {reStudy, reDotAll})
    reParserannon7 = re(r"%", {reStudy, reDotAll})
    reParserannon8 = re(r"/", {reStudy, reDotAll})
    reParserannon9 = re(r"\)", {reStudy, reDotAll})
    reParserannon10 = re(r"\(", {reStudy, reDotAll})
    reParserannon11 = re(r"\*", {reStudy, reDotAll})
    reParserannon12 = re(r"\+", {reStudy, reDotAll})
    reParserannon13 = re(r"\|", {reStudy, reDotAll})
    reParserannon14 = re(r"\]", {reStudy, reDotAll})
    reParserannon15 = re(r"\[", {reStudy, reDotAll})
    reParserannon16 = re(r"->", {reStudy, reDotAll})
    reParserannon17 = re(r":", {reStudy, reDotAll})
var kind_stack: seq[ParserTokenKind] = @[]
proc program*(self: Parser): string =
    self.program

proc `program=`*(self: Parser; val: string) =
    self.program = val
    self.i = 0
    self.pos = (1, 1)
    nIndent = @[0]

proc next*(self: Parser): ParserToken =
    if kind_stack.len != 0:
        return ParserToken(kind: kind_stack.pop(), pos: self.pos)
    if self.i >=
        self.program.len:
        return ParserToken(kind: ParserTokenKind.EOF, val: "$",
                          pos: self.pos)
    elif matchLen(self.program, reParserannon0,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon0,
                          start = self.i)
            kind = ANNON0
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon1,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon1,
                          start = self.i)
            kind = ANNON1
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon2,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon2,
                          start = self.i)
            kind = ANNON2
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon3,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon3,
                          start = self.i)
            kind = ANNON3
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon4,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon4,
                          start = self.i)
            kind = ANNON4
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon5,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon5,
                          start = self.i)
            kind = ANNON5
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon6,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon6,
                          start = self.i)
            kind = ANNON6
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon7,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon7,
                          start = self.i)
            kind = ANNON7
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon8,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon8,
                          start = self.i)
            kind = ANNON8
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon9,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon9,
                          start = self.i)
            kind = ANNON9
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon10,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon10,
                          start = self.i)
            kind = ANNON10
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon11,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon11,
                          start = self.i)
            kind = ANNON11
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon12,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon12,
                          start = self.i)
            kind = ANNON12
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon13,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon13,
                          start = self.i)
            kind = ANNON13
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon14,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon14,
                          start = self.i)
            kind = ANNON14
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon15,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon15,
                          start = self.i)
            kind = ANNON15
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon16,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon16,
                          start = self.i)
            kind = ANNON16
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParserannon17,
                  start = self.i) != -1:
        var
            len = matchLen(self.program, reParserannon17,
                          start = self.i)
            kind = ANNON17
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParser0, start = self.i) !=
        -1:
        var
            len = matchLen(self.program, reParser0,
                          start = self.i)
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
            kind = NIMCODE
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParser1, start = self.i) !=
        -1:
        var
            len = matchLen(self.program, reParser1,
                          start = self.i)
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
            kind = STR
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParser2, start = self.i) !=
        -1:
        var
            len = matchLen(self.program, reParser2,
                          start = self.i)
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
            kind = RSTR
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParser3, start = self.i) !=
        -1:
        var
            len = matchLen(self.program, reParser3,
                          start = self.i)
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
            kind = RULENAME
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParser4, start = self.i) !=
        -1:
        var
            len = matchLen(self.program, reParser4,
                          start = self.i)
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
            kind = block:
                var ret = TOKENNAME
                if str.startsWith("ANNON"):
                    raise newException(SyntaxError,
                                    "Token\'s name must not start from `ANNON`.")
                ret
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParser5, start = self.i) !=
        -1:
        var
            len = matchLen(self.program, reParser5,
                          start = self.i)
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
            kind = block:
                if len - 1 > nIndent[^1]:
                    nIndent.add len - 1
                    INDENT
                elif len - 1 < nIndent[^1]:
                    while len - 1 != nIndent[^1]:
                        discard nIndent.pop()
                        kind_stack.add DEDENT
                        if nIndent.len == 0:
                            raise newException(SyntaxError, "Invalid indent.")
                    discard kind_stack.pop()
                    DEDENT
                else:
                    LF
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    elif matchLen(self.program, reParser6, start = self.i) !=
        -1:
        var
            len = matchLen(self.program, reParser6,
                          start = self.i)
            str = self.program[self.i ..
                self.i + (len - 1)]
            lines = splitLines(str)
            kind = SPACE
        result = ParserToken(kind: kind, val: str, pos: self.pos)
        self.i += len
        self.pos[0] +=
            lines.len - 1
        if lines.len == 1:
            self.pos[1] += len
        else:
            self.pos[1] = 1 +
                lines[^1].len
    else:
        raise newException(TokenError, "Unexpected characters." &
            self.program[self.i])
    if result.kind ==
        ParserTokenKind.SPACE:
        return self.next()

iterator lex*(self: Parser; program: string): ParserToken =
    `program=`(self, program)
    var ret: ParserToken
    while true:
        ret = self.next()
        yield ret
        if ret.kind ==
            ParserTokenKind.EOF:
            break

proc parse*(self: Parser; src: string): ParserNode =
    var
        stack: seq[int] = @[0]
        token_stack: type(result.tokens)
        ret_stack: type(result.children)
    for tk in self.lex(src):
        var
            t = $tk.kind
            tmpt = $tk.kind
        while true:
            case stack[^1]
            of 0:
                case t
                of "STR":
                    stack.add(1)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(2)
                    token_stack.add(tk)
                    break
                of "tokendef":
                    stack.add(3)
                    t = tmpt
                of "magic":
                    stack.add(4)
                    t = tmpt
                of "RSTR":
                    stack.add(5)
                    token_stack.add(tk)
                    break
                of "module":
                    stack.add(6)
                    t = tmpt
                of "annon0":
                    stack.add(7)
                    t = tmpt
                of "LF":
                    stack.add(8)
                    token_stack.add(tk)
                    break
                of "statement":
                    stack.add(9)
                    t = tmpt
                of "ANNON7":
                    stack.add(10)
                    token_stack.add(tk)
                    break
                of "pattern":
                    stack.add(11)
                    t = tmpt
                of "ruledef":
                    stack.add(12)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 1:
                case t
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 2:
                case t
                of "ANNON17":
                    stack.add(13)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 3:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 4:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 5:
                case t
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 6:
                case t
                of "EOF":
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 7:
                case t
                of "STR":
                    stack.add(1)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(2)
                    token_stack.add(tk)
                    break
                of "tokendef":
                    stack.add(3)
                    t = tmpt
                of "magic":
                    stack.add(4)
                    t = tmpt
                of "RSTR":
                    stack.add(5)
                    token_stack.add(tk)
                    break
                of "LF":
                    stack.add(8)
                    token_stack.add(tk)
                    break
                of "statement":
                    stack.add(14)
                    t = tmpt
                of "ANNON7":
                    stack.add(10)
                    token_stack.add(tk)
                    break
                of "pattern":
                    stack.add(11)
                    t = tmpt
                of "ruledef":
                    stack.add(12)
                    t = tmpt
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = module
                    ret_stack.add(result)
                    tmpt = t
                    t = "module"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 8:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 9:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 10:
                case t
                of "ANNON1":
                    stack.add(15)
                    token_stack.add(tk)
                    break
                of "directive":
                    stack.add(16)
                    t = tmpt
                of "ANNON5":
                    stack.add(17)
                    token_stack.add(tk)
                    break
                of "ANNON3":
                    stack.add(18)
                    token_stack.add(tk)
                    break
                of "ANNON0":
                    stack.add(19)
                    token_stack.add(tk)
                    break
                of "ANNON2":
                    stack.add(20)
                    token_stack.add(tk)
                    break
                of "ANNON4":
                    stack.add(21)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 11:
                case t
                of "ANNON6":
                    stack.add(22)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 12:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = statement
                    ret_stack.add(result)
                    tmpt = t
                    t = "statement"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 13:
                case t
                of "INDENT":
                    stack.add(23)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 14:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon0"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 15:
                case t
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = directive
                    ret_stack.add(result)
                    tmpt = t
                    t = "directive"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 16:
                case t
                of "ANNON6":
                    stack.add(24)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 17:
                case t
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = directive
                    ret_stack.add(result)
                    tmpt = t
                    t = "directive"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 18:
                case t
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = directive
                    ret_stack.add(result)
                    tmpt = t
                    t = "directive"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 19:
                case t
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = directive
                    ret_stack.add(result)
                    tmpt = t
                    t = "directive"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 20:
                case t
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = directive
                    ret_stack.add(result)
                    tmpt = t
                    t = "directive"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 21:
                case t
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = directive
                    ret_stack.add(result)
                    tmpt = t
                    t = "directive"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 22:
                case t
                of "TOKENNAME":
                    stack.add(25)
                    token_stack.add(tk)
                    break
                of "NIMCODE":
                    stack.add(26)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 23:
                case t
                of "TOKENNAME":
                    stack.add(27)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(28)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(29)
                    token_stack.add(tk)
                    break
                of "ruleright":
                    stack.add(30)
                    t = tmpt
                of "expression":
                    stack.add(31)
                    t = tmpt
                of "RULENAME":
                    stack.add(32)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(33)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(34)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(35)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(36)
                    t = tmpt
                of "name":
                    stack.add(37)
                    t = tmpt
                of "annon2":
                    stack.add(38)
                    t = tmpt
                of "pattern":
                    stack.add(39)
                    t = tmpt
                of "atom_expr":
                    stack.add(40)
                    t = tmpt
                of "ANNON11":
                    stack.add(41)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(42)
                    t = tmpt
                of "repeat_expr":
                    stack.add(43)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 24:
                case t
                of "TOKENNAME":
                    stack.add(44)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(45)
                    token_stack.add(tk)
                    break
                of "name":
                    stack.add(46)
                    t = tmpt
                of "NIMCODE":
                    stack.add(47)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 25:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 26:
                case t
                of "LF":
                    stack.add(48)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 27:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 28:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 29:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(52)
                    t = tmpt
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(55)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(56)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "annon2":
                    stack.add(59)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(61)
                    t = tmpt
                of "ANNON11":
                    stack.add(62)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(63)
                    t = tmpt
                of "repeat_expr":
                    stack.add(64)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 30:
                case t
                of "DEDENT":
                    stack.add(65)
                    token_stack.add(tk)
                    break
                of "annon1":
                    stack.add(66)
                    t = tmpt
                of "LF":
                    stack.add(67)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 31:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 32:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 33:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 34:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(71)
                    t = tmpt
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(74)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(75)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "annon2":
                    stack.add(78)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(80)
                    t = tmpt
                of "ANNON11":
                    stack.add(81)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(82)
                    t = tmpt
                of "repeat_expr":
                    stack.add(83)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 35:
                case t
                of "TOKENNAME":
                    stack.add(27)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(28)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(29)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(32)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(33)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(36)
                    t = tmpt
                of "name":
                    stack.add(37)
                    t = tmpt
                of "pattern":
                    stack.add(39)
                    t = tmpt
                of "atom_expr":
                    stack.add(84)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 36:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 37:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 38:
                case t
                of "TOKENNAME":
                    stack.add(27)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(28)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(29)
                    token_stack.add(tk)
                    break
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = ruleright
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruleright"
                of "expression":
                    stack.add(85)
                    t = tmpt
                of "ANNON6":
                    stack.add(86)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(32)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(33)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(34)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(35)
                    token_stack.add(tk)
                    break
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = ruleright
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruleright"
                of "ANNON16":
                    stack.add(87)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(36)
                    t = tmpt
                of "name":
                    stack.add(37)
                    t = tmpt
                of "pattern":
                    stack.add(39)
                    t = tmpt
                of "atom_expr":
                    stack.add(40)
                    t = tmpt
                of "ANNON11":
                    stack.add(41)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(42)
                    t = tmpt
                of "repeat_expr":
                    stack.add(43)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 39:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 40:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 41:
                case t
                of "TOKENNAME":
                    stack.add(27)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(28)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(29)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(32)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(33)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(36)
                    t = tmpt
                of "name":
                    stack.add(37)
                    t = tmpt
                of "pattern":
                    stack.add(39)
                    t = tmpt
                of "atom_expr":
                    stack.add(88)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 42:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 43:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON13":
                    stack.add(89)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "annon4":
                    stack.add(90)
                    t = tmpt
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 44:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON8":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 45:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON8":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 46:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "annon6":
                    stack.add(91)
                    t = tmpt
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "ANNON8":
                    stack.add(92)
                    token_stack.add(tk)
                    break
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 47:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 48:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = tokendef
                    ret_stack.add(result)
                    tmpt = t
                    t = "tokendef"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 49:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 50:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 51:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(52)
                    t = tmpt
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(55)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(56)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "annon2":
                    stack.add(93)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(61)
                    t = tmpt
                of "ANNON11":
                    stack.add(62)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(63)
                    t = tmpt
                of "repeat_expr":
                    stack.add(64)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 52:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 53:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 54:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 55:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(71)
                    t = tmpt
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(74)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(75)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "annon2":
                    stack.add(94)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(80)
                    t = tmpt
                of "ANNON11":
                    stack.add(81)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(82)
                    t = tmpt
                of "repeat_expr":
                    stack.add(83)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 56:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(95)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 57:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 58:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 59:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(96)
                    t = tmpt
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(55)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(56)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(61)
                    t = tmpt
                of "ANNON9":
                    stack.add(97)
                    token_stack.add(tk)
                    break
                of "ANNON11":
                    stack.add(62)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(63)
                    t = tmpt
                of "repeat_expr":
                    stack.add(64)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 60:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 61:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 62:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(98)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 63:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 64:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON13":
                    stack.add(99)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "annon4":
                    stack.add(100)
                    t = tmpt
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 65:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 66:
                case t
                of "DEDENT":
                    stack.add(101)
                    token_stack.add(tk)
                    break
                of "LF":
                    stack.add(102)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 67:
                case t
                of "TOKENNAME":
                    stack.add(27)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(28)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(29)
                    token_stack.add(tk)
                    break
                of "ruleright":
                    stack.add(103)
                    t = tmpt
                of "expression":
                    stack.add(31)
                    t = tmpt
                of "RULENAME":
                    stack.add(32)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(33)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(34)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(35)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(36)
                    t = tmpt
                of "name":
                    stack.add(37)
                    t = tmpt
                of "annon2":
                    stack.add(38)
                    t = tmpt
                of "pattern":
                    stack.add(39)
                    t = tmpt
                of "atom_expr":
                    stack.add(40)
                    t = tmpt
                of "ANNON11":
                    stack.add(41)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(42)
                    t = tmpt
                of "repeat_expr":
                    stack.add(43)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 68:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 69:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 70:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(52)
                    t = tmpt
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(55)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(56)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "annon2":
                    stack.add(104)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(61)
                    t = tmpt
                of "ANNON11":
                    stack.add(62)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(63)
                    t = tmpt
                of "repeat_expr":
                    stack.add(64)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 71:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 72:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = name
                    ret_stack.add(result)
                    tmpt = t
                    t = "name"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 73:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = pattern
                    ret_stack.add(result)
                    tmpt = t
                    t = "pattern"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 74:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(71)
                    t = tmpt
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(74)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(75)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "annon2":
                    stack.add(105)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(80)
                    t = tmpt
                of "ANNON11":
                    stack.add(81)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(82)
                    t = tmpt
                of "repeat_expr":
                    stack.add(83)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 75:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(106)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 76:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 77:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 78:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(107)
                    t = tmpt
                of "ANNON14":
                    stack.add(108)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(74)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(75)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(80)
                    t = tmpt
                of "ANNON11":
                    stack.add(81)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(82)
                    t = tmpt
                of "repeat_expr":
                    stack.add(83)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 79:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = elem
                    ret_stack.add(result)
                    tmpt = t
                    t = "elem"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 80:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 81:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(109)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 82:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 83:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON13":
                    stack.add(110)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "annon4":
                    stack.add(111)
                    t = tmpt
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 84:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 85:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 86:
                case t
                of "NIMCODE":
                    stack.add(112)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 87:
                case t
                of "RULENAME":
                    stack.add(113)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 88:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 89:
                case t
                of "TOKENNAME":
                    stack.add(27)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(28)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(29)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(32)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(33)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(35)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(36)
                    t = tmpt
                of "name":
                    stack.add(37)
                    t = tmpt
                of "pattern":
                    stack.add(39)
                    t = tmpt
                of "atom_expr":
                    stack.add(40)
                    t = tmpt
                of "ANNON11":
                    stack.add(41)
                    token_stack.add(tk)
                    break
                of "repeat_expr":
                    stack.add(114)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 90:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON13":
                    stack.add(115)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 91:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                of "ANNON8":
                    stack.add(116)
                    token_stack.add(tk)
                    break
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = magic
                    ret_stack.add(result)
                    tmpt = t
                    t = "magic"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 92:
                case t
                of "TOKENNAME":
                    stack.add(44)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(45)
                    token_stack.add(tk)
                    break
                of "name":
                    stack.add(117)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 93:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(96)
                    t = tmpt
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(55)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(56)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(61)
                    t = tmpt
                of "ANNON9":
                    stack.add(118)
                    token_stack.add(tk)
                    break
                of "ANNON11":
                    stack.add(62)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(63)
                    t = tmpt
                of "repeat_expr":
                    stack.add(64)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 94:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(107)
                    t = tmpt
                of "ANNON14":
                    stack.add(119)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(74)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(75)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(80)
                    t = tmpt
                of "ANNON11":
                    stack.add(81)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(82)
                    t = tmpt
                of "repeat_expr":
                    stack.add(83)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 95:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 96:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 97:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 98:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 99:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(56)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(61)
                    t = tmpt
                of "ANNON11":
                    stack.add(62)
                    token_stack.add(tk)
                    break
                of "repeat_expr":
                    stack.add(120)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 100:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON13":
                    stack.add(121)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 101:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = ruledef
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruledef"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 102:
                case t
                of "TOKENNAME":
                    stack.add(27)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(28)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(29)
                    token_stack.add(tk)
                    break
                of "ruleright":
                    stack.add(122)
                    t = tmpt
                of "expression":
                    stack.add(31)
                    t = tmpt
                of "RULENAME":
                    stack.add(32)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(33)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(34)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(35)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(36)
                    t = tmpt
                of "name":
                    stack.add(37)
                    t = tmpt
                of "annon2":
                    stack.add(38)
                    t = tmpt
                of "pattern":
                    stack.add(39)
                    t = tmpt
                of "atom_expr":
                    stack.add(40)
                    t = tmpt
                of "ANNON11":
                    stack.add(41)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(42)
                    t = tmpt
                of "repeat_expr":
                    stack.add(43)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 103:
                case t
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon1"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon1"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 104:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(96)
                    t = tmpt
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(55)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(56)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(61)
                    t = tmpt
                of "ANNON9":
                    stack.add(123)
                    token_stack.add(tk)
                    break
                of "ANNON11":
                    stack.add(62)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(63)
                    t = tmpt
                of "repeat_expr":
                    stack.add(64)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 105:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "expression":
                    stack.add(107)
                    t = tmpt
                of "ANNON14":
                    stack.add(124)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    stack.add(74)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(75)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(80)
                    t = tmpt
                of "ANNON11":
                    stack.add(81)
                    token_stack.add(tk)
                    break
                of "or_expr":
                    stack.add(82)
                    t = tmpt
                of "repeat_expr":
                    stack.add(83)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 106:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 107:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon2"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 108:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 109:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = repeat_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "repeat_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 110:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(75)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(80)
                    t = tmpt
                of "ANNON11":
                    stack.add(81)
                    token_stack.add(tk)
                    break
                of "repeat_expr":
                    stack.add(125)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 111:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON13":
                    stack.add(126)
                    token_stack.add(tk)
                    break
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    result.kind = or_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "or_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 112:
                case t
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = ruleright
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruleright"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = ruleright
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruleright"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 113:
                case t
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = ruleright
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruleright"
                of "ANNON6":
                    stack.add(127)
                    token_stack.add(tk)
                    break
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = ruleright
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruleright"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 114:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 115:
                case t
                of "TOKENNAME":
                    stack.add(27)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(28)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(29)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(32)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(33)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(35)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(36)
                    t = tmpt
                of "name":
                    stack.add(37)
                    t = tmpt
                of "pattern":
                    stack.add(39)
                    t = tmpt
                of "atom_expr":
                    stack.add(40)
                    t = tmpt
                of "ANNON11":
                    stack.add(41)
                    token_stack.add(tk)
                    break
                of "repeat_expr":
                    stack.add(128)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 116:
                case t
                of "TOKENNAME":
                    stack.add(44)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(45)
                    token_stack.add(tk)
                    break
                of "name":
                    stack.add(129)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 117:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "ANNON8":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 118:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 119:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 120:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 121:
                case t
                of "TOKENNAME":
                    stack.add(49)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(50)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(51)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(53)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(54)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(56)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(57)
                    t = tmpt
                of "name":
                    stack.add(58)
                    t = tmpt
                of "pattern":
                    stack.add(60)
                    t = tmpt
                of "atom_expr":
                    stack.add(61)
                    t = tmpt
                of "ANNON11":
                    stack.add(62)
                    token_stack.add(tk)
                    break
                of "repeat_expr":
                    stack.add(130)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 122:
                case t
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon1"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon1"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 123:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = atom_expr
                    ret_stack.add(result)
                    tmpt = t
                    t = "atom_expr"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 124:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    result.kind = expression
                    ret_stack.add(result)
                    tmpt = t
                    t = "expression"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 125:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 126:
                case t
                of "TOKENNAME":
                    stack.add(68)
                    token_stack.add(tk)
                    break
                of "STR":
                    stack.add(69)
                    token_stack.add(tk)
                    break
                of "ANNON10":
                    stack.add(70)
                    token_stack.add(tk)
                    break
                of "RULENAME":
                    stack.add(72)
                    token_stack.add(tk)
                    break
                of "RSTR":
                    stack.add(73)
                    token_stack.add(tk)
                    break
                of "ANNON12":
                    stack.add(75)
                    token_stack.add(tk)
                    break
                of "elem":
                    stack.add(76)
                    t = tmpt
                of "name":
                    stack.add(77)
                    t = tmpt
                of "pattern":
                    stack.add(79)
                    t = tmpt
                of "atom_expr":
                    stack.add(80)
                    t = tmpt
                of "ANNON11":
                    stack.add(81)
                    token_stack.add(tk)
                    break
                of "repeat_expr":
                    stack.add(131)
                    t = tmpt
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 127:
                case t
                of "NIMCODE":
                    stack.add(132)
                    token_stack.add(tk)
                    break
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 128:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON6":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON16":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 129:
                case t
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "ANNON7":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "ANNON8":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                of "EOF":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon6"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 130:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON9":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 131:
                case t
                of "TOKENNAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "STR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON10":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON14":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RULENAME":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "RSTR":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON13":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON15":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON12":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                of "ANNON11":
                    result = ParserNode()
                    discard stack.pop()
                    result.children.insert(ret_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    ret_stack.add(result)
                    tmpt = t
                    t = "annon4"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            of 132:
                case t
                of "DEDENT":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = ruleright
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruleright"
                of "LF":
                    result = ParserNode()
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    result.tokens.insert(token_stack.pop, 0)
                    discard stack.pop()
                    var tmpannon = ret_stack.pop
                    result.children.insert(tmpannon.children, 0)
                    result.tokens.insert(tmpannon.tokens, 0)
                    result.kind = ruleright
                    ret_stack.add(result)
                    tmpt = t
                    t = "ruleright"
                else:
                    raise newException(SyntaxError, "Unexpected Token." & t & tk.val)
            else:
                raise newException(SyntaxError, "Error that is impossible to be occured.")

