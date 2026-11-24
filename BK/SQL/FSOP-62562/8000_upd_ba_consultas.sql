Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update BA_CONSULTAS
set    det_sql = 'SELECT MAX(a.fecha) fecha, c.nro_documento, c.nom_completo, a.cod_moneda,
       round(AVG(a.sal_tot_cap * nvl(pag_gen.fu_obt_cotizacion(a.cod_moneda), 1))) sal_pro_mon_local
  FROM ge_sal_diarios a, ge_cta_clientes b, ba_personas c, ge_cuentas g
 WHERE a.nro_cuenta = b.nro_cuenta
   AND b.nro_cuenta = g.nro_cuenta
   AND b.cod_modulo = g.cod_modulo
   AND b.cod_modalidad = g.cod_modalidad
   AND (g.estado IN (''A'', ''N'', ''I'') OR 
        g.estado IN (''S'') AND EXISTS (SELECT 1
                                        FROM ge_bloqueos q
                                       WHERE q.nro_cuenta = g.nro_cuenta
                                         AND q.cod_causa = 503))
   AND b.relacion = ''P''
   AND b.cod_modulo IN (3, 4)
   AND b.cod_modalidad IN (31, 334, 41)
   AND c.cod_persona = b.cod_persona
   AND fecha BETWEEN pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(3), 1) - 30 AND pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(3), 1)
   AND ('||'&'||'P_FILTROS)
 GROUP BY c.nro_documento, c.nom_completo, a.cod_moneda'
WHERE COD_CONSULTA='CD_SAL_PLO';

commit;
