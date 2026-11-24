Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
update it.ba_consultas t
  set t.det_sql = 'SELECT o.nro_cuenta, o.denominacion, o.nro_cheque, o.cod_moneda, o.mto_cheque,
       o.sal_total, o.Sal_Fecha, o.dias_mora, o.estado, l.mto_linea_cto, o.cod_usu_oficial, o.nombre_oficial,
       o.cod_oficina, o.fec_valor, o.fec_operacion, o.hora_operacion, o.transaccion, o.desc_transaccion,
       o.usuario_pago, o. nombre_usuario_pago, desc_cobro tipo_cobro
from (
SELECT cte.nro_cuenta,cte.denominacion, cl.cod_persona, a.nro_cheque,cte.cod_moneda,a.monto as mto_cheque,
       (nvl(cte.sal_total, 0) - nvl(cte.sal_retenido, 0) - nvl(cte.sal_bloqueado, 0)) as sal_total,
       nvl((Select nvl(sd.sal_tot_cap,0) - nvl(sd.sal_blo_int,0) - nvl(sd.sal_ret_ade,0)
                from ge_sal_diarios sd
                where sd.fecha = a.fec_operacion
                  and sd.nro_cuenta = a.nro_cuenta),0) as Sal_Fecha,
       sob.can_dias as dias_mora,
       a.estado,cl.cod_usu_oficial, usu.nombre as nombre_oficial,
       usu.cod_oficina,a.fec_valor,a.fec_operacion,a.hora_operacion, a.transaccion,
       fug_obt_des_transaccion(a.modulo, a.modalidad, a.transaccion)as desc_transaccion,
       a.cod_usuario as usuario_pago,
       fue_obt_nom_usuario(a.cod_usuario) nombre_usuario_pago, a.tipo_cobro, desc_cobro
    from ge_cta_clientes ct,
       ge_clientes cl,
       cc_lin_sobregiros per,
       cc_cta_corrientes cte,
       cc_sobregiros_res sob,
       ba_usuarios usu,
       CV_CHE_SOBRG a
   where a.nro_cuenta = cte.nro_cuenta
    and cte.nro_cuenta = ct.nro_cuenta
    and cte.nro_cuenta = sob.nro_cuenta(+)
    and ct.relacion = '||chr(39)||'P'||chr(39)||'
    and ct.cod_persona = cl.cod_persona
    and usu.cod_usuario = cl.cod_usu_oficial
    and cte.nro_cuenta = per.nro_cuenta(+)
    and per.estado(+) = '||chr(39)||'A'||chr(39)||'
    and (select (nvl(cc.sal_lin_sobregiro, 0) +
                 decode(a.fec_valor, pag_cal.FU_OBT_FEC_ACTUAL(4), nvl(cc.sal_cta_corriente, 0),
                        (Select nvl(sd.sal_tot_cap,0) - nvl(sd.sal_blo_int,0) - nvl(sd.sal_ret_ade,0)
                           from ge_sal_diarios sd
                          where sd.fecha = a.fec_operacion
                            and sd.nro_cuenta = a.nro_cuenta)) +
                 decode(a.fec_valor, pag_cal.FU_OBT_FEC_ACTUAL(4), nvl(cc.sal_cta_combinada, 0),
                        decode(cc.nro_cta_ahorro, '||chr(39)||'X'||chr(39)||', 0,
                               nvl((Select nvl(sa.sal_tot_cap,0) - nvl(sa.sal_blo_int,0) - nvl(sa.sal_ret_ade,0)
                                      from ge_sal_diarios sa
                                     where sa.fecha = a.fec_operacion
                                       and sa.nro_cuenta = cc.nro_cta_ahorro),0))) -
                  decode(a.estado, '||chr(39)||'RECHAZADOS'||chr(39)||', nvl(a.monto,0),0)
                  ) as saldo_cliente
             FROM (Select aa.nro_cuenta,
                          aa.cod_moneda,
                          (nvl(aa.sal_total, 0) - nvl(aa.sal_bloqueado, 0) - nvl(aa.sal_retenido, 0)) as sal_cta_corriente,
                          fuc_obt_mto_lin_sob(aa.nro_cuenta) as sal_lin_sobregiro,
                          case
                            when aa.cta_combinada = '||chr(39)||'S'||chr(39)||' then
                             (Select (nvl(ax.sal_total, 0) - nvl(ax.sal_bloqueado, 0) - nvl(ax.sal_retenido, 0)) as saldo
                                from ah_cta_vistas ax
                               where ax.nro_cuenta = bb.nro_cta_ahorro)
                            else
                              0
                          End as sal_cta_combinada,
                          nvl(bb.nro_cta_ahorro,'||chr(39)||'X'||chr(39)||') nro_cta_ahorro
                     from cc_cta_corrientes aa, cc_cta_combinadas bb
                    where aa.nro_cuenta = bb.nro_cta_cte(+)) cc
            where cc.nro_cuenta = a.nro_cuenta) < 0
    and  ('||'&'||'P_FILTROS)

    ) o,
    (select l.cod_persona, l.monto mto_linea_cto
          from pr_lineas l
         where l.estado = '||chr(39)||'A'||chr(39)||')l
  where o.cod_persona= l.cod_persona(+)
 ORDER BY 2'
 where t.cod_consulta = 'CD_CHSOBRG';
/
commit;
