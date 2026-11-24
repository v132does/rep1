create or replace force view it.iv_trupmmdd2_v as
select rpad(a.nro_cuenta,30,' ') nu_cta_clte,
       rpad(b.cod_persona,10,' ') nu_clte,
       decode(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),
       null,rpad(b.cod_persona,10,' '),
       rpad(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),10,' ')) nu_grupo_clte,
       decode(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),
       null,rpad(pai_dtm.fu_obt_nom_cliente(b.cod_persona),10,' '),
       rpad(pai_dtm.fu_obt_nom_gru_economico(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona)),10,' ')) nb_sn_clte,
       rpad(to_char(a.cod_modalidad),5,' ') cd_tp_cta,
       rpad(to_char(a.fecha,'YYYY/MM/DD'),10,' ') fh_valor,
       rpad(a.cod_usuario,10,' ') cd_operador,
       rpad(to_char(f.cod_dtm_transaccion),6,' ') tp_transaccion,
       f.tipo,
       decode(f.tipo,
       'C',(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto,null,to_char(sysdate,'dd/mm/yyyy'))),
       'D',(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto*-1,null,to_char(sysdate,'dd/mm/yyyy'))))
       /*decode(f.tipo,
       'C',a.monto,
       'D',a.monto*-1 )*/ im_transaccion,
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
       rpad(to_char(a.cod_oficina),4,' ') cd_sucursal,
       rpad(SUBSTR(e.descripcion,1,LENGTH(e.DESCRIPCION)-1),45,' ') nb_sucursal,
       pai_dtm.fu_for_cod_gestor(pai_dtm.fu_obt_gestor(b.cod_persona)) cd_gestor,
       '1' cd_pais_gestor,
       'CALCULAR' tp_titularidad,
       decode(f.tipo,
       'C',a.monto,
       'D',a.monto*-1 )
       /*decode(f.tipo,
       'C',(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto,null,to_char(sysdate,'dd/mm/yyyy'))),
       'D',(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto*-1,null,to_char(sysdate,'dd/mm/yyyy'))))*/ im_transaccion_base
from ge_movimientos a
     inner join ge_cta_clientes b on(b.nro_cuenta=a.nro_cuenta AND b.relacion='P')
     inner join ba_oficinas e on(e.cod_oficina=a.cod_oficina)
     inner join ic_dtm_transacciones f on(f.cod_transaccion=a.cod_transaccion and f.cod_modalidad=a.cod_modalidad)
     inner join ge_clientes g on(g.cod_persona=b.cod_persona)--por inconsistencia
     inner join ge_cuentas h on(h.nro_cuenta=b.nro_cuenta)
where a.REVERSADO='N'
      and a.cod_tra_padre not in(310,309,358)
      --and exists (select 1 from dtm_ctupmmdd i where trim(i.nu_cta_ser)=a.nro_cuenta)

     /*and h.estado not in ('A','X','T')
     and ((pai_dtm.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='A')or
      ((pai_dtm.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='C')and
      ((pai_dtm.fu_obt_fec_cuentas(A.NRO_CUENTA,null,3))=(to_date(to_char(pai_dtm_v.FU_OBT_fec_actual(3),'dd/mm/yyyy'))))))*/
      /*and a.FECHA=to_date('11/11/2009','dd/mm/yyyy');*/
;

