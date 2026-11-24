create or replace force view it.iv_diupmmdd_x as
select '0007'||--CD_AGENCIA,
          TO_CHAR(A.FECHA,'MM/DD/YYYY')||--FH_DIA_INHABIL,

          '*'CADENA
    from IC_DIA_INHABILES A
;

