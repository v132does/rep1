Alter table IT.GE_CAUSALES
  add constraint CK_TIPO_CAUSALES
  check (TIPO IN ('A', 'B', 'C', 'D','F', 'G', 'H','I', 'J','L', 'O', 'R', 'T', 'X', 'S', 'V', 'N', 'E', 'M', 'P', 'K','W','Q','U'));
