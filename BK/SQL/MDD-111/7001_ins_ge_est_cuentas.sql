-- Estados de cuenta (6 x modalidad 138/139/140) — copia mod 127 del ambiente destino
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into it.ge_est_cuentas (cod_modulo, cod_modalidad, estado, descripcion, activo)
select 10, m.cod_modalidad, e.estado, e.descripcion, e.activo
  from (select 138 cod_modalidad from dual
        union all select 139 from dual
        union all select 140 from dual) m
 cross join it.ge_est_cuentas e
 where e.cod_modulo = 10
   and e.cod_modalidad = 127
   and not exists (
         select 1 from it.ge_est_cuentas x
          where x.cod_modulo = 10
            and x.cod_modalidad = m.cod_modalidad
            and x.estado = e.estado);

commit;
/
