create or replace force view it.iv_tiupmmdd as
select '0007'||
        rpad(to_char(a.val_minimo),9,' ')||
        rpad(a.significado,40,' ')||
        TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MM/DD/YYYY')||
        '*' cadena

 from ba_cod_referencias a
 where a.dominio='DTM_RIESGO';

