create or replace force view it.simgia_artrnsfc as
select rownum RCNTRNSF,
nvl(to_char(lc.fec_operacion,'yymmdd'),'0') RCFECHA,
nvl(decode(lc.cod_msj_swift,202,'B',103,'C'),'') RCSOLIC,
nvl(lc.cod_oficina,0) RCSUC,
nvl((select decode(cod_moneda,'GS','PYG',cod_moneda)
  from it.ba_monedas
  where cod_moneda= lc.cod_moneda),'')  RCMONEDA,
nvl(lc.monto,0) RCMONTO,
nvl(lc.cod_per_solicitante,0) RCCLIEN,
nvl(PAI_INT.FU_SIM_NORM_CADENA(lc.nom_solicitante,35),'') RCORDEN,
nvl(PAI_INT.FU_SIM_NORM_CADENA(lc.observacion,35),'') RCBCOBEN,
nvl(PAI_INT.FU_SIM_NORM_CADENA(lc.nom_beneficiario,35),'') RCBENEFI,
nvl((select eq.cod_pais_bbva
from it.equiv_paises eq
where eq.cod_pais_it = lc.cod_pai_beneficiario
),'') RCPAIS,
lc.tip_fondo RCORIGEN,
decode(lc.tip_motivo, '0', '7', lc.tip_motivo) RCMOTIVO,
decode(lc.tip_financiacion, '0', '5', lc.tip_financiacion) RCFINANC,
nvl(to_char(lc.fec_valor,'yymmdd'),'0') RCFCHVAL,
nvl(lc.usu_inserCion,'') RCREGOPR,
DECODE(lc.estado,'A','99','E','1','C','0','P','0') RCESTADO,
nvl(lc.nro_referencia,'') RCVEROPR,
nvl(lc.cod_tip_referencia,'') RCPROOPR,
nvl(lc.usu_modificacion,'') RCENVOPR,
nvl(to_char(lc.fec_envio,'yymmdd'),'0') RCFCHENV,
nvl(to_char(lc.fec_operacion,'yymmdd'),'0') RCFCHDEB
from lc_transferencias lc
where lc.cod_modalidad = 72;

