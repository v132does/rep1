CREATE OR REPLACE TRIGGER IT.TS_SB_CRC_VTA_CARTERAS
 BEFORE
  INSERT OR DELETE OR UPDATE
 ON "IT"."SB_CRC_VTA_CARTERAS"
 REFERENCING NEW AS NEW OLD AS OLD
 FOR EACH ROW

DECLARE
 v_fec_ope_vta date;
BEGIN

   begin
    select  MIN(V.FEC_OPE_ENTE) fec_ope_vta
    into v_fec_ope_vta
      from sb_crc_vta_carteras v
     where v.cod_modulo         = :new.cod_modulo
       and v.cod_modalidad      = :new.cod_modalidad
       and v.cod_oficina        = :new.cod_oficina
       and v.cod_moneda         = :new.cod_moneda
       and v.tip_operacion      = :new.tip_operacion
       and v.nro_cuenta_bt      = :new.nro_cuenta_bt
       and v.tip_documento      = :new.tip_documento
       and v.nro_documento      = :new.nro_documento
       and v.estado_vta_cartera = 'C'
       ;
      exception
         when no_data_found then
           v_fec_ope_vta := null;
         when others then
           v_fec_ope_vta := null;
      end;

    if v_fec_ope_vta is not null and inserting then


      update sb_crc_vta_carteras v
      set v.estado_vta_cartera = 'N',
          v.ope_recaptada = 'S'
     where v.cod_modulo         = :new.cod_modulo
       and v.cod_modalidad      = :new.cod_modalidad
       and v.cod_oficina        = :new.cod_oficina
       and v.cod_moneda         = :new.cod_moneda
       and v.tip_operacion      = :new.tip_operacion
       and v.nro_cuenta_bt      = :new.nro_cuenta_bt
       and v.tip_documento      = :new.tip_documento
       and v.nro_documento      = :new.nro_documento
       and v.estado_vta_cartera = 'C'
       and v.fec_ope_ente       = v_fec_ope_vta;
   end if;
END;
/

