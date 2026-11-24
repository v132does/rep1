create or replace force view it.simgia_olfauxchqn as
select to_char(nvl(substr(cche.nro_cuenta,1,2),0)) CHQSUC,
       case
       when substr(cche.nro_cuenta,3,2) IN (4,43) then
            (select substr(cb.cod_rub_externo, 1,6) from cc_cta_bancarias ccb, cb_rubros cb where ccb.cod_rubro = cb.cod_rubro and ccb.nro_cuenta = cche.nro_cuenta)
       else
            to_char(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(cche.nro_cuenta,3,2), gcue.cod_moneda),0))
       end CHQCTA,
       case
       when substr(cche.nro_cuenta,3,2) IN (4,43) then
            (select substr(cb.cod_rub_externo, 7,6) from cc_cta_bancarias ccb, cb_rubros cb where ccb.cod_rubro = cb.cod_rubro and ccb.nro_cuenta = cche.nro_cuenta)
       else
            to_char(nvl(substr(cche.nro_cuenta,5,6),0))
       end CHQSUB,

       to_number(nvl(cche.serie,0)) CHQSERIE,
       to_number(nvl(substr(cche.nro_che_inicial,-length(cche.nro_che_inicial),6),0)) CHQDESDE,
       -- to_number(nvl(cche.nro_che_inicial,0)) CHQDESDE1,
       to_char(nvl(cche.nro_che_final,0)) CHQHASTA,
       to_number(nvl(to_char(cche.fec_cam_estado,'ddmmyy'),'0')) CHQFECHA
,cche.nro_cuenta,substr(cche.nro_cuenta,3,2) vcta, gcue.cod_moneda
from CC_CHEQUERAS cche, ge_cuentas gcue
where cche.nro_cuenta = gcue.nro_cuenta
;

