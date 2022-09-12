Module names are the name of the file, appended with **.bash** if
bash-specific, otherwise **.sh**.  Module names are always all-lowercase
and limited to alphanumerics, starting with an alphabetic character. No
hyphens or underscores.  Core libraries may be shorter than 5 characters
but regular libraries should be 5 or more.  For example, a binary tree
library which is bash-specific might be named **bintree.bash**, but not
**btr.bash** or **BinTree.bash** or **binary_tree.sh**.

Regular variables and functions are named in camelCase, i.e. starting
with a lower-case character and following the constraints of bash
identifiers.  Acronyms and such should be treated the same as words,
only capitalizing the first letter, Java style.  For example, a variable
might be named *myVar* or *indexElement* but not *MyVar* or
*index_element*.

Constants are namespaced with the module name in all-caps limited to 5
characters, followed by underscore, then the all-caps constant name with
underscores, SCREAMING_SNAKE_CASE style.  For example, a constant in
module **mathematics.bash** might be named *MATHE_PI* but not *Math_pi*
or *MTH_PI*.  Although bash typically uses this naming style for
exported variables, constants are not required (nor expected) to be
exported.

Global variables are namespaced with the module name limited to 5
characters (lower-case), appended with the PascalCase variable name
(i.e.  camelCase but first letter capitalized, making the whole thing
camelCase).  For our purposes, a global is any variable which is
referenced by functions without being explicitly passed in.  If such a
variable happens to be declared as a local (for example, in a *main*
function), it should still be named as if it were a true global.

Local variables which are meant to be private use PascalCase and must
consist of more than one letter.  Private variables are typically used
to allow callers to provide a variable reference (name) in which a
return value should be stored.  In order to avoid masking any potential
return variable name, functions which use private locals typically avoid
declaring *any* regular locals.

Regular function names follow the camelCase identifier method.  Private
function names follow the PascalCase identifier method.
