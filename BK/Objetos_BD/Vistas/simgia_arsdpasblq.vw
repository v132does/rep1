create or replace force view it.simgia_arsdpasblq as
select
    /*MAEACT/ARSDPASBLQ (SALDOS DE PASIVO PIGNORADOS O EMBARGADOS)
    PBLSUC     PACKED       2  0       2         1        Ambos    PBLSUC
    PBLCTA     PACKED       6  0       4         3        Ambos    PBLCTA
    PBLSUB     PACKED       6  0       4         7        Ambos    PBLSUB
    PBLSDOACT  PACKED      13  2       7        11        Ambos    PBLSDOACT
    PBLMAYOR   PACKED      12  0       7        18        Ambos    PBLMAYOR
    PBLRIESGO  PACKED       6  0       4        25        Ambos    PBLRIESGO*/
    /*cta cte*/
    nvl(to_number(substr(ccco.nro_cuenta,1,2)),0) PBLSUC,
    nvl(to_number(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ccco.nro_cuenta,3,2),ccco.cod_moneda)),0) PBLCTA,
    nvl(to_number(substr(ccco.nro_cuenta,5,6)),0) PBLSUB,
    nvl(ccco.SAL_BLOQUEADO,0) PBLSDOACT,
    nvl(pai_int.FU_OBT_CTA_CONTABLE(fub_obt_rub_transaccion(ccco.cod_modulo,
                            ccco.cod_modalidad,
                            602,
                            ccco.cod_moneda,
                            gcc.cod_persona,
                            '1',
                            'C')),0) PBLMAYOR,
    nvl(gcc.cod_persona,0) PBLRIESGO

    from cc_cta_corrientes ccco,  ge_cta_clientes gcc, ge_clientes gc--, cb_rubros r
where   ccco.nro_cuenta = gcc.nro_cuenta(+)
and     gc.cod_persona(+) = gcc.cod_persona
and     gcc.relacion like 'P'
and     ccco.SAL_BLOQUEADO > 0

union all

select

/*caja ahorro*/
  nvl(to_number(substr(acv.nro_cuenta,1,2)),0) PBLSUC,
  nvl(to_number(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(acv.nro_cuenta,3,2),acv.cod_moneda)),0) PBLCTA,
  nvl(to_number(substr(acv.nro_cuenta,5,6)),0) PBLSUB,
  nvl(acv.SAL_BLOQUEADO,0) PBLSDOACT,
  nvl(pai_int.FU_OBT_CTA_CONTABLE(fub_obt_rub_transaccion(acv.cod_modulo,
                                                             acv.cod_modalidad,
                                                             682,
                                                             acv.cod_moneda,
                                                             gcc.cod_persona,
                                                              '1',
                                                             decode(acv.cta_combinada,'S','C','D'))),0) PBLMAYOR,
  nvl(gcc.cod_persona,0) PBLRIESGO

from ah_cta_vistas acv, cc_cta_combinadas ccc, ge_cta_clientes gcc, ge_clientes gc
where acv.nro_cuenta = ccc.nro_cta_ahorro(+)
and   acv.nro_cuenta = gcc.nro_cuenta
and   gc.cod_persona(+)=gcc.cod_persona
and   gcc.relacion like 'P'
and acv.SAL_BLOQUEADO > 0
;

