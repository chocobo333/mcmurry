# Package

version       = "0.1.1"
author        = "chocobo333"
description   = "A module for generating lexer/parser."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tmp"]
installExt    = @["nim"]
bin           = @["mcmurry"]



# Dependencies

requires "nim >= 1.0.4"
requires "asciitype"
