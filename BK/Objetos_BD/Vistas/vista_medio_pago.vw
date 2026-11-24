create or replace force view it.vista_medio_pago as
select a.de_id,
       a.itipago,
       a.ddestipag,
       a.dmontipag,
       a.cmonetipag,
       a.ddmonetipag,
       a.dticamtipag,
       a.identarj,
       a.ddesdentarj,
       a.drsprotar, --10
       a.drucprotar,
       a.ddvprotar,
       a.iforpropa,
       a.dcodauope,
       a.dnomtit,
       a.dnumtarj,
       a.dnumcheq,
       a.dbcoemi
  from cb_medio_pago a
 order by 1
;

