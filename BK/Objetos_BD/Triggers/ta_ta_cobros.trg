CREATE OR REPLACE TRIGGER IT.TA_TA_COBROS
 AFTER update or insert
 ON "IT"."TA_COBROS"
 FOR EACH ROW
declare
  v_cod_envio ge_par_web_servicios.cod_envio%type;
  v_cod_programa varchar2(40) :=  pat_val.G_PROCESO;
  v_pag_lin_habilitado ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('TA_PAG_LINEA');
begin
  if nvl(v_pag_lin_habilitado,'N') = 'S' then
      v_cod_programa := pat_val.G_PROCESO;
      if ( v_cod_programa = 'PRT_DEB_AUTOMATICO' and :old.estado = 'E' and :new.estado = 'P') or
          ( v_cod_programa = 'FUJ_PRO_TRANSACCION_250' and :new.estado in ('C','P')) or
          ( v_cod_programa = 'PRT_GEN_ACR_GOURMET' and :new.estado = 'P') or
          ( v_cod_programa = 'PRT_DEB_AUTOMATICO_24X7' and :new.estado = 'P') or
          ( v_cod_programa = 'PRT_DEB_AUTOMATICO_ATR' and :old.estado IS NULL and :new.estado = 'P') or
          ( v_cod_programa = 'PAW_BEE_LP_AUT_PAG_TARJETA') or
           (v_cod_programa = 'PRA_LIB_RETENCION') then

            select S_COD_ENVIO.NEXTVAL into v_cod_envio from dual;
            insert into ge_par_web_servicios
              (cod_envio, fecha, cod_servicio, estado, dat_enviados, cod_programa, reg_pago)
            values
              (v_cod_envio,
               :new.fec_proceso,
               '000002', --codigo para el servicio de pago de tarjetas
               'P',
               'cardNumber=' || :new.nro_tarjeta || '&' || 'amount=' || :new.monto , --cardNumber=NRO_TARJETA&amount=MONTO
               v_cod_programa,
               :new.rowid);
         pat_val.G_PROCESO := null;
       end if;
   end if;
end;
/

