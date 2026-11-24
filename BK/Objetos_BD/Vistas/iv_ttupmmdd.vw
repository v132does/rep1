create or replace force view it.iv_ttupmmdd as
select to_char(pai_dtm_v.FU_OBT_fec_actual(3),'MM/DD/YYYY')||--fh_operacion
       '0007'|| --cd_agencia,
       rpad(lpad(to_char(a.cod_dtm_transaccion),3,'0'),6,' ')||--tp_transaccion
       rpad(a.tipo,1,' ')|| --nb_entrada_salida
       rpad(a.descripcion,35,' ')||--nb_transaccion
       '*'CADENA
from ic_dtm_transacciones a
;

