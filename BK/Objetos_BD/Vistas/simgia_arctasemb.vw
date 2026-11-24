create or replace force view it.simgia_arctasemb as
select
/*ge.cod_embargo CENROR,*/
rownum CENROR,
to_char(ge.fecha,'DDMMYY') CEFECHAREG,
substr(ged.nro_cuenta,1,2) CESUC,
pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ged.nro_cuenta,3,2),acc.cod_moneda) CECTA,
/*substr(ged.nro_cuenta, 5, 6) CESUB,*/
acc.nro_certificado CESUB,
1  CEINDCDA,
substr(acc.denominacion,1,40)  CETITULAR ,
decode(ge.cod_moneda,'GS','0','USD','05','EUR','17')  CEMONEDA,
ged.mto_embargado CEMONTO,
0 CESALDO,
ge.motivo CECAUSA,
to_char(ge.fec_oficio,'DDMMYY')  CEFECHACOM,
0 as CEFECHACAN,
ge.cod_usuario as CEOPERADOR

from GE_EMBARGOS ge, GE_EMBARGOS_DET ged, ah_cta_certificados acc
where ge.cod_embargo = ged.cod_embargo and
ged.nro_cuenta = acc.nro_cuenta(+) and
acc.cod_modalidad = 33;

