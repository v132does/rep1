create or replace force view it.iv_ctupmmdd_v as
select '0007' ||--cd_agencia,
       rpad(a.nro_cuenta,30,' ')||--nu_cta_ser,
       rpad(a.cod_persona,10,' ')||--nu_cta,
       decode(pai_dtm.fu_obt_cod_gru_economico(a.cod_persona),
       null,rpad(a.cod_persona,10,' '),
       rpad(pai_dtm.fu_obt_cod_gru_economico(a.cod_persona),10,' '))||-- nu_parent_num,
       DECODE(pai_dtm.fu_obt_nom_gru_economico(pai_dtm.fu_obt_cod_gru_economico(a.cod_persona)),
       NULL,decode(pai_dtm.fu_obt_nom_cliente(a.cod_persona),
                    NULL,RPAD(' ',10,' '),
                    RPAD(pai_dtm.fu_obt_nom_cliente(a.cod_persona),10,' ')),
       RPAD(pai_dtm.fu_obt_nom_gru_economico(pai_dtm.fu_obt_cod_gru_economico(a.cod_persona)),10,' '))||--sn_parent_num,
       rpad(to_char(a.cod_modalidad),5,' ')||--cd_tipo_cuenta,
       decode(pai_dtm.fu_obt_nom_cliente(a.cod_persona),
       null,rpad(' ',35,' ' ),
       rpad(replace(pai_dtm.fu_obt_nom_cliente(a.cod_persona),chr(10),' '),35,' ') )||--nb_cliente,
       nvl(rpad(pai_dtm_v.fu_obt_tip_persona(a.cod_persona),2,' '),rpad(' ',2,' ')) ||--tp_titularidad
       pai_dtm.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)||--cd_edo_cta,
       decode(to_char(pai_dtm.fu_obt_fec_cuentas(A.NRO_CUENTA,A.COD_MODALIDAD,1)),
              null,rpad('01/01/2001',10,' '),/*volver a modificar el valor 8*/
              to_char(pai_dtm.fu_obt_fec_cuentas(A.NRO_CUENTA,A.COD_MODALIDAD,1),'MM/DD/YYYY'))||--fh_ult_transaccion,
       nvl(to_char(pai_dtm.fu_obt_fec_cuentas(A.NRO_CUENTA,NULL,2),'MM/DD/YYYY'),rpad('01/01/2001',10,' '))||--fh_apertura,
       decode(pai_dtm.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD),
              'A','01/01/2001',
              'C',(to_char(pai_dtm.fu_obt_fec_cuentas(A.NRO_CUENTA,null,3),'MM/DD/YYYY'))) ||-- fh_cancelacion,
       rpad(pai_dtm.fu_for_cod_gestor(pai_dtm.fu_obt_gestor(a.cod_persona)),8,' ')||-- cd_gestor,
       rpad('1',5,' ')||--cd_pais_gestor,
       nvl(rpad(to_char(pai_dtm_v.fu_obt_pais(A.COD_PERSONA)),5,' '),rpad('1',5,' '))||--cd_pais_resid_clte,
       nvl(to_char(pai_dtm_v.fu_obt_fec_ing_cliente(A.COD_PERSONA),'MM/DD/YYYY'),rpad('01/01/2001',10,' '))||--fh_alte_clte,
       rpad(c.cod_moneda,4,' ')||-- cd_moneda,
       nvl(rpad(to_char(d.cod_actividad),4,' '),rpad('701',4,' '))||--cd_tp_industria
       '*' CADENA
from ge_cta_clientes a
inner join ge_clientes b on(b.cod_persona=a.cod_persona)
inner join ge_cuentas c on(c.nro_cuenta=a.nro_cuenta)
inner join ba_personas d on(a.cod_persona=d.cod_persona)
where a.cod_modalidad in(31,32,33,41)
and a.relacion='P'
and c.estado not in ('A','X','T','P')
--para filtrar las canceladas
and ((pai_dtm.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='A')or
      ((pai_dtm.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='C')and
   ((pai_dtm.fu_obt_fec_cuentas(A.NRO_CUENTA,null,3))=(to_date(to_char(pai_dtm_v.FU_OBT_fec_actual(3),'dd/mm/yyyy'))))))
--Para filtrar inmovilizadas
and  (c.estado!='I'
or (c.estado='I'and c.nro_cuenta in (select x.nro_cuenta
                                            from ge_movimientos x
                                            where x.nro_cuenta=a.nro_cuenta
                                            and x.cod_tra_padre!=310)))

/*and c.fec_apertura<=to_date('09/11/2009','dd/mm/yyyy')
and trunc(a.fec_insercion)<=to_char(to_date('09/11/09','dd/mm/yyyy'))
and trunc(b.fec_insercion)<=to_date('09/11/2009','dd/mm/yyyy')*/
;

