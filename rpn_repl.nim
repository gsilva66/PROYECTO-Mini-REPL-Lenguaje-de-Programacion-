## ============================================================================
## Mini-REPL Evaluador Postfijo (RPN) en Nim
## Materia: CAO604 - Lenguajes de Programación (FACYT - UC)
## ============================================================================

import std/[strutils, tables, sets]

# ----------------------------------------------------------------------------
# 1. MANEJO DE ERRORES (Excepciones idiomáticas en Nim)
# En Nim, los errores recuperables heredan de CatchableError. Esto permite
# capturar fallos en tiempo de ejecución sin que el REPL aborte abruptamente.
# ----------------------------------------------------------------------------
type
  RpnError* = object of CatchableError
  RpnTypeError* = object of RpnError
  RpnRuntimeError* = object of RpnError
  RpnSyntaxError* = object of RpnError

# ----------------------------------------------------------------------------
# 2. SISTEMA DE TIPOS DEL EVALUADOR (Object Variants / Uniones Etiquetadas)
# Nim implementa tipos algebraicos (sum types) mediante "object variants".
# El compilador realiza chequeo estático y garantiza en tiempo de ejecución
# que solo se acceda al campo correspondiente al discriminador `kind`.
# ----------------------------------------------------------------------------
type
  ValueKind* = enum
    vkInt, vkFloat, vkBool, vkIdent

  Value* = object
    case kind*: ValueKind
    of vkInt:
      intVal*: int
    of vkFloat:
      floatVal*: float
    of vkBool:
      boolVal*: bool
    of vkIdent:
      # Permite apilar nombres de variables para asignar (ej: x 10 =)
      # o resolverlos perezosamente al ser consumidos por un operador.
      identName*: string

  TokenKind* = enum
    tkValue, tkOperator, tkCommand

  Token* = object
    case kind*: TokenKind
    of tkValue:
      val*: Value
    of tkOperator:
      op*: string
    of tkCommand:
      cmd*: string

  # --------------------------------------------------------------------------
  # 3. ABSTRACCIÓN DE DATOS Y ALCANCE (Scoping / Shadowing)
  # El entorno se modela como una pila de tablas de símbolos (seq de Table).
  # - Índice 0: Entorno global.
  # - `begin`: Apila una nueva tabla vacía (nuevo ámbito local).
  # - `end`: Desapila y libera la tabla superior (destruye variables locales).
  # --------------------------------------------------------------------------
  Environment* = object
    scopes*: seq[Table[string, Value]]

  EvalStack* = seq[Value]

# ----------------------------------------------------------------------------
# UTILIDADES DE REPRESENTACIÓN (Polimorfismo ad-hoc mediante sobrecarga de `$`)
# ----------------------------------------------------------------------------
proc `$`*(v: Value): string =
  case v.kind
  of vkInt: $v.intVal
  of vkFloat: formatFloat(v.floatVal, ffDefault, precision = 6)
  of vkBool: $v.boolVal
  of vkIdent: v.identName

proc isNumeric(v: Value): bool =
  v.kind in {vkInt, vkFloat}

proc toFloat(v: Value): float =
  case v.kind
  of vkInt: float(v.intVal)
  of vkFloat: v.floatVal
  else: raise newException(RpnTypeError, "Se esperaba un valor numérico, se recibió: " & $v.kind)

# ----------------------------------------------------------------------------
# GESTIÓN DEL ENTORNO Y ALCANCE (Paso por valor vs. Paso por referencia `var`)
# En Nim:
# - Parámetros sin `var` son inmutables (el compilador elige pasar por valor
#   o referencia constante de forma transparente).
# - Parámetros con `var` se pasan explícitamente por referencia mutable.
# ----------------------------------------------------------------------------
proc initEnvironment*(): Environment =
  # Inicia con un único ámbito: el global.
  result.scopes = @[initTable[string, Value]()]

proc enterScope*(env: var Environment) =
  env.scopes.add(initTable[string, Value]())

proc exitScope*(env: var Environment) =
  if env.scopes.len <= 1:
    raise newException(RpnRuntimeError, "No hay ningún bloque local abierto para cerrar ('end' inválido).")
  discard env.scopes.pop()

proc defineVar*(env: var Environment, name: string, val: Value) =
  # Siempre escribe en el ámbito más interno (tope de la pila de scopes).
  # Si existe una variable homónima en un ámbito externo, ocurre shadowing.
  env.scopes[^1][name] = val

proc lookupVar*(env: Environment, name: string): Value =
  # Recorre desde el ámbito más interno hacia el global (regla de alcance léxico/dinámico).
  for i in countdown(env.scopes.high, 0):
    if env.scopes[i].hasKey(name):
      return env.scopes[i][name]
  raise newException(RpnRuntimeError, "Variable no definida: '" & name & "'")

proc printVars*(env: Environment) =
  ## Muestra las variables activas respetando el shadowing (oculta las sombreadas).
  var seen = initHashSet[string]()
  echo "Variables activas (nivel de ámbito actual: ", env.scopes.len - 1, "):"
  var count = 0
  for i in countdown(env.scopes.high, 0):
    let scopeLabel = if i == 0: "global" else: "local#" & $i
    for k, v in env.scopes[i].pairs:
      if k notin seen:
        echo "  ", k, " = ", v, "  [", scopeLabel, "]"
        seen.incl(k)
        inc count
  if count == 0:
    echo "  (ninguna)"

# ----------------------------------------------------------------------------
# TOKENIZADOR (Análisis Léxico simple separado por espacios)
# ----------------------------------------------------------------------------
proc isValidIdentifier(s: string): bool =
  if s.len == 0: return false
  if not (s[0].isAlphaAscii() or s[0] == '_'): return false
  for c in s:
    if not (c.isAlphaNumeric() or c == '_'):
      return false
  return true

proc tokenize*(line: string): seq[Token] =
  const operators = ["+", "-", "*", "/", "==", "!=", "<", ">", "="]
  const commands = ["begin", "end", "vars", "stack", "clear", "help", "exit", "quit"]

  for raw in line.splitWhitespace():
    if raw in operators:
      result.add(Token(kind: tkOperator, op: raw))
    elif raw in commands:
      result.add(Token(kind: tkCommand, cmd: raw))
    elif raw == "true":
      result.add(Token(kind: tkValue, val: Value(kind: vkBool, boolVal: true)))
    elif raw == "false":
      result.add(Token(kind: tkValue, val: Value(kind: vkBool, boolVal: false)))
    else:
      # Intentar parsear como entero, luego flotante, luego identificador
      try:
        let i = parseInt(raw)
        result.add(Token(kind: tkValue, val: Value(kind: vkInt, intVal: i)))
        continue
      except ValueError:
        discard

      try:
        let f = parseFloat(raw)
        result.add(Token(kind: tkValue, val: Value(kind: vkFloat, floatVal: f)))
        continue
      except ValueError:
        discard

      if isValidIdentifier(raw):
        result.add(Token(kind: tkValue, val: Value(kind: vkIdent, identName: raw)))
      else:
        raise newException(RpnSyntaxError, "Token inválido: '" & raw & "'")

# ----------------------------------------------------------------------------
# EVALUADOR DE PILA (Subrutinas con paso explícito de pila y entorno)
# ----------------------------------------------------------------------------
proc popValue(stack: var EvalStack): Value =
  if stack.len == 0:
    raise newException(RpnRuntimeError, "Error de pila insuficiente (stack underflow).")
  result = stack.pop()

proc resolveIfIdent(v: Value, env: Environment): Value =
  if v.kind == vkIdent:
    return env.lookupVar(v.identName)
  return v

proc applyOperator*(op: string, stack: var EvalStack, env: var Environment) =
  # Caso especial: Asignación (ej: x 10 =  o  x 5 2 + =)
  if op == "=":
    let rhsRaw = stack.popValue()
    let lhsRaw = stack.popValue()
    if lhsRaw.kind != vkIdent:
      raise newException(RpnTypeError, "El destino de '=' debe ser un nombre de variable, se recibió: " & $lhsRaw)
    let rhsVal = resolveIfIdent(rhsRaw, env)
    env.defineVar(lhsRaw.identName, rhsVal)
    echo lhsRaw.identName, " = ", rhsVal
    return

  # Para el resto de operadores binarios, extraemos operando derecho e izquierdo
  let b = resolveIfIdent(stack.popValue(), env)
  let a = resolveIfIdent(stack.popValue(), env)

  case op
  # Operaciones aritméticas
  of "+", "-", "*", "/":
    if not (a.isNumeric() and b.isNumeric()):
      raise newException(RpnTypeError,
        "Operación aritmética '" & op & "' inválida entre " & $a.kind & " y " & $b.kind)

    if op == "/":
      let denom = b.toFloat()
      if denom == 0.0:
        raise newException(RpnRuntimeError, "División por cero.")
      stack.add(Value(kind: vkFloat, floatVal: a.toFloat() / denom))
    elif a.kind == vkInt and b.kind == vkInt:
      # Mantiene precisión entera si ambos operandos son enteros
      let res = case op
        of "+": a.intVal + b.intVal
        of "-": a.intVal - b.intVal
        of "*": a.intVal * b.intVal
        else: 0
      stack.add(Value(kind: vkInt, intVal: res))
    else:
      # Promoción explícita a flotante en operaciones mixtas
      let fa = a.toFloat()
      let fb = b.toFloat()
      let res = case op
        of "+": fa + fb
        of "-": fa - fb
        of "*": fa * fb
        else: 0.0
      stack.add(Value(kind: vkFloat, floatVal: res))

  # Comparaciones de orden
  of "<", ">":
    if not (a.isNumeric() and b.isNumeric()):
      raise newException(RpnTypeError,
        "Comparación '" & op & "' requiere operandos numéricos, se recibió " & $a.kind & " y " & $b.kind)
    let res = if op == "<": a.toFloat() < b.toFloat() else: a.toFloat() > b.toFloat()
    stack.add(Value(kind: vkBool, boolVal: res))

  # Comparaciones de igualdad
  of "==", "!=":
    var isEqual = false
    if a.isNumeric() and b.isNumeric():
      isEqual = a.toFloat() == b.toFloat()
    elif a.kind == vkBool and b.kind == vkBool:
      isEqual = a.boolVal == b.boolVal
    else:
      raise newException(RpnTypeError,
        "No se puede comparar igualdad entre tipos incompatibles: " & $a.kind & " y " & $b.kind)
    stack.add(Value(kind: vkBool, boolVal: if op == "==": isEqual else: not isEqual))

  else:
    raise newException(RpnSyntaxError, "Operador desconocido: " & op)

proc evaluateLine*(line: string, stack: var EvalStack, env: var Environment): bool =
  ## Evalúa una línea completa de entrada. Retorna `false` si se solicitó salir.
  let tokens = tokenize(line)
  if tokens.len == 0:
    return true

  var onlyCommand = false
  for tok in tokens:
    case tok.kind
    of tkValue:
      stack.add(tok.val)
    of tkOperator:
      applyOperator(tok.op, stack, env)
    of tkCommand:
      onlyCommand = true
      case tok.cmd
      of "begin":
        env.enterScope()
        echo "-> Nuevo ámbito local abierto (nivel ", env.scopes.len - 1, ")"
      of "end":
        env.exitScope()
        echo "<- Ámbito local cerrado (nivel ", env.scopes.len - 1, ")"
      of "vars":
        env.printVars()
      of "stack":
        echo "Pila: ", stack
      of "clear":
        stack.setLen(0)
        echo "Pila limpiada."
      of "help":
        echo """
Comandos disponibles:
  Aritmética : +  -  *  /          (ej: 5 3 + 2 *)
  Lógica     : == != <  >          (ej: 10 5 >)
  Variables  : <nombre> <valor> =  (ej: x 10 =  |  x 5 +)
  Alcance    : begin / end         (crea y destruye ámbitos locales)
  Inspección : vars, stack, clear, exit
"""
      of "exit", "quit":
        return false

  # Si la línea evaluó una expresión (no fue solo un comando o asignación),
  # mostramos el resultado en el tope de la pila.
  if not onlyCommand and tokens[^1].kind != tkOperator or
     (tokens[^1].kind == tkOperator and tokens[^1].op != "="):
    if stack.len > 0:
      let top = resolveIfIdent(stack[^1], env)
      echo "=> ", top

  return true

# ----------------------------------------------------------------------------
# BUCLE PRINCIPAL (REPL)
# ----------------------------------------------------------------------------
proc main() =
  var env = initEnvironment()
  var stack: EvalStack = @[]

  echo "=== Mini-REPL RPN en Nim (CAO604) ==="
  echo "Escribe 'help' para ver los comandos o 'exit' para salir."

  while true:
    let prompt = if env.scopes.len > 1: "rpn[local#" & $(env.scopes.len - 1) & "]> " else: "rpn> "
    stdout.write(prompt)
    stdout.flushFile()

    var line: string
    try:
      line = stdin.readLine()
    except EOFError:
      echo "\nSaliendo..."
      break

    # Guardamos una copia de la pila antes de evaluar la línea para restaurarla
    # en caso de error (transaccionalidad básica ante fallos).
    let backupStack = stack
    try:
      if not evaluateLine(line, stack, env):
        break
    except RpnError as e:
      stack = backupStack
      echo "[Error] ", e.msg

when isMainModule:
  main()
