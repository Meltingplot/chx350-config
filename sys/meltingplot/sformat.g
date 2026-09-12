; sformat.g - format a number with a fixed number of decimals, right aligned in a column
;
; Parameters:
;   F<value>   number to format (required)
;   D<int>     decimal places   (default 2)
;   W<int>     column width     (default 10)
;   C"<char>"  pad character    (default " ")
;
; Usage: M98 P"0:/sys/meltingplot/sformat.g" F{sensors.probes[0].value[0]} D3 W12
;
; RRF macros cannot return a value, so the formatted string is handed back in
; global.result - the same variable the rest of the project uses for integer error
; codes. That is safe under the project rule: global.result is only valid immediately
; after the call that set it. Read it on the next line; never assume a value of yours
; survives an intervening call.

if !exists(param.F)
  echo "sformat: missing F parameter"
  set global.result = ""    ; still a string, so the caller cannot read a stale value
  M99

var digits = exists(param.D) ? floor(param.D) : 2
var width = exists(param.W) ? floor(param.W) : 10
var pad = exists(param.C) ? param.C : " "
var scale = round(pow(10, var.digits))

; Start from RRF's own rendering: it keeps the decimal places the value was
; written with (345678.90 -> "345678.90") and falls back to 7 places for a
; computed one (5.68 -> "5.6799998"). Never scale the whole value into an
; integer - floats are single precision here, so 345678.90 * 100 already
; lands on 34567892 (above 2^24 the integers are no longer exact).
var text = "" ^ param.F
var negative = (take(var.text, 1) == "-")
if var.negative
  set var.text = drop(var.text, 1)

var dot = find(var.text, ".")
var integer = (var.dot == -1) ? var.text : take(var.text, var.dot)
var decimals = (var.dot == -1) ? "" : drop(var.text, var.dot + 1)

if #var.decimals <= var.digits
  ; the rendering is already exact at this precision - only widen the fraction
  while #var.decimals < var.digits
    set var.decimals = var.decimals ^ "0"
else
  ; more decimals than asked for: round numerically, but split the integer part
  ; off first so only the fraction (< 1) gets scaled and the magnitude cannot
  ; drag the result off (that is what breaks a plain round(value * scale)).
  var value = abs(param.F)
  var whole = floor(var.value)
  var frac = {round((var.value - var.whole) * var.scale)}
  if var.frac >= var.scale                 ; 9.999 D2 -> 10.00
    set var.frac = var.frac - var.scale
    set var.whole = var.whole + 1
  set var.integer = "" ^ var.whole
  set var.decimals = "" ^ var.frac
  while #var.decimals < var.digits         ; 5 -> "05"
    set var.decimals = "0" ^ var.decimals

; the sign is dropped when the value rounds to zero, so no "-0.00"
var sign = (var.negative & abs(param.F) > 0.5 / var.scale) ? "-" : ""
set var.text = var.sign ^ var.integer ^ ((var.digits > 0) ? "." ^ var.decimals : "")

var padding = min(max(var.width - #var.text, 0), 64)    ; clamped: the loop bound comes from a parameter
var result = ""
while iterations < var.padding
  set var.result = var.result ^ var.pad

set global.result = var.result ^ var.text
