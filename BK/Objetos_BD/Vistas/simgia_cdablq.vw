create or replace force view it.simgia_cdablq as
select
(case
  when length(CDABSEQ1)>1 then substr(to_char(CDABSEQ1),-2,2)
  when length(CDABSEQ1)=1 then  to_char(CDABSEQ1)--- Otro
end) CDABSEQ,
CDABRIESGO,
CDABSUC,
CDABNUMERO,
CDABCUPON,
CDABMONTO,
CDABFEBLQ,
CDAVTOBLQ,
CDAMOTIVOB
from (
select rownum CDABSEQ1, z.*
from
(
       (Select c.cod_persona CDABRIESGO,
       c.cod_oficina CDABSUC,
       a.nro_certificado CDABNUMERO,
       '0' CDABCUPON,
       nvl(b.monto,0) CDABMONTO,
       nvl(to_char(b.fec_inicio,'YYMMDD'),0) CDABFEBLQ,
       nvl(to_char(b.fec_fin,'YYMMDD'),0) CDAVTOBLQ,
       (Select substr(descripcion,1,20)
       from ge_causales
       where tipo = 'B'
       and cod_causa= b.cod_causa) CDAMOTIVOB
       from ge_bloqueos b, ge_cta_clientes c, ah_cta_certificados a
       where b.nro_cuenta= c.nro_cuenta
       and c.nro_cuenta= a.nro_cuenta
       and b.cod_causa not in(230, 231)
       and c.relacion = 'P')
       /*PARA LOS BLOQUEADOS*/
UNION
       (Select c.cod_persona CDABRIESGO,
       c.cod_oficina CDABSUC,
       a.nro_certificado CDABNUMERO,
       ac.nro_cuenta CDABCUPON,
       nvl(cu.mto_interes,0) CDABMONTO,
       nvl(to_char(to_char(ac.fecha,'YYMMDD')),0) CDABFEBLQ,
       nvl(to_char(ac.fecha,'YYMMDD'),0) CDAVTOBLQ,
       (Select substr(descripcion,1,20)
        from ge_causales
        where tipo = 'B'
        and cod_causa= ac.cod_causa) CDAMOTIVOB
        from ge_cta_clientes c, ah_cta_certificados a, ah_cup_bloqueados ac, ah_cupones cu
        where c.nro_cuenta= a.nro_cuenta
        and ac.nro_cuenta= a.nro_cuenta
        and cu.nro_cuenta=ac.nro_cuenta and cu.nro_cupon=ac.nro_cupon
        and c.relacion = 'P')
) z
)
;

