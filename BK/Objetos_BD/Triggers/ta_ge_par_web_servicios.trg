CREATE OR REPLACE TRIGGER IT.TA_GE_PAR_WEB_SERVICIOS
  after update on ge_par_web_servicios
  for each row
declare
  v_nro_tarjeta   ta_tarjetas.nro_tarjeta%type;
  v_tabla         ba_programas.ubi_ejecutable%type;
  v_estado        ge_par_web_servicios.estado%type;
  v_log_error     ge_par_web_servicios.log_error%type;
  v_mto_pagado    ta_cobros.monto%type;
  v_reg_pago      rowid;
  -- local variables here
begin

  if updating then

     v_tabla := fug_obt_ubi_ejecutable(:new.cod_programa);
     v_estado   := :new.estado;
     v_log_error   := :new.log_error;
     v_nro_tarjeta := substr(:new.dat_enviados,0,16);
     
     if v_tabla = 'TA_BLO_AUT_TARJETAS' then

         v_nro_tarjeta := substr(:new.dat_enviados,0,16);

            update ta_blo_aut_tarjetas a
               set a.estado = v_estado,
                   a.log_error = v_log_error
              where a.nro_tarjeta = v_nro_tarjeta
                and a.estado = 'P'
                and a.fecha = pag_cal.FU_OBT_FEC_ACTUAL(5);

     elsif (v_tabla = 'FUJ_PRO_TRANSACCION_250' and :new.estado = 'E') or
           (v_tabla = 'PRA_LIB_RETENCION' and :new.estado = 'E') or
           (v_tabla = 'PRT_DEB_AUTOMATICO' and :new.estado = 'E') or
           (v_tabla = 'PRT_GEN_ACR_GOURMET' and :new.estado = 'E') or           
           (v_tabla = 'PRT_DEB_AUTOMATICO_24X7' and :new.estado = 'E') or           
           (v_tabla = 'PRT_DEB_AUTOMATICO_ATR' and :new.estado = 'E')then
       BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
       v_nro_tarjeta := substr(:new.dat_enviados,12,16);
       --DYDMR-7571 - Incidencia SAU - ITGF - Error en el Trigger de TA_GE_PAR_WEB_SERVICIOS
       v_mto_pagado  := substr(:new.dat_enviados,36,12);
       v_reg_pago    := :old.reg_pago;
       update ta_cobros a
          set a.est_envio = 'W'
        where rowid = v_reg_pago;
          /*a.nro_tarjeta = v_nro_tarjeta
          and a.fec_proceso = :new.fecha
--          and a.estado = 'P'
          and a.est_envio = 'P'
          and a.monto = v_mto_pagado
          and rownum < 2; -- DYDMR-7033 JUL/2017 OMM. Hubo 2 pagos de la misma tarjeta con diferente monto.*/
     end if;

  end if;

end ta_ge_par_web_servicios;
/

