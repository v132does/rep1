-- Solo transaccion 401 CAMEST — copia fila mod 127 del ambiente destino
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into it.ge_transacciones (
  cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo,
  abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch,
  cod_retencion, interno, afecta, cod_tip_asiento2, detallado, cod_tip_asi_resultado, tip_despliegue)
select t.cod_transaccion, 10, m.cod_modalidad, t.descripcion, t.ve_cliente, t.tipo,
       t.abreviatura, t.rutina1, t.rutina2, t.rutina3, t.cod_tip_asiento, t.cod_tasa, t.batch,
       t.cod_retencion, t.interno, t.afecta, t.cod_tip_asiento2, t.detallado, t.cod_tip_asi_resultado, t.tip_despliegue
  from (select 138 cod_modalidad from dual
        union all select 139 from dual
        union all select 140 from dual) m
 cross join it.ge_transacciones t
 where t.cod_modulo = 10
   and t.cod_modalidad = 127
   and t.cod_transaccion = 401
   and not exists (
         select 1 from it.ge_transacciones x
          where x.cod_modulo = 10
            and x.cod_modalidad = m.cod_modalidad
            and x.cod_transaccion = t.cod_transaccion);

commit;
/
