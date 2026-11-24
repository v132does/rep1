create or replace force view it.iv_ctupmmdd_2 as
select '0007' cd_agencia,
       rpad(a.nro_cuenta,30,' ')nu_cta_clte,
       rpad(a.cod_persona,10,' ')nu_clte

from ge_cta_clientes a
inner join ge_clientes b on(b.cod_persona=a.cod_persona)
inner join ge_cuentas c on(c.nro_cuenta=a.nro_cuenta)
inner join ba_personas d on(a.cod_persona=d.cod_persona)
where a.cod_modalidad in(31,32,33,41)
and a.relacion='P'
and c.estado not in ('A','X','T','P')
and d.cod_persona not in (select COD_PERSONA from ba_personas where cod_actividad = 702)
--para filtrar las canceladas
and ((pai_dtm_t.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='A')or
      ((pai_dtm_t.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='C')and
   ((pai_dtm_t.fu_obt_fec_cuentas(A.NRO_CUENTA,null,3))=pai_dtm_v.FU_OBT_fec_actual(3))))
--Para filtrar inmovilizadas
and  (c.estado!='I'
or (c.estado='I'and c.nro_cuenta in (select x.nro_cuenta
                                            from ge_movimientos x
                                            where x.nro_cuenta=a.nro_cuenta
                                            and x.cod_tra_padre!=310)))
and a.nro_cuenta not in ('0101296855','0101296156','0102342261')
;

