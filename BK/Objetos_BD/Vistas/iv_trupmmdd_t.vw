create or replace force view it.iv_trupmmdd_t as
select to_char(rpad(to_char(pai_dtm_t.fu_obt_fecha,'MM/DD/YYYY'),10,' '))||
       '0007'||
       rpad(a.nro_cuenta,30,' ')||-- NU_CTA_SER,
       rpad(b.cod_persona,10,' ')||-- NU_CTA,
       decode(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),
              null,rpad(b.cod_persona,10,' '),
              rpad(to_char(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona)),10,' ') )||-- NU_PARENT_NUM,
       decode(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona),
              null,decode(pai_dtm.fu_obt_nom_cliente(b.cod_persona),
                          null,' ',10,' ',
                          rpad(pai_dtm.fu_obt_nom_cliente(b.cod_persona),10,' ')),
       rpad(pai_dtm.fu_obt_nom_gru_economico(pai_dtm.fu_obt_cod_gru_economico(b.cod_persona)),10,' '))||-- SN_PARENT_NUM,
       rpad(to_char(a.cod_modalidad),5,' ')||-- CD_TIPO_CUENTA,
       rpad(to_char(a.fecha,'MM/DD/YYYY'),10,' ')||-- fh_valor,
       rpad(a.cod_usuario,10,' ')||-- cd_operador,
       rpad(lpad(to_char(f.cod_dtm_transaccion),3,'0'),5,' ')||-- tp_transaccion,
       decode(f.tipo,
       'C',pai_dtm.fu_for_montos(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto,null,to_char(sysdate,'dd/mm/yyyy'))),
       'D',pai_dtm.fu_for_montos(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto*-1,null,to_char(sysdate,'dd/mm/yyyy'))))
       /* decode(f.tipo,
       'C',pai_dtm.fu_for_montos(a.monto),
       'D',pai_dtm.fu_for_montos(a.monto*-1) )*/||-- im_transaccion,
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
       rpad(' ',16,' ')||--nu_referencia
       lpad(to_char(a.cod_oficina),4,'0')||-- COD_SUC_OPERACION,
       rpad(SUBSTR(e.descripcion,1,LENGTH(e.DESCRIPCION)-1),45,' ')||-- NB_SUC_OPERACION,
       rpad(pai_dtm.fu_for_cod_gestor(pai_dtm.fu_obt_gestor(b.cod_persona)),8,' ')||-- CD_GESTOR,
       rpad('1',5,' ')|| --CD_PAIS_GESTOR,
       rpad(pai_dtm_v.fu_obt_tip_persona(b.cod_persona),3,' ')||--TP_TITULARIDAD
       decode(f.tipo,
       'C',pai_dtm.fu_for_montos(a.monto),
       'D',pai_dtm.fu_for_montos(a.monto*-1))
       /*decode(f.tipo,
       'C',pai_dtm.fu_for_montos(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto,null,to_char(sysdate,'dd/mm/yyyy'))),
       'D',pai_dtm.fu_for_montos(fub_con_mon_a_moneda(a.cod_moneda,'USD',a.monto*-1,null,to_char(sysdate,'dd/mm/yyyy'))))*/||-- im_transaccion_base

       '*'CADENA

from gv_movimientos a
     inner join ge_cta_clientes b on(b.nro_cuenta=a.nro_cuenta AND b.relacion='P')
     inner join ba_oficinas e on(e.cod_oficina=a.cod_oficina)
     inner join ic_dtm_transacciones f on(f.cod_transaccion=a.cod_transaccion and f.cod_modalidad=a.cod_modalidad)
     --inner join ge_clientes g on(g.cod_persona=b.cod_persona)--por inconsistencia
where a.FECHA=pai_dtm_t.fu_obt_fecha
       and a.REVERSADO='N'
       and a.cod_tra_padre not in(310,309,358)
       --and exists (select 1 from dtm_ctupmmdd i where i.nu_cta_ser=a.nro_cuenta)
;

