
import core

import re


type
    SyntaxError* = object of Exception

from strutils import `%`
proc `$`*(self: Token): string =
    "[$1: \"$2\"]" % [($self.kind)[2..4], self.value]

proc lbp*(kind: TokenKind): int =
    var lbp = 0
    case kind
    of tkName, tkIntLit, tkEOF:
        lbp = 0
    of tkAdd:
        lbp = 10
    of tkMul:
        lbp = 20
    return lbp

proc newToken*(kind: TokenKind, value: string, pos: (int, int) = (0, 0)): Token =
    Token(kind: kind, value: value, lbp: kind.lbp, pos: pos)

let
    space = re"\s+"
    intLit = re"[1-9][0-9]*"
    op_add = re"\+"
    op_mul = re"\*"
    name = re"[a-zA-Z_][a-zA-Z_0-9]*"
    eof = re"$"

proc newLexer*(program: string): Lexer =
    Lexer(program: program, i: 0)

proc next*(lexer: Lexer): Token =
    if lexer.i >= lexer.program.len:
        return tkEOF.newToken(lexer.program[lexer.i..^1])
    while lexer.program[lexer.i] == ' ':
        lexer.i += 1
    if lexer.program.matchLen(intLit, start=lexer.i) != -1:
        var i = lexer.program.matchLen(intLit, start=lexer.i)
        result = tkINTLIT.newToken(lexer.program[lexer.i..lexer.i+i-1])
        lexer.i += i
    elif lexer.program.matchLen(op_add, start=lexer.i) != -1:
        var i = lexer.program.matchLen(op_add, start=lexer.i)
        result = tkADD.newToken(lexer.program[lexer.i..lexer.i+i-1])
        lexer.i += i
    elif lexer.program.matchLen(op_mul, start=lexer.i) != -1:
        var i = lexer.program.matchLen(op_mul, start=lexer.i)
        result = tkMul.newToken(lexer.program[lexer.i..lexer.i+i-1])
        lexer.i += i
    elif lexer.program.matchLen(name, start=lexer.i) != -1:
        var i = lexer.program.matchLen(name, start=lexer.i)
        result = tkName.newToken(lexer.program[lexer.i..lexer.i+i-1])
        lexer.i += i
    elif lexer.program.matchLen(eof, start=lexer.i) != -1:
        var i = lexer.program.matchLen(eof, start=lexer.i)
        result = tkEOF.newToken(lexer.program[lexer.i..lexer.i+i-1])
        lexer.i += i
    else:
        raise newException(SyntaxError, "unexcepted character.")

iterator lex(self: Lexer): Token =
    self.i = 0
    var ret: Token
    while true:
        ret = self.next()
        yield ret
        if ret.kind == tkEOF:
            break


when isMainModule:
    var
        lexer = newLexer("54+5*3")
    for tk in lexer.lex:
        echo tk

import macros
