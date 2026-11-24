create or replace force view it.simgia_arcajaseg as
select to_char(nvl(ccse.cod_caj_seguridad,0)) RNUMERO,
       nvl(ccse.tipo, '') RTAMANO,
       nvl(case
       when ccse.estado like 'O' and cscon.estado like 'J' then 'J'
       when ccse.estado like 'L' then 'L'
       when ccse.estado like 'D' then 'D'
       else 'O'
       end,' ') RESTADO,
       nvl(PAI_INT.FU_SIM_NORM_CADENA((select a.nom_completo from ba_personas a where a.cod_persona = ccper.cod_persona),40),'') RTITULAR,
       nvl(PAI_INT.FU_SIM_NORM_CADENA((select b.direccion from ba_direcciones b where b.cod_persona = ccper.cod_persona and b.principal like 'S'),40),'') RDIRECC,
       ' ' RLOCALI,
       nvl((select c.telefono from ba_telefonos c where c.cod_persona = ccper.cod_persona and c.principal like 'S'),'') RTELEFO,
       ' ' ROBSERV,
       to_number(nvl(to_char(cscon.fec_apertura,'ddmmyy'),0)) RFCHINI,
       to_number(nvl(to_char(cscon.fec_ult_pago,'ddmmyy'),0)) RFCHUP,
       0 RFCHVTO,
       to_number(nvl(substr(cscon.nro_cta_debito, 1, 2),0)) RCTAOFI,
       to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(cscon.nro_cta_debito, 3, 2), cscon.cod_moneda),0)) RCUENTA,
       to_number(nvl(substr(cscon.nro_cta_debito, 5, 6),0)) RSUBCTA,
       nvl(case
       when cscon.tip_pago like 'D' then 'A'
       when cscon.tip_pago like 'E' then 'E'
       else 'M'
       end,0) RFORPAG,
       nvl(cscon.usu_insercion,0) ROPRDOR,
       to_number(nvl(to_char(cscon.fec_modificacion,'ddmmyy'),0)) RFUMODI,
       to_number(nvl(ccper.cod_persona,0)) RCLIENTE

from CS_CAJ_SEGURIDAD ccse, CS_CON_PERSONAS ccper, CS_CONTRATOS cscon

where cscon.cod_caj_seguridad = ccse.cod_caj_seguridad
and   cscon.nro_contrato = ccper.nro_contrato
and cscon.estado <> 'C'
and   ccper.tip_relacion like 'T'

union
--para las cajas que no tienen contratos y personas, los estados corresponderan a L o a D,
--podria haber  estados L y D que si tienen contratos y personas, esos ya se incluyeron en la primera parte de la vista

select to_char(nvl(ccse.cod_caj_seguridad,0)) RNUMERO,
       nvl(ccse.tipo,' ') RTAMANO,
       nvl(ccse.estado, ' ') RESTADO,
       ' ' RTITULAR,
       ' ' RDIRECC,
       ' ' RLOCALI,
       ' '  RTELEFO,
       ' ' ROBSERV,
       0 RFCHINI,
       0 RFCHUP,
       0 RFCHVTO,
       0 RCTAOFI,
       0 RCUENTA,
       0 RSUBCTA,
       ' ' RFORPAG,
       ' ' ROPRDOR,
       0 RFUMODI,
       0 RCLIENTE

from CS_CAJ_SEGURIDAD ccse

where ccse.cod_caj_seguridad not in (select cs_contratos.cod_caj_seguridad from cs_contratos)
;

