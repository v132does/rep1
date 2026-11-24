create or replace force view it.iv_ttupmmdd_v as
select to_char(pai_dtm_T.fu_obt_fecha/*-1*/,'MM/DD/YYYY')||--fh_operacion
       '0007'|| --cd_agencia,
       rpad(lpad(to_char(a.cod_dtm_transaccion),3,'0'),6,' ')||--tp_transaccion
       rpad(a.tipo,1,' ')|| --nb_entrada_salida
       rpad(a.descripcion,35,' ')||--nb_transaccion_pu
       '*'CADENA
from ic_dtm_transacciones a
;

