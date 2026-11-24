create or replace force view it.iv_ttupmmdd2 as
select a.cod_dtm_transaccion,
       a.tipo ,
       a.descripcion

from ic_dtm_transacciones a;

