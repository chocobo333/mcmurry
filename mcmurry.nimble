# Package

version       = "0.3.5"
author        = "chocobo333"
description   = "A module for generating lexer/parser."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tmp"]
# installExt    = @["nim"]
# bin           = @["mcmurry"]



# Dependencies

requires "nim >= 1.0.4"
requires "asciitype"

# For compiling
requires "ast_pattern_matching"
requires "regex"
# requires "timeit"
