create or replace function it.FUJ_VAL_CAJA(
      p_nro_operacion in varchar2,     -- Nro de operacion del Cajero
      p_nro_caja in varchar2)          -- Nro de Caja

return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;    -- Caja
  v_cod_modalidad number(3) := 91; -- Caja
  v_cod_usuario varchar2(10) := upper(user);  -- usuario es el que se conecta
  --
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_usu_responsable varchar2(10); -- usuario responsable de la caja
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  v_impresora     varchar2(200);
  -- Detalle de transacciones habilitadas para esta caja
  Cursor transacciones is
         Select ltrim(to_char(cod_transaccion,'9999')) || '#' ||
                descripcion transaccion
           from ge_transacciones c
          where c.cod_modulo = v_cod_modulo
            and c.cod_modalidad = v_cod_modalidad            
            and exists (select 0
                          from ba_usu_roles a,ge_tra_roles b
                         where a.cod_rol = b.cod_rol
                           and a.cod_usuario = v_cod_usuario
                           and b.cod_transaccion = c.cod_transaccion
                           and b.cod_modulo = c.cod_modulo
                           and b.cod_modalidad = c.cod_modalidad
                           --sólo las transacciones habilitadas en el horario actual o sin restricciones
                           and (to_char(sysdate,'hh24:mi:ss') between nvl(hor_inicio,to_char(sysdate,'hh24:mi:ss'))
                                                                  and nvl(hor_fin,to_char(sysdate,'hh24:mi:ss'))))
          order by c.cod_transaccion;
  v_det_transacciones varchar2(4000) := '';
  v_can_registros number(5) := 0;
  v_estado varchar2(01);
begin
  /* Procedimiento para validar el usuario y la caja */
  -- Verifico si existe el usuario en la tabla de usuarios
  v_msj_respuesta := FUE_OBT_NOM_USUARIO(v_cod_usuario);
  if v_msj_respuesta = 'Usuario no registrado en el Sistema' then
     v_cod_respuesta := '001';  -- tiene problemas
  end if;
  if pae_cnf.fu_obt_est_modulo(v_cod_modulo) <> 2  then
     -- modulo no esta habilitado
     v_cod_respuesta := '002';
     v_msj_respuesta := 'Modulo de Caja no esta habilitado para Operaciones';
  end if;
  if v_cod_respuesta = '000' then -- solo sino hubo errores
    -- Verifico la situacion del numero de caja
      Begin
         Select cod_usu_responsable, estado, impresora
           into v_cod_usu_responsable, v_estado, v_impresora
           from cj_cajas
           where nro_caja = to_number(p_nro_caja);
           -- verifico si el usuario actual es el responsable de esta caja
         if v_cod_usuario <> v_cod_usu_responsable then
            v_cod_respuesta := '001'; -- con error
            v_msj_respuesta := 'Usuario no puede acceder a esta Caja';
         end if;
         if v_estado <> 'A' then
            v_cod_respuesta := '001'; -- con error
            v_msj_respuesta := 'Caja no se encuentra activa';
         end if;
         if v_cod_respuesta = '000' then
           IF fue_obt_can_sesiones(user) > TO_NUMBER(NVL(fug_obt_pardinamico('CAN_SES_ACT_ITGF'),0))     
               and user <> 'IT' and fuj_obt_can_sesiones(user) = 0 THEN
               v_cod_respuesta := '001'; -- con error
          	   v_msj_respuesta := 'Usuario ya esta activo en el Sistema. No puede volver a ingresar!';
          END IF;
         end if;
      exception
         when no_data_found then
           v_cod_respuesta := '001'; -- con error
           v_msj_respuesta := 'Nro. de Caja no definido en el Sistema';
         when others then
           v_cod_respuesta := '001'; -- con error
           v_msj_respuesta := 'ERROR: en fue_obt_des_transaccion '||sqlerrm;
      end;
  end if;
  if v_cod_respuesta = '000' then
        -- Esta todo ok, se arman las transacciones ---
        v_can_registros := 0;
        for tr in transacciones loop
          v_det_transacciones := v_det_transacciones || '#' || tr.transaccion;
          v_can_registros := v_can_registros + 1;
        end loop;
        if v_can_registros = 0 then
           v_cod_respuesta := '004';
           v_msj_respuesta := 'Usuario no tiene permiso a ninguna transaccion';
        else
           v_det_transacciones := '2#' || -- 2=cantidad de columnas a desplegar
                                  ltrim(to_char(v_can_registros,'9999')) ||'#' || -- registros
                                  'Codigo%5#Descripcion%55' || -- titulos de las columnas
                                  v_det_transacciones;
        end if;
  end if;
  --si todo fue ok, actualizar el indicador de cajero presente S, indica que está conectado actualmente
  if v_cod_respuesta = '000' then
    --inicializar módulo
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
    update cj_cajas
       set presente = 'S'  --decode(presente,'N','S','N')
     where nro_caja = p_nro_caja;
  end if;
  -- armo finalmente los datos, si hubo o no errores
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta;
  if v_det_transacciones is not null then
    v_msj_salida := v_msj_salida ||'~'||
                    to_char(v_fec_actual,'ddmmyyyy')||'~'||  -- fecha
                    to_char(sysdate,'hh24:mi:ss')||'~'|| -- hora actual
                    nvl(v_impresora,'N')||'~'|| -- impresora actual
                    v_det_transacciones;
  end if;
  return(v_msj_salida);
end FUJ_VAL_CAJA;
/

