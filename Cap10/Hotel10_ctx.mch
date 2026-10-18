MACHINE Hotel10_ctx

SETS ROOM; NAME; REPORT = {present, notpresent}

CONSTANTS small, sze, empty

PROPERTIES sze : NATURAL1 & card(ROOM) = sze & small <: ROOM & empty : NAME

END