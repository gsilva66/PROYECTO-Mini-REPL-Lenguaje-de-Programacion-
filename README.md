=== Mini-REPL RPN en Nim (CAO604) ===
Escribe 'help' para ver los comandos o 'exit' para salir.
rpn> x 10 =
x = 10
rpn> x 5 + 2 *
=> 30
rpn> 5 true +
[Error] Operación aritmética '+' inválida entre vkInt y vkBool
rpn> 10 0 /
[Error] División por cero.
rpn> 10 5 >
=> true
rpn> begin
-> Nuevo ámbito local abierto (nivel 1)
rpn[local#1]> x 99 =
x = 99
rpn[local#1]> y 20 =
y = 20
rpn[local#1]> vars
Variables activas (nivel de ámbito actual: 1):
  x = 99  [local#1]
  y = 20  [local#1]
rpn[local#1]> end
<- Ámbito local cerrado (nivel 0)
rpn> x
=> 10
rpn> y
[Error] Variable no definida: 'y'
rpn> exit
