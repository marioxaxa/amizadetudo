MACHINE           Safes

INCLUDES          Locks, Keys

PROMOTES          opendoor, closedoor, lockdoor

VARIABLES         unlocks, masterkey

INVARIANT         unlocks : KEY >+> DOOR &
                  masterkey : POW(DOOR) &
                  card(masterkey) <= 1 &
                  status~[{unlocked}] <: unlocks[keys] /\ masterkey

INITIALISATION    unlocks := {} || 
                  masterkey := {}

OPERATIONS

  allocate(kk, dd) =
  PRE kk : KEY & dd : DOOR & kk /: dom(unlocks) & dd /: ran(unlocks)
  THEN unlocks := unlocks \/ {kk |-> dd} END;

  deallocate(kk, dd) =
  PRE kk : KEY & dd : DOOR & kk |-> dd : unlocks & status(dd) = locked & kk /: keys
  THEN unlocks := unlocks - {kk |-> dd} END;

  insertmaster(dd) =
  PRE dd : DOOR & masterkey = {}
  THEN masterkey := {dd} END;

  removemaster(dd) =
  PRE dd : DOOR & dd : masterkey & status(dd) = locked
  THEN masterkey := {} END;

  insert(kk, dd) = 
  PRE kk : KEY & dd : DOOR & unlocks(kk) = dd
  THEN insertkey(kk) END;

  extract(kk, dd) = 
  PRE kk : KEY & dd : DOOR & unlocks(kk) = dd & status(dd) = locked
  THEN removekey(kk) END;

  unlock(dd) = 
  PRE dd : DOOR & unlocks~(dd) : keys & dd : masterkey
  THEN unlockdoor(dd) END;

  quicklock(dd) = 
  PRE dd : DOOR & position(dd) = closed
  THEN lockdoor(dd) || removekey(unlocks~(dd)) END;

  quickcloseandlock(dd) =
  PRE dd : DOOR & position(dd) = open & unlocks~(dd) : keys
  THEN quickclose(dd) || removekey(unlocks~(dd)) END

END