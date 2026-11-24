create or replace force view it.bv_deu_cli_historico_crc_new as
Select a.FEC_PROCESO as FECHA,
       a.cod_persona as COD_PERSONA,
       fue_obt_nom_persona(a.cod_persona) as NOM_APEL,
       a.CLA_ENTIDAD as CAT,
       a.CLA_SISTEMA as CAT_SIS,
       to_char(a.TOT_DEU_ENTIDAD,'999G999G999G999')  as R_DIRECTO,
       to_char(a.TOT_DEU_SISTEMA,'999G999G999G999')  as R_DIRECTO_SISTEMA,
       to_char(a.TOT_CON_ENTIDAD,'999G999G999G999')  as CONTING,
       to_char(a.TOT_CON_SISTEMA,'999G999G999G999')  as CONTING_SISTEMA,
       to_char(sum(a.TOT_DEU_ENTIDAD + a.TOT_DEU_SISTEMA + a.TOT_CON_ENTIDAD + a.TOT_CON_SISTEMA),'999G999G999G999')  as RIESGO_DIRECTO_TOTAL,
       to_char(a.Tot_Cou_Entidad,'999G999G999G999')  as CODE,
       to_char(a.Tot_Cou_SISTEMA,'999G999G999G999')  as CODE_SISTEMA,
       to_char(a.Tot_Riesgo,'999G999G999G999')  as TOTAL_RIESGO
  from ge_bcp_clasificacion_his a
group by a.cod_persona,
         a.CLA_ENTIDAD,
         a.CLA_SISTEMA,
         a.TOT_DEU_ENTIDAD,
         a.TOT_DEU_SISTEMA,
         a.TOT_CON_ENTIDAD,
         a.TOT_CON_SISTEMA,
         a.Tot_Cou_SISTEMA,
         a.Tot_Cou_Entidad,
         a.Tot_Riesgo ,
         a.Fec_Proceso;

