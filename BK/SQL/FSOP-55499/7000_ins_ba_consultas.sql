BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
/
insert into BA_CONSULTAS (COD_CONSULTA, DESCRIPCION, TIPO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_BLMAYOR', 'LIBRO MAYOR MANUAL', 'P', null, 'SELECT nvl(d.cod_rubro, '' '') cod_rubro,
       r.cod_moneda,
       m.descripcion moneda,
       a.fecha fec_asiento,
       to_number(substr(d.cod_rubro, 1, 2) || substr(d.cod_rubro, 4) || substr(d.cod_rubro, 3, 1)) rub_ord,
       lpad(to_char(d.cod_oficina), 3, '' '') cod_oficina,
       nvl(d.nro_asiento, 0) nro_asiento,
       nvl(d.referencia, a.cod_usuario) referencia,
       nvl(d.descripcion, '' '') descripcion,
       to_char(a.fecha, ''DD/MM/YY'') fecha,
       nvl(d.tip_movimiento, '' '') tip_movimiento,
       decode(d.tip_movimiento, ''D'', d.mto_mon_local, 0) debito,
       decode(d.tip_movimiento, ''C'', d.mto_mon_local, 0) credito,
       decode(d.tip_movimiento, ''D'', d.mto_mon_rubro, 0) deb_me,
       decode(d.tip_movimiento, ''C'', d.mto_mon_rubro, 0) cre_me,
       nvl(a.cod_usuario, '' '') cod_usuario,
       nvl(d.nro_linea, 0) nro_linea,
       nvl(c.sal_mon_rub_ant, 0) sal_mon_rub_ant,
       nvl(c.sal_mon_loc_ant, 0) sal_mon_loc_ant,
       r.descripcion des_rubro
  FROM ba_monedas m, cb_sal_consolidados c, cb_asientos_det d, cb_asientos a, cb_rubros r
 WHERE r.cod_moneda = m.cod_moneda
   AND c.cod_rubro = d.cod_rubro
   AND a.cod_oficina = d.cod_oficina
   AND a.nro_asiento = d.nro_asiento
   AND a.fecha = d.fecha
   AND d.cod_rubro = r.cod_rubro
   AND a.actualizado = ''S''
   AND d.actualizado = ''S''
   AND (&P_FILTROS)
UNION
SELECT nvl(d.cod_rubro, '' '') cod_rubro,
       r.cod_moneda,
       b.descripcion moneda,
       a.fecha fec_asiento,
       to_number(substr(d.cod_rubro, 1, 2) || substr(d.cod_rubro, 4) || substr(d.cod_rubro, 3, 1)) rub_ord,
       lpad(to_char(d.cod_oficina), 3, '' '') cod_oficina,
       nvl(d.nro_asiento, 0) nro_asiento,
       nvl(d.referencia, a.cod_usuario) referencia,
       nvl(d.descripcion, '' '') descripcion,
       to_char(a.fecha, ''DD/MM/YY'') fecha,
       nvl(d.tip_movimiento, '' '') tip_movimiento,
       decode(d.tip_movimiento, ''D'', d.mto_mon_local, 0) debito,
       decode(d.tip_movimiento, ''C'', d.mto_mon_local, 0) credito,
       decode(d.tip_movimiento, ''D'', d.mto_mon_rubro, 0) deb_me,
       decode(d.tip_movimiento, ''C'', d.mto_mon_rubro, 0) cre_me,
       nvl(a.cod_usuario, '' '') cod_usuario,
       nvl(d.nro_linea, 0) nro_linea,
       (SELECT nvl(x.sal_mon_rub_ant, 0) + nvl(x.deb_mon_rubro, 0) - nvl(x.cre_mon_rubro, 0)
          FROM cb_sal_consolidados_dia x
         WHERE x.fecha = pag_cal.fu_obt_fec_ant_hab(a.fecha, NULL)
           AND x.cod_rubro = c.cod_rubro) sal_mon_rub_ant,
       
       (SELECT nvl(x.sal_mon_loc_ant, 0) + nvl(x.deb_mon_local, 0) - nvl(x.cre_mon_local, 0)
          FROM cb_sal_consolidados_dia x
         WHERE x.fecha = pag_cal.fu_obt_fec_ant_hab(a.fecha, NULL)
           AND x.cod_rubro = c.cod_rubro) sal_mon_loc_ant,
       r.descripcion des_rubro
  FROM ba_monedas b,
       cb_sal_consolidados_dia c,
       cb_asientos_det_his d,
       cb_asientos_his a,
       cb_rubros r
 WHERE r.cod_moneda = b.cod_moneda
   AND c.cod_rubro = d.cod_rubro
   AND c.fecha = a.fecha
   AND a.cod_oficina = d.cod_oficina
   AND a.nro_asiento = d.nro_asiento
   AND a.fecha = d.fecha
   AND d.cod_rubro = r.cod_rubro
   AND a.actualizado = ''S''
   AND d.actualizado = ''S''
   AND (&P_FILTROS)
ORDER BY 1, 3, 4, 6', null, null, null);

commit;
