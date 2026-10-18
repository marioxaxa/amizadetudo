MACHINE FullHotel

INCLUDES Hotel10, Hotelguests10

SEES Hotel10_ctx

PROMOTES 
    roomquery, vacancies, totalguests,
    guestquery, presentquery

INVARIANT numbers~[{0}] = pguests~[{empty}]

OPERATIONS

  fullcheckin(rr, nn, qty) =
  PRE 
    rr : ROOM & 
    nn : NAME & 
    nn /= empty & 
    qty : 1..6 & 
    numbers(rr) = 0 & 
    (rr : small => qty <= 4)
  THEN 
    checkin(rr, qty) || 
    guestcheckin(rr, nn)
  END;

  fullcheckout(rr) =
  PRE
    rr : ROOM
  THEN
    checkout(rr) ||
    guestcheckout(rr)
  END;

  fullswap(rr, ss) =
  PRE
    rr : ROOM &
    ss : ROOM &
    ((rr : small) <=> (ss : small))
  THEN
    swap(rr, ss) ||
    guestswap(rr, ss)
  END

END