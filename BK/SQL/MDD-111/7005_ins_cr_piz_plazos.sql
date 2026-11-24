-- Pizarra plazos GS + USD — copia mod 127 del ambiente destino
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into it.cr_piz_plazos (
  cod_modulo, cod_modalidad, cod_moneda, mto_desde, plz_desde, plz_hasta,
  tas_interes, tas_minima, tas_maxima, tip_capitalizacion, tas_efectiva, cod_sub_modalidad)
select 10, m.cod_modalidad, p.cod_moneda, p.mto_desde, p.plz_desde, p.plz_hasta,
       p.tas_interes, p.tas_minima, p.tas_maxima, p.tip_capitalizacion, p.tas_efectiva, p.cod_sub_modalidad
  from (select 138 cod_modalidad from dual
        union all select 139 from dual
        union all select 140 from dual) m
 cross join it.cr_piz_plazos p
 where p.cod_modulo = 10
   and p.cod_modalidad = 127
   and not exists (
         select 1 from it.cr_piz_plazos x
          where x.cod_modulo = 10
            and x.cod_modalidad = m.cod_modalidad
            and x.cod_moneda = p.cod_moneda);

commit;
/
