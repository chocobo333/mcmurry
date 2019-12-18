
import asciitype
export asciitype

# import hashes

# proc hash*[A](x: seq[A]): Hash =
#     ## efficient hashing of arrays and sequences.
#     for it in items(x): result = result !& hash(it)
#     result = !$result