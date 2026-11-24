# Mini-REPL Evaluador Postfijo (RPN)

![Nim](https://img.shields.io/badge/Nim-2.0+-FFE953?style=flat-square&logo=nim&logoColor=white)
![License](https://img.shields.io/badge/Licencia-MIT-blue?style=flat-square)
![Status](https://img.shields.io/badge/Estado-Completado-success?style=flat-square)

**Proyecto: Asignación #1**  
**Materia:** CAO604 – Lenguajes de Programación  
**Institución:** Universidad de Carabobo (UC) - FACYT  
**Semestre:** 1-2026  
*Un entorno interactivo de consola basado en pila con chequeo estático de tipos, alcance léxico y manejo de memoria explícito.*

---

## 📑 Tabla de Contenidos
1. [Descripción general](#-descripción-general)
2. [Características principales](#-características-principales)
3. [Requisitos previos](#-requisitos-previos)
4. [Instalación y Compilación](#-instalación-y-compilación)
5. [Ejecución](#-ejecución)
6. [Uso: Sintaxis y Comandos](#-uso-sintaxis-y-comandos)
7. [Sesión de prueba de ejemplo](#-sesión-de-prueba-de-ejemplo)
8. [Estructura del código](#-estructura-del-código)
9. [Decisiones de diseño](#-decisiones-de-diseño)
10. [Tecnologías utilizadas](#-tecnologías-utilizadas)

---

## 📖 Descripción general

Este proyecto implementa un Mini-REPL (Read-Eval-Print Loop) que evalúa expresiones matemáticas y lógicas utilizando **Notación Polaca Inversa (RPN)**. En esta notación, los operandos preceden a los operadores (por ejemplo, `5 3 +` en lugar de `5 + 3`), lo que permite que el motor de evaluación funcione de manera determinista basándose en una arquitectura de pila (Stack), sin necesidad de paréntesis ni reglas de precedencia complejas. 

Sirve como demostración técnica para la materia de Lenguajes de Programación, ilustrando conceptos fundamentales de diseño de lenguajes bajo el ecosistema de **Nim**.

---

## ⚡ Características principales

El código implementa rigurosamente los 4 requisitos técnicos exigidos en la asignación:

*   **1. Evaluación en Pila y Manejo de Errores:** La evaluación extrae y empuja datos sobre una `EvalStack`. Los errores en tiempo de ejecución (underflow de pila, división por cero) se capturan mediante un sistema de excepciones idiomático que hereda de `CatchableError` (ej. `RpnRuntimeError`), garantizando que el REPL recupere el control e informe al usuario sin abortar el proceso.
*   **2. Sistema de Tipos del Evaluador:** Emplea "Object Variants" (uniones etiquetadas) a través del tipo `Value` discriminado por el enum `ValueKind` (`vkInt`, `vkFloat`, `vkBool`, `vkIdent`). Esto provee chequeo de tipos estricto (ej. impidiendo sumar un número con un booleano).
*   **3. Variables y Paso de Parámetros:** Permite mutar la memoria mediante el comando `=`. El estado del programa se gestiona pasando el entorno y la pila por referencia (préstamo mutable) hacia los procedimientos (`proc`) utilizando la palabra clave `var` (ej. `env: var Environment`), evidenciando el manejo explícito de memoria.
*   **4. Alcance Local (Scoping y Shadowing):** Implementa entornos dinámicos estructurados como una pila de diccionarios (`seq[Table[string, Value]]`). Comandos como `begin` y `end` (`enterScope`, `exitScope`) controlan el ciclo de vida de los ámbitos, permitiendo "shadowing" y garantizando que la memoria global permanezca inalterada tras cerrar un bloque.

---

## ⚙️ Requisitos previos

Para compilar y ejecutar el proyecto, el sistema debe contar con:
*   **Compilador de Nim** (Versión 1.6+ o superior).
*   **Compilador de C** (como `gcc`, `clang` o `mingw-w64` en Windows), ya que Nim compila a C por defecto.

**Verificación:**
```bash
nim --version
gcc --version
```

---

## 🛠 Instalación y Compilación

1. Clona este repositorio:
   ```bash
   git clone <URL_DEL_REPOSITORIO>
   cd <CARPETA_DEL_REPOSITORIO>
   ```

2. Ejecuta el programa de forma directa (compila y corre en un solo paso):
   ```bash
   nim c -r main.nim
   ```

3. *Alternativa:* Para generar el binario optimizado para producción sin ejecutarlo inmediatamente:
   ```bash
   nim c -d:release main.nim
   ```
   Esto generará un ejecutable llamado `main` (o `main.exe` en Windows) en el mismo directorio.

---

## 🚀 Ejecución

Una vez compilado, puedes arrancar el REPL ejecutando el binario generado:
```bash
./main
```

Verás el mensaje de bienvenida y el prompt principal indicando el estado del ámbito:
*   Ámbito global: `rpn> `
*   Ámbitos locales: `rpn[local#1]> `

Para salir del REPL, ingresa el comando `exit`, `quit`, o utiliza la señal `EOF` (Ctrl+D en Linux/macOS, Ctrl+Z en Windows).

---

## ⌨️ Uso: Sintaxis y Comandos

El REPL procesa líneas de texto tokenizando por espacios en blanco.

### Operadores
| Operador | Operación                  | Ejemplo de entrada | Salida   |
|:--------:|:---------------------------|:-------------------|:---------|
| `+`      | Suma                       | `5 3 +`            | `8`      |
| `-`      | Resta                      | `10 2 -`           | `8`      |
| `*`      | Multiplicación             | `4 2 *`            | `8`      |
| `/`      | División (produce Float)   | `9 2 /`            | `4.5`    |
| `==`     | Igualdad lógica            | `5 5 ==`           | `true`   |
| `!=`     | Desigualdad lógica         | `5 3 !=`           | `true`   |
| `<`      | Menor que                  | `2 10 <`           | `true`   |
| `>`      | Mayor que                  | `10 2 >`           | `true`   |
| `=`      | Asignación de variable     | `x 100 =`          | `x = 100`|

### Comandos de control (Sistema)
| Comando | Descripción de la implementación en el REPL (`evaluateLine`) |
|:--------|:-------------------------------------------------------------|
| `begin` | Invoca `enterScope()`, apilando una nueva tabla hash vacía.  |
| `end`   | Invoca `exitScope()`, destruyendo el ámbito local actual.    |
| `vars`  | Imprime las variables activas respetando reglas de shadowing.|
| `stack` | Muestra el estado actual de la pila de operandos.            |
| `clear` | Vacía por completo la pila (`stack.setLen(0)`).              |
| `help`  | Muestra la ayuda rápida en pantalla.                         |
| `exit`  | Finaliza el proceso cerrando el bucle del REPL.              |

---

## 🧪 Sesión de prueba de ejemplo

A continuación, se demuestra una interacción real con el evaluador que valida las reglas de la asignación.

```text
=== Mini-REPL RPN en Nim (CAO604) ===
Escribe 'help' para ver los comandos o 'exit' para salir.

rpn> 5 3 +
=> 8
rpn> 5 3 + 2 *
=> 16
rpn> 10 2 /
=> 5.0
rpn> x 10 =
x = 10
rpn> x 5 + 2 *
=> 30
rpn> 10 5 >
=> true

rpn> 5 true +
[Error] Operación aritmética '+' inválida entre vkInt y vkBool
rpn> 5 0 /
[Error] División por cero.
rpn> +
[Error] Error de pila insuficiente (stack underflow).

rpn> x 10 =
x = 10
rpn> begin
-> Nuevo ámbito local abierto (nivel 1)
rpn[local#1]> x 99 =
x = 99
rpn[local#1]> vars
Variables activas (nivel de ámbito actual: 1):
  x = 99  [local#1]
rpn[local#1]> end
<- Ámbito local cerrado (nivel 1)
rpn> vars
Variables activas (nivel de ámbito actual: 0):
  x = 10  [global]
```

---

## 🧩 Estructura del código

El archivo fuente `main.nim` está organizado en las siguientes secciones conceptuales:
1.  **Tipos y Errores:** Declaración de `ValueKind`, `TokenKind` y los `CatchableError` personalizados.
2.  **Abstracción del Entorno:** El tipo `Environment` y utilidades polinórficas de representación (Sobrecarga de `$`).
3.  **Gestión de Memoria (Procs):** Funciones `enterScope`, `exitScope`, `defineVar` y `lookupVar`.
4.  **Análisis Léxico:** La función `tokenize` que clasifica literales, comandos y operadores.
5.  **Evaluación:** `applyOperator` (ejecuta la lógica matemática/lógica) y `evaluateLine` (orquesta la línea).
6.  **Bucle REPL:** El bloque `main` con lectura interactiva y manejo de transacciones en la pila.

---

## 🧠 Decisiones de diseño

1.  **Object Variants como Sum Types:** Se optó por usar los tipos variantes de Nim (`case kind: ValueKind`) en lugar de herencia clásica. Esto permite que la evaluación de tipos en tiempo de ejecución sea cerrada y exhaustiva, impidiendo comportamientos ambiguos en operaciones no compatibles.
2.  **Resolución perezosa de identificadores:** Cuando se lee una variable (ej. `x`), el evaluador no la busca inmediatamente. Se empaqueta como `vkIdent` y se apila. La resolución a su valor real solo ocurre cuando es consumida por un operador mediante el procedimiento `resolveIfIdent()`. Esto permite la dualidad necesaria para el operador de asignación `=`.
3.  **Errores mediante excepciones (CatchableError):** Se utilizaron excepciones controladas en lugar de retornar monadas como `Option` para simplificar el flujo del tokenizador a lo largo de las capas, delegando al bloque `try / except` del bucle principal la tarea de atrapar el fallo y emitir el aviso sin interrumpir la ejecución.
4.  **Transaccionalidad parcial de errores:** Si un comando falla en medio de su ejecución, la pila de evaluación se restaura a su estado original (se hace un respaldo previo al `evaluateLine`). Sin embargo, los efectos secundarios aplicados al entorno (`Environment`) no tienen "rollback", reflejando el comportamiento típico de shells iterativas.
5.  **División flotante estricta:** Al igual que en lenguajes modernos de tipado estático, la división `/` siempre realiza una promoción implícita a flotante.

---

## 💻 Tecnologías utilizadas

*   **Lenguaje:** [Nim](https://nim-lang.org/)
*   **Librería Estándar:** Módulos `strutils` (parsing), `tables` (diccionarios para scopes), `sets` (manejo de variables únicas).
*   **Backend:** Compilador GCC.

---
