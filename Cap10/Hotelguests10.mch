MACHINE Hotelguests10

SEES Hotel10_ctx

VARIABLES pguests

INVARIANT pguests : ROOM +-> NAME

INITIALISATION pguests := ROOM * {empty}

OPERATIONS

  guestcheckin(rr, nn) =
  PRE rr : ROOM & nn : NAME & nn /= empty
  THEN pguests(rr) := nn
  END;

  guestcheckout(rr) =
  PRE rr : ROOM
  THEN pguests(rr) := empty
  END;

  nn <-- guestquery(rr) =
  PRE rr : ROOM
  THEN nn := pguests(rr)
  END;

  rr <-- presentquery(nn) =
  PRE nn : NAME & nn /= empty
  THEN
    IF nn : ran(pguests)
    THEN rr := present
    ELSE rr := notpresent
    END
  END;

  guestswap(rr, ss) =
  PRE rr : ROOM & ss : ROOM
  THEN pguests := pguests <+ {rr |-> pguests(ss), ss |-> pguests(rr)}
  END

END