/* Doors
 * Author: Allyson
 * Creation date: 19/05/2026
 */
MACHINE           Doors

SETS              DOOR; POSITION = {open, closed}

VARIABLES         position

INVARIANT         position : DOOR --> POSITION

INITIALISATION    position := DOOR * {closed}

OPERATIONS

  opening(dd) = 
  PRE dd : DOOR THEN position(dd) := open END;

  closedoor(dd) = 
  PRE dd : DOOR THEN position(dd) := closed END

END
