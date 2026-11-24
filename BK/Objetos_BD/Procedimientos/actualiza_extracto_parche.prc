create or replace procedure it.ACTUALIZA_EXTRACTO_PARCHE is
cursor AHORRO is
 select a.nro_cuenta,
        a.sal_ult_extracto,
        a.fec_ult_extracto
 from AH_ULT_EXTRACTO a;
cursor CORRIENTE is
 select a.nro_cuenta,
        a.sal_ult_extracto,
        a.fec_ult_extracto
 from CC_ULT_EXTRACTO a;

begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1 ; END;
   for x in AHORRO loop
        update ah_cta_vistas ah
         set ah.sal_ult_extracto = x.sal_ult_extracto,
             ah.fec_ult_extracto = x.fec_ult_extracto
         where ah.nro_cuenta = x.nro_cuenta;
    end loop;
    commit;

   for Y in CORRIENTE loop
        update CC_CTA_CORRIENTES C
         set C.sal_ult_extracto = Y.sal_ult_extracto,
             C.FEC_ULT_EXTRACTO = Y.fec_ult_extracto
         where C.nro_cuenta = Y.nro_cuenta;
    end loop;
 commit;
end ACTUALIZA_EXTRACTO_PARCHE;
/

