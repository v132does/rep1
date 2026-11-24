alter table IT.AH_CTA_PLAZOS
add (TOT_INTERES NUMBER(18,2) default 0);
comment on column AH_CTA_PLAZOS.TOT_INTERES
  is 'Total de Interes Plazo Fijo.';

alter table IT.AH_CTA_PLAZOS
add constraint CK_TOT_INTERES_MAYOR_IGUAL_0
  check (nvl(tot_interes,0) >= 0);
