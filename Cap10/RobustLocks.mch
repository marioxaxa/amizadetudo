MACHINE           RobustLocks

INCLUDES          Locks

SETS              REPORT = {ok, error}

OPERATIONS

  oo <-- robustopen(dd) =
  PRE dd : DOOR
  THEN
    IF status(dd) = unlocked
    THEN opendoor(dd) || oo := ok
    ELSE oo := error
    END
  END;

  oo <-- robustclose(dd) =
  PRE dd : DOOR
  THEN
    closedoor(dd) || oo := ok
  END;

  oo <-- robustunlock(dd) =
  PRE dd : DOOR
  THEN
    unlockdoor(dd) || oo := ok
  END;

  oo <-- robustlock(dd) =
  PRE dd : DOOR
  THEN
    IF position(dd) = closed
    THEN lockdoor(dd) || oo := ok
    ELSE oo := error
    END
  END

END