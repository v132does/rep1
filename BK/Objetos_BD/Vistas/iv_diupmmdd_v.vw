create or replace force view it.iv_diupmmdd_v as
select '0007'||--CD_AGENCIA,
          rpad(TO_CHAR(A.FECHA,'MM/DD/YYYY'),17,' ')||--FH,

          '*'CADENA
    from IC_DIA_INHABILES A
;

