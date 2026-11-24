begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end;
/
update ba_consultas c
set c.det_sql='SELECT rubro,
                      cod_rubro,
                      nombre_rubro,
                      mon,
                      fecha,
                      moneda,
                      SUM(tot_inventario) tot_inventario,
                      CASE WHEN instr(fug_obt_pardinamico(''COD_RUB_CONS''),'',''||t.cod_rubro||'','') > 0 THEN
                      SUM(sal_contable) *-1 
                      ELSE SUM(sal_contable) END  sal_contable,
                      (SUM(tot_inventario) - CASE WHEN instr(fug_obt_pardinamico(''COD_RUB_CONS''),'',''||t.cod_rubro||'','') > 0 THEN
                                             SUM(sal_contable) *-1
                                             ELSE SUM(sal_contable) END) dif
               FROM bv_cua_com_2 t
               WHERE (' || '&' || 'P_FILTROS)
               GROUP BY rubro, cod_rubro, nombre_rubro, mon, moneda, fecha
               ORDER BY rubro ASC'
where c.cod_consulta='CD_CUACCO'; 

commit; 


