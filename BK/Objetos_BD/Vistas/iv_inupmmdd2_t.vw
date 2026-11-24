create or replace force view it.iv_inupmmdd2_t as
select to_char(rpad(to_char(trunc(sysdate),'YYYY/MM/DD'),10,' ')) fe_,
       '0007' cd_agencia,
       rpad(a.nro_cuenta,30,' ') nu_cta_clte,
       rpad(b.cod_persona,10,' ') nu_clte,
       decode(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),
              null,rpad(b.cod_persona,10,' '),
              rpad(to_char(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona)),10,' ') ) nu_grupo_clte,
       decode(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),
              null,rpad(pai_dtm.fu_obt_nom_cliente(b.cod_persona),10,' '),
       rpad(pai_dtm.fu_obt_nom_gru_economico(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona)),10,' ')) nb_sn_cliente,
       rpad(to_char(a.cod_modalidad),5,' ') cd_tp_cta,
       rpad(to_char(pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,
                                               a.cod_modalidad,
                                               2),'YYYY/MM/DD'),10,' ') fh_inicio,
       rpad(to_char(pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,
                                        a.cod_modalidad,
                                        4),'YYYY/MM/DD'),10,' ') fh_fin,
       rpad(fug_obt_val_tasa(a.cod_modulo,
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
                                               2)),5,' ') pc_tasa_interes,
       rpad(pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,a.cod_modalidad,4)-
            pai_dtm.fu_obt_fec_cuentas(a.nro_cuenta,a.cod_modalidad,2),4,' ') nu_plazo,
       rpad(' ',16,' ') nu_referencia,
       rpad(a.cod_usuario,10,' ') cd_operador,
       rpad(to_char(d.cod_dtm_transaccion),6,' ') tp_transaccion,
       decode(d.tipo,
       'C',(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto,null,to_char(sysdate,'dd/mm/yyyy'))),
       'D',(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto*-1,null,to_char(sysdate,'dd/mm/yyyy'))))
       /*decode(d.tipo,
       'C',(A.MONTO),
       'D',(A.MONTO *-1) )*/ im_transaccion,
        rpad(a.cod_moneda,4,' ') cd_moneda,
       decode(a.nro_documento,
       null, rpad(' ',35,' '),
       rpad(to_char(a.nro_documento),35,' ')) narrativa1,
       decode(a.nro_documento2,
       null, rpad(' ',35,' '),
       rpad(to_char(a.nro_documento2),35,' ')) narrativa2,
       decode(a.nro_documento3,
       null, rpad(' ',35,' '),
       rpad(to_char(a.nro_documento3),35,' ')) narrativa3,
       decode(a.nro_documento4,
       null, rpad(' ',35,' '),
       rpad(to_char(a.nro_documento4),35,' ')) narrativa4,
       pai_dtm.fu_for_cod_gestor(pai_dtm.fu_obt_gestor(b.cod_persona)) cd_gestor,
       rpad('1',5,' ') cd_pais_gestor,
       rpad(to_char(pai_dtm.fu_obt_pais(b.cod_persona)),5,' ') cd_pais_resid_clte,
       decode(d.tipo,
       'C',(A.MONTO),
       'D',(A.MONTO *-1) )
       /*decode(d.tipo,
       'C',(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto,null,to_char(sysdate,'dd/mm/yyyy'))),
       'D',(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto*-1,null,to_char(sysdate,'dd/mm/yyyy'))))*/ im_transaccion_base

from gv_movimientos a
inner join ge_cta_clientes b on(b.nro_cuenta=a.nro_cuenta and b.relacion='P')
inner join ge_cuentas c on(a.nro_cuenta=c.nro_cuenta)
inner join ic_dtm_transacciones d on(d.cod_modalidad=a.cod_modalidad and d.cod_transaccion=a.cod_transaccion and d.tipo in('C','D'))
--inner join ge_clientes e on(b.cod_persona=e.cod_persona)--por la inconsistencia
where a.FECHA=pai_dtm_t.fu_obt_fecha
and b.cod_modalidad in(32,33)
and a.REVERSADO='N'
and a.cod_tra_padre not in(310,309,358)
--and exists (select 1 from dtm_ctupmmdd dtm where trim(dtm.nu_cta_ser)=a.nro_cuenta)
/*and a.FECHA=to_date('27/10/2009','dd/mm/yyyy')*/
;

