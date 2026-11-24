create or replace force view it.simgia_argytap as
select lc.nro_referencia RGTNRO, PAI_INT.FU_SIM_NORM_CADENA(substr(lc.observacion,1,20),20) RGTREFC, nvl(to_char(lc.fec_valor,'yymmdd'),0) RGTFVAL,
decode(lc.cod_moneda,'GS','PYG',lc.cod_moneda) RGTMONE,
lc.monto RGTMONTO,
' ' RGTMONEORI,  /*irrelevante*/
0 RGTMONTORI, /*irrelevante */
nvl(lc.cod_oficina,0) RGTSUC,
nvl(lc.cod_per_beneficiario,999999) RGTCLIEN,
PAI_INT.FU_SIM_NORM_CADENA(lc.nom_beneficiario,40) RGTNOMBRE,
/*nvl(( select cdr.cod_rub_externo
from cb_rubros cdr
where cdr.cod_rubro = lc.cod_rubro),'0') RGTCTA,*/
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(case
                                                      when lc.fec_valor <= trunc(sysdate) then 7
                                                      when lc.fec_valor > trunc(sysdate) then  4--- Otro
                                                    end,
                                                    case
                                                      when lc.fec_valor <= trunc(sysdate) then 71
                                                      when lc.fec_valor > trunc(sysdate) then  45--- Otro
                                                    end, /*lc.cod_modalidad,*/
                                                    case
                                                      when lc.fec_valor <= trunc(sysdate) then 286
                                                      when lc.fec_valor > trunc(sysdate) then  1503--- Otro
                                                    end,
                                                    LC.COD_MONEDA,
                                                    LC.COD_PER_BENEFICIARIO,
                                                    0,
                                                    'D',
                                                    lc.estado)),0) RGTCTA,
/*(select ebt.cod_banco_as
from it.equiv_bco_trans ebt
where ebt.cod_banco_it = lc.cod_bco_corresponsal) RGTCCOR,*/
PAI_INT.FU_SIM_OBT_CODCORR(lc.cod_bco_corresponsal,lc.cod_moneda) RGTCCOR,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.nom_solicitante,1,35),35) RGTORDEN1,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.nom_solicitante,35,35),35) RGTORDEN2,
nvl(PAI_INT.FU_SIM_NORM_CADENA(substr(lc.nom_solicitante,105,35),35),' ') RGTORDEN3,
nvl(PAI_INT.FU_SIM_NORM_CADENA(substr(lc.nom_solicitante,140,35),35),' ') RGTORDEN4,
PAI_INT.FU_SIM_NORM_CADENA(lc.nom_banco,35) RGTBANCO,
(select eq.cod_pais_bbva
from it.equiv_paises eq, lc_transferencias a
where eq.cod_pais_it = a.cod_pai_solicitante
and a.cod_pai_solicitante= lc.cod_pai_solicitante
and a.nro_referencia= lc.nro_referencia
and a.cod_tip_referencia= lc.cod_tip_referencia) RGTPAIS,
PAI_INT.FU_SIM_NORM_CADENA(lc.nro_cta_referencia,35) RGTBENEF1,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.nom_solicitante,1,35),35) RGTBENEF2,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.dir_beneficiario,1,35),35) RGTBENEF3,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.nom_ciu_beneficiario,1,35),35) RGTBENEF4,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.observacion,1,35),35) RGTREFER1,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.observacion,35,35),35) RGTREFER2,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.observacion,70,35),35) RGTREFER3,
PAI_INT.FU_SIM_NORM_CADENA(substr(lc.observacion,105,35),35) RGTREFER4,
nvl(lc.usu_modificacion,0) RGTREGPOR,
to_char(lc.fec_operacion,'yymmdd') RGTFREG,
decode(lc.estado,'OK','P','DE','D','AN','A','FO',' ','PE',' ') RGTESTADO,
0 RGTPSUC, /*irrelevante*/
0 RGTPCTA, /*irrelevante*/
0 RGTPSUB, /*irrelevante*/
0 RGTFPAG, /*irrelevante*/
0 RGTLIQPAG, /*irrelevante*/
' ' RGTPAGPOR, /*irrelevante*/
nvl(to_char(tf.tip_fondo), '0') RGTORIGEN,
decode(nvl(to_char(tm.tip_motivo), '0'), '0', '7', '22', '0', nvl(to_char(tm.tip_motivo), '0')) RGTMOTIVO,
decode(nvl(to_char(tfi.tip_financiacion), '0'), '0', '5', nvl(to_char(tfi.tip_financiacion), '0')) RGTFINANC,
0 RGTFCOB,
lc.usu_insercion RGTOPRCOB
from lc_transferencias lc,
     (select val_minimo tip_fondo from ba_cod_referencias where dominio = 'TRA_TIP_FONDO') tf,
     (select val_minimo tip_motivo from ba_cod_referencias where dominio = 'TRA_TIP_MOTIVO') tm,
     (select val_minimo tip_financiacion from ba_cod_referencias where dominio = 'TRA_TIP_FINANCIACION') tfi
where lc.tip_fondo =  tf.tip_fondo(+)
  and lc.tip_motivo = tm.tip_motivo(+)
  and lc.tip_financiacion = tfi.tip_financiacion(+)
  and lc.cod_modalidad = 75
;

