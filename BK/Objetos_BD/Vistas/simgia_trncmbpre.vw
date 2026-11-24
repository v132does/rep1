create or replace force view it.simgia_trncmbpre as
select 0 num,
 'normal' fuente,
/*documentos normales*/
nvl(to_char(lv.fecha,'YYMMDD'),'0')  RFECHA,
nvl(substr(replace(lv.hora,':',''),1,4),'0') RHORA,
decode(o.cod_mad_hijo,71,'C','V') ROPERAC,
DECODE(nvl(substr(lv.nro_documento3,-6,6), -1),-1,decode(o.afe_posicion,'E','E',decode(o.afe_transferencia,'S','T','O')),'C') RTIPO,

nvl(bm.cod_numerico,0)  RDIVISA,

nvl(lv.monto,0) RMONTOD,
nvl(lv.cot_ope,0) RCAMBIO,
nvl(lv.equ_loc,0) RMONTOG,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(lv.cod_modulo,
                                                           lv.cod_modalidad,
                                                           633,
                                                           lv.cod_moneda,
                                                           null,
                                                           0,
                                                           'D',
                                                           lv.estado)),nvl( pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(lv.cod_modulo,
                                                           lv.cod_modalidad,
                                                           632,
                                                           lv.cod_moneda,
                                                           null,
                                                           0,
                                                           'D',
                                                           lv.estado)),0)) RCUENTA,

nvl(substr(lv.nro_documento3,-6,6), 0) RNROCHQ,

decode(lv.reversado,'S','99',0) RESTADO,
nvl(lv.nro_documento,0) RBOLETA,

nvl(lv.cod_ofi_origen,0) RSUCURS,
nvl((case
  when length(lv.nro_caja)>1 then substr(to_char(lv.nro_caja),-2,2)
  when length(lv.nro_caja)=1 then  to_char(lv.nro_caja)--- Otro
end),'0') RSERVIC,


nvl( PAI_INT.FU_SIM_NORM_CADENA(
case

when length(substr(lv.nro_documento3,-6,6)) > 0 then
gm.CONCEPTO /*cheque*/
else
bp.nom_completo/*no cheque*/
end
                ,40), '') RNOMBRE,
nvl(bp.cod_persona, 0)   RNUCLI,
 'IT' RTERMIN,
nvl(lv.cod_usuario,'') ROPERAD,
0 RCOMISION,
0 RCONCEP,
0 RCLIENTE,
0 RGRUCLI
from  lv_cambios lv, lc_tip_operaciones o, ge_calendarios c, it.ba_monedas bm, ba_personas bp , gv_movimientos gm
where lv.cod_tip_ope_cambio is not null
and bm.cod_moneda = lv.cod_moneda(+)
and lv.cod_tip_ope_cambio = o.cod_tip_operacion
and lv.reversado = 'N'
and c.cod_modulo = 7
and lv.cod_tra_padre <> 761 -- Op. Futura solo cuando se concreta
and lv.fecha = c.fec_actual
and lv.nro_documento not in (select j.nro_doc_referencia
   from cj_movimientos j
   where j.fecha=c.fec_actual and
   j.nro_doc_referencia = lv.nro_documento and
    j.estado='N')

   and gm.nro_documento2 = bp.cod_persona(+)
   and gm.cod_transaccion = 760
   and gm.COD_MOD_PADRE = 7
   and gm.reversado = 'N'
   and gm.hora= lv.hora
   and gm.fecha = lv.fecha
   and gm.cod_usuario = lv.cod_usuario

union all

select rownum,
 'cj_mov' fuente,
/*con uno o dos cheques de cj_movimientos*/
nvl(to_char(lv.fecha,'YYMMDD'),'0')  RFECHA,
nvl(substr(replace(lv.hora,':',''),1,4),'0') RHORA,
decode(o.cod_mad_hijo,71,'C','V') ROPERAC,

 DECODE(nvl(substr(lv.nro_documento3,-6,6),
   nvl( j.nro_documento, -1)),-1,decode(o.afe_posicion,'E','E',decode(o.afe_transferencia,'S','T','O')),'C') RTIPO,

nvl(bm.cod_numerico,0)  RDIVISA,
nvl(j.monto,0) RMONTOD,
nvl(lv.cot_ope,0) RCAMBIO,
nvl(j.monto*lv.cot_ope,0) RMONTOG,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(lv.cod_modulo,
                                                           lv.cod_modalidad,
                                                           633,
                                                           lv.cod_moneda,
                                                           null,
                                                           0,
                                                           'D',
                                                           lv.estado)),nvl( pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(lv.cod_modulo,
                                                           lv.cod_modalidad,
                                                           632,
                                                           lv.cod_moneda,
                                                           null,
                                                           0,
                                                           'D',
                                                           lv.estado)),0)) RCUENTA,

   nvl(
   case
   when length(j.nro_documento) >6 then  substr(j.nro_documento,-6,6)
   else to_char(j.nro_documento)
   end
   , 0) RNROCHQ,

decode(lv.reversado,'S','99',0) RESTADO,
nvl(lv.nro_documento,0) RBOLETA,

nvl(lv.cod_ofi_origen,0) RSUCURS,
nvl((case
  when length(lv.nro_caja)>1 then substr(to_char(lv.nro_caja),-2,2)
  when length(lv.nro_caja)=1 then  to_char(lv.nro_caja)--- Otro
end),'0') RSERVIC,

nvl( PAI_INT.FU_SIM_NORM_CADENA(
gm.CONCEPTO /*cheque*/
                ,40), '') RNOMBRE,
nvl(bp.cod_persona, 0) RNUCLI,
 'IT' RTERMIN,
nvl(lv.cod_usuario,'') ROPERAD,
0 RCOMISION,
0 RCONCEP,
0 RCLIENTE,
0 RGRUCLI
from  lv_cambios lv, lc_tip_operaciones o, ge_calendarios c, cj_movimientos j, it.ba_monedas bm, ba_personas bp , gv_movimientos gm
where lv.cod_tip_ope_cambio is not null
and bm.cod_moneda = lv.cod_moneda(+)
and lv.cod_tip_ope_cambio = o.cod_tip_operacion
and lv.reversado = 'N'
and c.cod_modulo = 7
and lv.cod_tra_padre <> 761 -- Op. Futura solo cuando se concreta
and lv.fecha = c.fec_actual
and j.fecha=c.fec_actual
and j.nro_doc_referencia = lv.nro_documento
and j.estado='N'
and j.nro_documento is not null
   and gm.nro_documento2 = bp.cod_persona(+)
   and gm.cod_transaccion = 760
   and gm.COD_MOD_PADRE = 7
   and gm.reversado = 'N'
   and gm.hora= lv.hora
   and gm.fecha = lv.fecha
   and gm.cod_usuario = lv.cod_usuario
;

