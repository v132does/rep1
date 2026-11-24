CREATE OR REPLACE TRIGGER IT.TA_TA_BLO_AUT_TARJETAS
  after insert or update on ta_blo_aut_tarjetas  
  for each row
DECLARE
  r_par_web   ge_par_web_servicios%rowtype;
  v_cod_envio varchar2(10);
  v_modalidad ge_cta_clientes.cod_modalidad%type;

  function fl_obt_cod_modalidad(p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type)
    return number is
  begin
    select a.cod_modalidad
      into v_modalidad
      from ta_cta_tarjetas a, ta_tarjetas b
     where a.nro_cuenta = b.nro_cuenta
       and b.nro_tarjeta = p_nro_tarjeta
       and b.cod_persona = :new.cod_persona;
    return 1;
  exception
    when others then
      v_modalidad := null;
      return 0;
  end;
BEGIN
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;
  if inserting then
  
    select S_COD_ENVIO.NEXTVAL into v_cod_envio from dual;
  
    v_cod_envio := lpad(v_cod_envio, 10, 0);--DYDMR-13550 Se amplía longitud de la secuencia.
  
    r_par_web.cod_envio    := v_cod_envio;
    r_par_web.fecha        := pag_cal.FU_OBT_FEC_ACTUAL(5);
    r_par_web.cod_servicio := '000001';
    r_par_web.estado       := 'P';
    r_par_web.dat_enviados := :new.dat_bloqueo;
    r_par_web.log_error    := '';
    --Para definir si el proceso que realiza la inserción es
    -- de '1'-Bloqueo o '3'-Desbloqueo.
    --Definidos como parámetros dinámicos, según la modalidad.
    if fl_obt_cod_modalidad(:new.nro_tarjeta) = 1 then
      if :new.tip_operacion =
         fug_obt_pardinamico('TIP_OPERACION', 5, v_modalidad) then
        r_par_web.cod_programa := 'PRT_BLO_AUT_TARJETAS';
      elsif :new.tip_operacion =
            fug_obt_pardinamico('DES_TIP_OPERACION', 5, v_modalidad) then
        r_par_web.cod_programa := 'PRT_DES_BLO_AUT_TARJETAS';
      end if;
    else
      r_par_web.cod_programa := 'PRT_BLO_AUT_TARJETAS';
    end if;
    --
    r_par_web.fec_procesamiento := pag_cal.FU_OBT_FEC_ACTUAL(5);
    r_par_web.usu_insercion     := substr(USER, 1, 10);
    r_par_web.fec_insercion     := sysdate;
    r_par_web.usu_modificacion  := substr(USER, 1, 10);
    r_par_web.fec_modificacion  := sysdate;
  
    insert into ge_par_web_servicios values r_par_web;
    
    --'updating' agregado por EGC - 20/08/2014 - para mejorar el proceso de desbloqueo.
  elsif updating then
    --Si la tarjeta tiene registrada una modalidad.
    if fl_obt_cod_modalidad(:new.nro_tarjeta) = 1 then
      --Si el Tipo de Operación corresponde a Desbloqueo.
      if :old.tip_operacion = fug_obt_pardinamico('DES_TIP_OPERACION', 5, v_modalidad) then
        if ((instr(:new.log_error, '-- 99 -') between 20 and 40) and
           nvl(:new.estado, 'P') = 'E') or nvl(:new.estado, 'P') = 'R' then
          -- Si ocurrió algún tipo de error, actualiza los estados.
          -- Actualiza el estado de la tarjeta a 'Bloqueado'.
          update ta_tarjetas a
             set a.cod_estado = '13'
           where a.nro_tarjeta = :old.nro_tarjeta;
          -- Actualiza el estado de la cuenta a 'Bloqueado'.
          update ta_cta_tarjetas t
             set t.estado = 'B'
           where t.nro_cuenta =
                 (select a.nro_cuenta
                    from ta_cta_tarjetas a, ta_tarjetas b
                   where a.nro_cuenta = b.nro_cuenta
                     and b.nro_tarjeta = :old.nro_tarjeta
                     and b.cod_persona = :old.cod_persona)
             and t.estado = 'N';
        
        end if;
      end if;
    end if;
  end if;
END ta_ta_blo_aut_tarjetas;
/

