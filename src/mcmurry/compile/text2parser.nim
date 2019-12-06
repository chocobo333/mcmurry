
import os

import strutils

import private/parserdef
export parserdef

var parser = Parser()

const license = staticRead("."/".."/".."/".."/"LICENSE")

proc compile_parser*(src: string): string =
    let
        tab = "    "
    var
        node = parser.parse(src).simplify()
    echo src
    echo node
    result = "#[\n"
    result &= license.indent(1, tab)
    result &= "\n"
    result &= "Created by mcmurry; module for generating lexer/parser.".indent(1, tab)
    result &= "\n]#"

template GenerateParser*(body: untyped): untyped =
    echo compile_parser(astToStr(body))
    