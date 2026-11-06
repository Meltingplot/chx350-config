; self-test/check-dsf.g
; Can the machine start the self-test by itself? Called once by config.g, hands the answer back in
; global.self_test_can_start. M98.3 (start a macro on the HTTP channel) exists from DSF 3.7.0+mp.11.
; An older DSF hands it to RRF, which looks for a macro M98.3.g and answers "not supported" with
; result 1, the same as a busy channel (GCodes::TryMacroFile): a warning every minute, for ever.
; Fork versions: 3.7.0-rc.X+mp.N lack it, 3.7.0+mp.N has it from N = 11, a later base has it, and mp.N
; starts at 1 again on every base. Stock DSF has no "mp." and an unknown format counts as not having
; it: the tile and start.g still run the tiers. Each find() on a line of its own, see config.g at T8.

set global.self_test_can_start = false
if exists(sbc.dsf.version)
  var dsf = sbc.dsf.version
  if find(var.dsf, "mp.") >= 0
    if find(var.dsf, "3.7.0+mp.") == 0
      var fork = drop(var.dsf, 9)
      var number = 0
      while iterations < #var.fork
        var digit = find("0123456789", take(drop(var.fork, iterations), 1))
        if var.digit < 0
          break
        set var.number = {var.number * 10 + var.digit}
      set global.self_test_can_start = var.number >= 11
    else
      var rc = find(var.dsf, "3.7.0")
      var old36 = find(var.dsf, "3.6")
      var old35 = find(var.dsf, "3.5")
      set global.self_test_can_start = var.rc != 0 && var.old36 != 0 && var.old35 != 0
  if !global.self_test_can_start
    M118 P0 S{"Warning: DSF " ^ var.dsf ^ " has no M98.3 - the self-test does not start by itself"}
