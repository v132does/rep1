create or replace force view it.iv_inupmmdd_v as
select to_char(rpad(to_char(pai_dtm_v.FU_OBT_fec_actual(3)/*-1*/,'MM/DD/YYYY'),10,' '))||
       '0007' ||--cd_agencia,
       rpad(a.nro_cuenta,30,' ')||-- nu_cta_ser,
       rpad(b.cod_persona,10,' ')||-- nu_cta,
       decode(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),
              null,rpad(b.cod_persona,10,' '),
              rpad(to_char(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona)),10,' ') )||-- nu_parent_num,
       decode(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),
              null,decode(pai_dtm.fu_obt_nom_cliente(b.cod_persona),
                          null,' ',10,' ',
                          rpad(pai_dtm.fu_obt_nom_cliente(b.cod_persona),10,' ')),
       rpad(pai_dtm.fu_obt_nom_gru_economico(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona)),10,' '))||-- sn_parent_num,
       rpad(to_char(a.cod_modalidad),5,' ')||-- cd_tipo_cuenta,
       rpad(to_char(pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,
                                               a.cod_modalidad,
                                               2),'MM/DD/YYYY'),10,' ')||-- fh_inicio,
       rpad(to_char(pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,
                                        a.cod_modalidad,
                                        4),'MM/DD/YYYY'),10,' ')||-- fh_fin,
       substr(to_char(fug_obt_val_tasa(a.cod_modulo,
                        b.cod_modalidad,
                        b.cod_oficina,
                        b.nro_cuenta,
                        c.cod_moneda,
                        pai_dtm.fu_obt_cap_cuenta(b.nro_cuenta,
                                        b.cod_modalidad),
                        c.tas_personalizada,
                        c.cod_tasa,
                        null,
                        pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,
                                               a.cod_modalidad,
                                               2)),'000.0000'),2,8)||-- NU_TASA,
       lpad(pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,a.cod_modalidad,4)-
            pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,a.cod_modalidad,2),4,'0')||-- nu_plazo,
       rpad(' ',16,' ')|| --nu_referencia,
       rpad(a.cod_usuario,10,' ')||-- cd_operador,
       rpad(lpad(to_char(d.cod_dtm_transaccion),3,'0'),5,' ')||-- tp_transaccion,
       decode(d.tipo,
       'C',pai_dtm.fu_for_montos((fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto,null,to_char(sysdate,'dd/mm/yyyy')))),
       'D',pai_dtm.fu_for_montos((fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto*-1,null,to_char(sysdate,'dd/mm/yyyy')))))
       /*decode(d.tipo,
       'C',pai_dtm.fu_for_montos(A.MONTO),
       'D',pai_dtm.fu_for_montos((A.MONTO *-1)))*/||-- im_transaccion,
       rpad(a.cod_moneda,4,' ')||-- cd_moneda,
       decode(a.nro_documento,
       null, rpad(' ',35,' '),
       rpad(to_char(a.nro_documento),35,' '))||-- narrativa1,
       decode(a.nro_documento2,
       null, rpad(' ',35,' '),
       rpad(to_char(a.nro_documento2),35,' '))||-- narrativa2,
       decode(a.nro_documento3,
       null, rpad(' ',35,' '),
       rpad(to_char(a.nro_documento3),35,' '))||-- narrativa3,
       decode(a.nro_documento4,
       null, rpad(' ',35,' '),
       rpad(to_char(a.nro_documento4),35,' '))||-- narrativa4,
       rpad(pai_dtm.fu_for_cod_gestor(pai_dtm.fu_obt_gestor(b.cod_persona)),8,' ')||-- cd_gestor,
       rpad('1',5,' ')|| --cd_pais_gestor
       nvl(rpad(to_char(pai_dtm_v.fu_obt_pais(b.cod_persona)),5,' '),rpad('1',5,' '))||-- cd_pais_residENCIA,
       decode(d.tipo,
       'C',pai_dtm.fu_for_montos(A.MONTO),
       'D',pai_dtm.fu_for_montos((A.MONTO *-1)))
       /*decode(d.tipo,
       'C',pai_dtm.fu_for_montos((fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto,null,to_char(sysdate,'dd/mm/yyyy')))),
       'D',pai_dtm.fu_for_montos((fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto*-1,null,to_char(sysdate,'dd/mm/yyyy')))))*/||-- im_transaccion_base
       '*'CADENA

from ge_movimientos a
inner join ge_cta_clientes b on(b.nro_cuenta=a.nro_cuenta and b.relacion='P')
inner join ge_cuentas c on(a.nro_cuenta=c.nro_cuenta)
inner join ic_dtm_transacciones d on(d.cod_modalidad=a.cod_modalidad and d.cod_transaccion=a.cod_transaccion )
inner join ge_clientes e on(b.cod_persona=e.cod_persona)--por la inconsistencia
where b.cod_modalidad in(32,33)
and a.REVERSADO='N'
and a.cod_tra_padre not in(310,309,358)
--and exists (select 1 from dtm_ctupmmdd dtm where trim(dtm.nu_cta_ser)=a.nro_cuenta)
      /*and a.FECHA=to_date('27/10/2009','dd/mm/yyyy')*/
;

