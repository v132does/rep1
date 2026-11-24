CREATE OR REPLACE PROCEDURE IT.PRG_INS_CTA_REACTIVADAS(p_nro_cuenta    in ge_cuentas.nro_cuenta%TYPE,
                                                    p_cod_modalidad in ge_cuentas.cod_modalidad%type,
                                                    p_estado        in ge_cuentas.estado%TYPE,
                                                    p_est_batch     in ge_cuentas.estado%TYPE,
                                                    p_sal_actual    in cc_cta_corrientes.sal_total%type,
                                                    p_sal_batch     in cc_cta_corrientes.sal_total%type,
                                                    p_env_mail      in varchar2 default 'N') IS

  v_fec_actual      ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_mto             ge_movimientos.monto%type;
  v_cod_tra_padre   ge_movimientos.cod_tra_padre%type;
  v_cod_mod_padre   ge_movimientos.cod_mod_padre%type;
  v_cod_mad_padre   ge_movimientos.cod_mad_padre%type;
  v_cod_tra_hijo    ge_movimientos.cod_transaccion%type;
  v_cod_moneda      ge_movimientos.cod_moneda%type;
  v_existe          varchar2(1) := 'N';
  v_env_mail        varchar2(1) := p_env_mail;
  v_des_transaccion varchar2(200);

BEGIN
  Begin
    Select a.monto --Verifica si ya existe el registro
      into v_mto
      from ge_cta_reactivadas a
     where a.fecha = v_fec_actual
       and a.cod_modalidad = p_cod_modalidad
       and a.nro_cuenta = p_nro_cuenta;
  
    if nvl(v_mto, -1) >= 0 then
      v_existe := 'S';
    end if;
  exception
    when others then
      v_existe := 'N';
  end;

  if v_existe = 'N' then  -- Si no existe, inserta
    Begin
      select m.monto,        -- Guarda datos del movimiento en las variables
             m.cod_tra_padre,
             m.cod_transaccion,
             m.cod_moneda,
             m.cod_mod_padre,
             m.cod_mad_padre
        into v_mto,
             v_cod_tra_padre,
             v_cod_tra_hijo,
             v_cod_moneda,
             v_cod_mod_padre,
             v_cod_mad_padre
        from ge_movimientos m
       where m.nro_cuenta = p_nro_cuenta
         and m.fecha = v_fec_actual
         and m.cod_transaccion <> 425
         and m.cod_modulo in (3, 4)
         and m.monto > 0
         and rownum = 1;
    exception
      when others then
        v_mto           := 0;
        v_cod_tra_padre := null;
        v_cod_tra_hijo  := null;
    end;
  
    if nvl(v_mto, 0) = 0 then -- Para actualización de montos.
      if p_sal_batch <> p_sal_actual then
        v_mto := abs(p_sal_batch - p_sal_actual);
      else
        v_mto := 0;
      end if;
    end if;
    
      insert into ge_cta_reactivadas
        (fecha,
         hora,
         cod_usuario,
         nro_cuenta,
         cod_tra_padre,
         cod_mod_padre,
         cod_mad_padre,
         cod_transaccion,
         cod_modulo,
         cod_modalidad,
         cod_moneda,
         monto,
         est_cuenta,
         est_batch,
         cod_ofi_origen,
         cod_usu_oficial,
         cod_persona,
         est_mov)
        (select a.fecha,
                a.hora,
                a.cod_usuario,
                a.nro_cuenta,
                nvl(v_cod_tra_padre, a.cod_tra_padre),
                a.cod_mod_padre,
                a.cod_mad_padre,
                nvl(v_cod_tra_hijo, a.cod_transaccion),
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_moneda,
                nvl(v_mto, 0),
                p_estado,
                P_est_batch,
                a.cod_ofi_origen,
                fug_obt_cod_usu_oficial(fug_obt_cli_principal(a.nro_cuenta,'P')),
                fug_obt_cli_principal(a.nro_cuenta, 'P'),
                a.estado
           from ge_movimientos a
          where a.nro_cuenta = p_nro_cuenta
            and a.fecha = v_fec_actual
            and ((a.cod_transaccion = 425 and  v_cod_tra_padre is null) or 
                  (a.cod_transaccion <> 425 and  v_cod_tra_padre is not null))
            and a.cod_modulo in (3, 4)
            and rownum = 1);

    if v_env_mail = 'S' then -- Si tiene monto mayor a 0, envia el mail.
      if v_mto > 0 then
        v_env_mail := 'S';
      else
        v_env_mail := 'N';
      end if;
    end if;
  
  elsif v_existe = 'S' and nvl(v_mto, 1) = 0 then  -- Si ya existe, actualiza el monto 
    Begin
      select m.monto,
             m.cod_tra_padre,
             m.cod_transaccion,
             m.cod_moneda,
             m.cod_mod_padre,
             m.cod_mad_padre
        into v_mto,
             v_cod_tra_padre,
             v_cod_tra_hijo,
             v_cod_moneda,
             v_cod_mod_padre,
             v_cod_mad_padre
        from ge_movimientos m
       where m.nro_cuenta = p_nro_cuenta
         and m.fecha = v_fec_actual
         and m.cod_transaccion <> 425
         and m.cod_modulo in (3, 4)
         and m.monto > 0
         and rownum = 1;
    exception
      when others then
        v_mto           := 0;
        v_cod_tra_padre := null;
        v_cod_tra_hijo  := null;
    end;
  
    update ge_cta_reactivadas t
       set t.monto           = v_mto,
           t.cod_tra_padre   = v_cod_tra_padre,
           t.cod_transaccion = v_cod_tra_hijo
     where t.fecha = v_fec_actual
       and t.nro_cuenta = p_nro_cuenta
       and t.cod_modalidad = p_cod_modalidad;
  
    if v_env_mail = 'S' then
      if v_mto > 0 then
        v_env_mail := 'S';
      else
        v_env_mail := 'N';
      end if;
    end if;
  end if;

  if v_env_mail = 'S' then
    Begin
      if v_cod_mod_padre is null then
        select m.monto,
               m.cod_tra_padre,
               m.cod_transaccion,
               m.cod_moneda,
               m.cod_mod_padre,
               m.cod_mad_padre
          into v_mto,
               v_cod_tra_padre,
               v_cod_tra_hijo,
               v_cod_moneda,
               v_cod_mod_padre,
               v_cod_mad_padre
          from ge_cta_reactivadas m
         where m.nro_cuenta = p_nro_cuenta
           and m.fecha = v_fec_actual;
      end if;
      
      if v_cod_tra_hijo <> 425 then
        v_des_transaccion := ' de '||fug_obt_des_transaccion(4, 41, v_cod_tra_hijo);
      else
        v_des_transaccion := null;
      end if;
      it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                   nvl(fug_obt_dir_mail_usu(fug_obt_cod_usu_oficial(fug_obt_cli_principal(p_nro_cuenta, 'P'))),fug_obt_pardinamico('CAM_MAR_DIR_EP')),
                   'Cuenta INACTIVA ha recibido movimientos',
                   'La cuenta ' || p_nro_cuenta || ' del cliente ' ||
                   fue_obt_nom_persona(fug_obt_cli_principal(p_nro_cuenta,'P'))||
                   ' que tiene el estado INACTIVA pasará a tener el estado NORMAL,'||CHR(13)||
                   'ya que se esta registrando el siguiente movimiento: ' ||CHR(13)||
                   fug_obt_des_transaccion(v_cod_mod_padre,
                                           v_cod_mad_padre,
                                           v_cod_tra_padre) ||v_des_transaccion|| ' en ' || v_cod_moneda || ' por: ' ||
                   v_mto || '.');
    Exception
      when others then --Si da error al enviar mail, que deje seguir la operativa
        null;
    END;
  end if;

exception
  when others then
    PRG_INS_LOG_ERRORES('PRG_INS_CTA_REACTIVADAS', sqlerrm, 'p_nro_cuenta', p_nro_cuenta, 'p_cod_modalidad', p_cod_modalidad );
END;
/

