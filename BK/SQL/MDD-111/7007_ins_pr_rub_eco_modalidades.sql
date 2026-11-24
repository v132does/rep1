-- Rubro economico — copia mod 127 del ambiente destino
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into it.pr_rub_eco_modalidades (cod_modulo, cod_modalidad, cod_rub_economico, referencia)
select 10, m.cod_modalidad, r.cod_rub_economico, r.referencia
  from (select 138 cod_modalidad from dual
        union all select 139 from dual
        union all select 140 from dual) m
 cross join it.pr_rub_eco_modalidades r
 where r.cod_modulo = 10
   and r.cod_modalidad = 127
   and not exists (
         select 1 from it.pr_rub_eco_modalidades x
          where x.cod_modulo = 10
            and x.cod_modalidad = m.cod_modalidad
            and x.cod_rub_economico = r.cod_rub_economico);

commit;
/
