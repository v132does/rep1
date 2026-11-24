CREATE OR REPLACE FUNCTION IT.FUJ_VAL_IMPORTE
   (p_tipo       in varchar2,  -- Tipo de operacion: D-Debito o C-credito
    p_tip_monto  in varchar2,  -- tipo de monto E-efectivo, C-Cheq.ntro.bco O-Cheq.otr.bcos
    p_cod_moneda in varchar2,  -- moneda de la operacion
    p_importe    in number,    -- importe de la operacion
    p_cod_tra_padre in number default null,
    p_nro_cuenta in varchar2 default null) -- Transaccion padre
  return varchar2 is
  --
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  v_mto_max_permitido number(18,2);  -- monto maximo permitido
  --
  --v_mon_local varchar2(03) := pag_gen.fu_obt_mon_local;  -- ojo!!!, se debe cambiar
  v_hor_camara varchar2(10) := ltrim(rtrim(fue_obt_val_max_refcodes('HOR_COR_CAMARA', '1')));
  -- mensaje de salida ---
  v_salida varchar2(200)  := NULL;
  v_mto_che_ret_cero_ml cc_che_remitidos.monto%type;
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(9);
  v_fila varchar2(100);
begin
  if p_importe is null then
     v_salida := 'ERROR: Ingresar importe';
  elsif p_importe < 0 then
     v_salida := 'ERROR: Importe no puede ser negativo';
  --elsif p_cod_moneda = v_mon_local and  p_importe <> trunc(p_importe) then
  elsif p_cod_moneda = 'GS'  and  p_importe <> trunc(p_importe) then
     v_salida := 'ERROR. Importe no debe tener decimales';
  else
     v_mto_che_ret_cero_ml := fug_obt_pardinamico('MTO_CHE_RET_CERO',NULL,NULL,p_cod_moneda);
     if p_tip_monto = 'E' then -- si es efectivo
        if p_tipo = 'C' then -- egreso a la caja, verifico alzada del usuario
           -- obtengo la maxima alzada para este cajero
           v_mto_max_permitido := fuj_obt_max_limite(v_cod_usuario, p_cod_moneda, p_cod_tra_padre);
           if nvl(v_mto_max_permitido,0) < p_importe then
              begin
                 v_fila := null;
                 select rowid
                   into v_fila
                   from ge_autorizaciones a
                  where a.cod_usu_utilizador is null
                    and a.fec_utilizacion is null
                    and a.cod_moneda = p_cod_moneda
                    and a.fecha = v_fec_actual
                    and a.valor = p_importe
                    and a.cod_mod_padre = 9
                    and a.cod_usuario = user
                    and nvl(a.nro_cuenta,'x') = nvl(p_nro_cuenta,nvl(a.nro_cuenta,'x'))
                    and (case when a.cod_tra_padre = 241 then 245
                              when a.cod_tra_padre = 242 then 245
                              when a.cod_tra_padre = 246 then 245
                              else a.cod_tra_padre end) = p_cod_tra_padre
                    and rownum = 1; --para que tome una, x si hay varias autorizaciones
                 --las autorizaciones de operaciones de cambios son generales
                 -- actualizo la autorizacion como utilizada
                 update ge_autorizaciones
                    set cod_usu_utilizador = user,
                        fec_utilizacion = v_fec_actual,
                        hor_utilizacion = to_char(sysdate,'HH24:MI:SS')
                  where rowid = v_fila;
                 if sql%notfound then
                    raise no_data_found;
                 end if;
              exception
                 when no_data_found then
                    if p_nro_cuenta is null then
                       v_salida := 'Cajero no habilitado para operar con este Monto en '||p_cod_moneda||'. Solicite Autorizacion';
                    else
                       v_salida := 'Cajero no habilitado para operar con este Monto para la Cuenta '||p_nro_cuenta||'. Solicite Autorizacion';
                    end if;
                 when others then
                    v_salida := 'Al leer Autorizacion '||sqlerrm;
              end;
           end if;
       end if;
     elsif p_tip_monto = 'O' then -- si es cheque 0 Hs
        if p_tipo = 'D' then -- ingreso a la caja
           -----------------------------------------------------
           --Agregado Proyecto Truncamiento CORETRCH-1--
           --Control para Retencion 1 = 0 hs--
           -----------------------------------------------------
           if p_importe > 0 then               
                 --//--Para Monto--//--
                 if (nvl(p_importe,0) < nvl(v_mto_che_ret_cero_ml,0)) then              
                    v_salida := 'ERROR. Importe para Retencion 1 no puede ser menor a '||p_cod_moneda||' '||trim(to_char(v_mto_che_ret_cero_ml,'999,999,999,990'));      
                 elsif to_char(sysdate,'HH24:MI') >= v_hor_camara then -- por encima del primer corte
                    begin
                       v_fila := null;
                       select rowid
                         into v_fila
                         from ge_autorizaciones a
                        where a.cod_usu_utilizador is null
                          and a.fec_utilizacion is null
                          and a.cod_moneda = p_cod_moneda
                          and a.fecha = v_fec_actual
                          and a.valor = p_importe
                          and a.cod_mod_padre = 9
                          and a.cod_usuario = user
                          and (a.nro_cuenta = p_nro_cuenta or (p_nro_cuenta is null and a.nro_cuenta is null))
                          and a.cod_tra_padre = p_cod_tra_padre
                          and rownum = 1; --para que tome una, x si hay varias autorizaciones
                       --las autorizaciones de operaciones de cambios son generales
                       -- actualizo la autorizacion como utilizada
                       update ge_autorizaciones
                          set cod_usu_utilizador = user,
                              fec_utilizacion = v_fec_actual,
                              hor_utilizacion = to_char(sysdate,'HH24:MI:SS')
                        where rowid = v_fila;
                       if sql%notfound then
                          raise no_data_found;
                       end if;
                    exception
                       when no_data_found then
                          if p_nro_cuenta is null then
                             v_salida := 'Cajero no habilitado para ingresar Cheques C/Otros Bcos Ret.1. Solicite Autorizacion.';
                          else
                             v_salida := 'Cajero no habilitado para ingresar Cheques C/Otros Bcos.Ret.1. a la Cta '||p_nro_cuenta||'. Solicite Autorizacion';
                          end if;
                       when others then
                          v_salida := 'Al leer Autorizacion '||sqlerrm;
                    end;
                 end if;
           end if;           
        end if;
     elsif p_tip_monto = 'T' then -- cheque 24hs
        if p_tipo = 'D' then
           -----------------------------------------------------
           --Agregado Proyecto Truncamiento CORETRCH-1--
           --Control para Retencion 2 = 24 hs--
           -----------------------------------------------------
           --//--Para control de horacio, cualquiera sea al monto--//--
           if ((to_char(sysdate,'HH24:MI') >= v_hor_camara) and (p_importe > 0)) then                       
              --v_salida := 'ERROR. Importe para Retencion 2 debe regitrarse antes de las '||v_hor_camara;
              begin
                 v_fila := null;
                 select rowid
                   into v_fila
                   from ge_autorizaciones a
                  where a.cod_usu_utilizador is null
                    and a.fec_utilizacion is null
                    and a.cod_moneda = p_cod_moneda
                    and a.fecha = v_fec_actual
                    and a.valor = p_importe
                    and a.cod_mod_padre = 9
                    and a.cod_usuario = user
                    and (a.nro_cuenta = p_nro_cuenta or (p_nro_cuenta is null and a.nro_cuenta is null))
                    and a.cod_tra_padre = p_cod_tra_padre
                    and rownum = 1; --para que tome una, x si hay varias autorizaciones
                 --las autorizaciones de operaciones de cambios son generales
                 -- actualizo la autorizacion como utilizada
                 update ge_autorizaciones
                    set cod_usu_utilizador = user,
                        fec_utilizacion = v_fec_actual,
                        hor_utilizacion = to_char(sysdate,'HH24:MI:SS')
                  where rowid = v_fila;
                 if sql%notfound then
                    raise no_data_found;
                 end if;
              exception
                 when no_data_found then
                    if p_nro_cuenta is null then
                       v_salida := 'Cajero no habilitado para ingresar Cheques C/Otros Bcos Ret.2. Solicite Autorizacion';
                    else
                       v_salida := 'Cajero no habilitado para ingresar Cheques C/Otros Bcos.Ret.2. a la Cta '||p_nro_cuenta||'. Solicite Autorizacion';
                    end if;
                 when others then
                    v_salida := 'Al leer Autorizacion '||sqlerrm;
              end;
           end if;              
           ------------------------------------------------------
           /*if to_char(sysdate,'HH24:MI') < v_hor_camara and p_cod_moneda = v_mon_local and p_importe > 0 then
              v_salida := 'No puede ingresar Ret. 2 en el horario actual.';
           end if;*/
        end if;   
     elsif p_tip_monto = 'S' then -- cheque 48hs
        if p_tipo = 'D' then
           -----------------------------------------------------
           --Agregado Proyecto Truncamiento CORETRCH-1--
           --Control para Retencion 3 = 48 hs--
           -----------------------------------------------------
           --//--Para Horario--//--
           if ((to_char(sysdate,'HH24:MI') <= v_hor_camara) and (p_importe > 0)) then
              v_salida := 'ERROR. Importe para Retencion 3 debe registrarse después de las '||v_hor_camara;
           end if;              
           ------------------------------------------------------
           /*if p_cod_moneda = v_mon_local and p_importe > 0 then
              v_salida := 'No puede ingresar un importe con Retención 3 para Cheques en Moneda Local.';
           end if;*/
        end if;
     end if;
  end if;
  -- Retorno el mensaje de error
  return(v_salida);
exception
   when others then
      return ('ERROR: en FUJ_VAL_OPERACION ' ||sqlerrm);
end FUJ_VAL_IMPORTE;
/

