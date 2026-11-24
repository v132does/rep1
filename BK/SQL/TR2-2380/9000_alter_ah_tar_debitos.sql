-- Create/Recreate check constraints 
alter table it.AH_TAR_DEBITOS
  drop constraint AVCON_1119032741_COD_E_000;
alter table it.AH_TAR_DEBITOS
  add constraint AVCON_1119032741_COD_E_000
  check (COD_EST_SOLICITUD IN (0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 15, 16, 17, 18, 19, 25, 26))
  novalidate;
