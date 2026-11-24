create or replace force view it.iv_ctupmmdd_t_2 as
select '0007' cd_agencia,
       rpad(a.nro_cuenta,30,' ')nu_cta_ser,
       rpad(a.cod_persona,10,' ')nu_cta,
       nvl(rpad(pai_dtm_t.fu_obt_cod_gru_economico(a.cod_persona),10,' '),rpad(a.cod_persona,10,' ')) nu_parent_num,
       nvl(RPAD(pai_dtm_t.fu_obt_nom_gru_economico(pai_dtm_t.fu_obt_cod_gru_economico(a.cod_persona)),10,' '),
           nvl(RPAD(pai_dtm_t.fu_obt_nom_cliente(a.cod_persona),10,' '),RPAD(' ',10,' '))) sn_parent_num/*,
       rpad(to_char(a.cod_modalidad),5,' ') cd_tipo_cuenta,
       decode(pai_dtm_t.fu_obt_nom_cliente(a.cod_persona),
       null,rpad(' ',35,' ' ),
       rpad(pai_dtm_t.fu_obt_nom_cliente(a.cod_persona),35,' ') ) nb_cliente,
       nvl(rpad(pai_dtm_t.fu_obt_tip_persona(a.cod_persona),2,' '),rpad(' ',2,' ')) tp_titularidad,
       pai_dtm_t.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)cd_edo_cta,
       decode(to_char(pai_dtm_t.fu_obt_fec_cuentas(A.NRO_CUENTA,A.COD_MODALIDAD,1)),
              null,rpad('01/01/2001',10,' '),\*volver a modificar el valor 8*\
              to_char(pai_dtm_t.fu_obt_fec_cuentas(A.NRO_CUENTA,A.COD_MODALIDAD,1),'MM/DD/YYYY'))fh_ult_transaccion,
       nvl(to_char(c.fec_apertura,'MM/DD/YYYY'),rpad('01/01/2001',10,' '))fh_apertura,
       decode(pai_dtm_t.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD),
              'A','01/01/2001',
              'C',(to_char(pai_dtm_t.fu_obt_fec_cuentas(A.NRO_CUENTA,null,3),'MM/DD/YYYY'))) fh_cancelacion,
       rpad(pai_dtm_t.fu_for_cod_gestor(pai_dtm_t.fu_obt_gestor(a.cod_persona)),8,' ')cd_gestor,
       rpad('1',5,' ')cd_pais_gestor,
       nvl(rpad(to_char(pai_dtm_t.fu_obt_pais(A.COD_PERSONA)),5,' '),rpad('1',5,' '))cd_pais_resid_clte,
       nvl(to_char(pai_dtm_t.fu_obt_fec_ing_cliente(A.COD_PERSONA),'MM/DD/YYYY'),rpad('01/01/2001',10,' '))fh_alte_clte,
       rpad(c.cod_moneda,4,' ')cd_moneda,
       nvl(rpad(to_char(d.cod_actividad),4,' '),rpad('701',4,' '))cd_tp_industria*/

from ge_cta_clientes a
--inner join ge_clientes b on(b.cod_persona=a.cod_persona)
inner join ge_cuentas c on(c.nro_cuenta=a.nro_cuenta)
inner join ba_personas d on(a.cod_persona=d.cod_persona)
where a.cod_modalidad in(31,32,33,41)
and a.relacion='P'
and c.estado not in ('A','X','T','P')
and c.fec_apertura<=pai_dtm_t.fu_obt_fecha
--para filtrar las canceladas
and ((pai_dtm_t.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='A')or
      ((pai_dtm_t.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='C')and
   ((pai_dtm_t.fu_obt_fec_cuentas(A.NRO_CUENTA,null,3))=pai_dtm_t.fu_obt_fecha)))
--Para filtrar inmovilizadas
and  (c.estado!='I'
or (c.estado='I'and exists(select 1 from gv_movimientos x
                                    where x.nro_cuenta=a.nro_cuenta
                                    and x.cod_tra_padre!=310
                                    and x.FECHA=pai_dtm_t.fu_obt_fecha)))
;

