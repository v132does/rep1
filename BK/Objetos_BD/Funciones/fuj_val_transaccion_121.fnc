create or replace function it.FUJ_VAL_TRANSACCION_121(
      p_nro_operacion   in varchar2,                            -- Nro de referencia de la operacion
      p_nro_caja        in varchar2,                            -- Nro de Caja
      p_cod_tra_padre   in varchar2,                            -- Codigo de transaccion
      p_hora            in varchar2 default null)               -- hora de la transaccion a reimprimir
return long is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo          number(3)          := 9;                -- Caja
  v_cod_modalidad       number(3)          := 91;               -- Caja
  v_cod_transaccion     number(4)          := 121;              -- cod de transaccion
  v_cod_usuario         varchar2(10)       := upper(user);--('PY00666');      --usuario
  --
  v_cod_oficina         number(3);                              -- oficina de la caja

  v_estado              number(1);                              -- estado de la caja
  v_fec_caja            date;                                   -- fecha de la caja
  v_sal_actual          number(18,2);                           -- saldo actual de la caja en efectivo
  v_sal_cheques         number(18,2);                           -- saldo actual de la caja en cheques
  --
  v_msj_salida          long;                          -- mensaje final retornado
  v_cod_respuesta       varchar2(03)       := '000';            -- sin errores
  v_msj_respuesta       varchar2(1000)     := 'OK';             -- sin errores
  v_can_campos          number(3)          := 0;                -- cantidad de campos
  v_det_campos          varchar2(8000)     := null;
  -- Contenedor de la lista de valores a devolver
  v_val_posibles        varchar2(3000)     := null;
  -- Datos del movimiento
  --v_nro_documento varchar2(10); *** Modificado por JCLG ***
  v_nro_documento       number(15);
  v_nro_cuenta          varchar2(15);
  v_denominacion        varchar2(100);
  v_cod_moneda          varchar2(3);
  v_monto               varchar2(18);
function lf_val_imp_ope_riesgo return varchar is
 v_tra_hab_impresion varchar2(1) := 'N';
begin
 begin
   
 select est_operacion
  into v_tra_hab_impresion  
from(
 select 'S' est_operacion
   from ge_par_ope_riesgos r
  where r.cod_modulo = v_cod_modulo
    and r.cod_modalidad = v_cod_modalidad
    and r.cod_transaccion = to_number(p_cod_tra_padre)
    and exists (select distinct 1
           from ge_mov_autorizaciones u
          where u.cod_mod_padre = r.cod_modulo
            and u.cod_mad_padre = r.cod_modalidad
            and u.cod_tra_padre = r.cod_transaccion
            and u.cod_usuario = v_cod_usuario
           -- and u.hora = p_hora
            and u.estado = 'A')
  union
  select 'R' est_operacion
   from ge_par_ope_riesgos r
  where r.cod_modulo = v_cod_modulo
    and r.cod_modalidad = v_cod_modalidad
    and r.cod_transaccion = to_number(p_cod_tra_padre)
    and exists (select distinct 1
           from ge_mov_autorizaciones u
          where u.cod_mod_padre = r.cod_modulo
            and u.cod_mad_padre = r.cod_modalidad
            and u.cod_tra_padre = r.cod_transaccion
            and u.cod_usuario = v_cod_usuario
           -- and u.hora = p_hora
            and u.estado = 'R')
   union 
   select 'P' est_operacion
     from ge_par_ope_riesgos r
    where r.cod_modulo = v_cod_modulo
      and r.cod_modalidad = v_cod_modalidad
      and r.cod_transaccion = to_number(p_cod_tra_padre)
      and exists (select distinct 1
             from ge_mov_autorizaciones u
            where u.cod_mod_padre = r.cod_modulo
              and u.cod_mad_padre = r.cod_modalidad
              and u.cod_tra_padre = r.cod_transaccion
              and u.cod_usuario = v_cod_usuario
             -- and u.hora = p_hora
              and u.estado = 'S')
    );     
 exception
   when no_data_found then
     v_tra_hab_impresion := 'N';
     return v_tra_hab_impresion;
   when others then
     v_tra_hab_impresion := 'N';
     return v_tra_hab_impresion;
 end;
 
 return v_tra_hab_impresion;
exception
 when others then
   v_tra_hab_impresion := 'N';
   return v_tra_hab_impresion;

end lf_val_imp_ope_riesgo;  
  
begin
   if to_number(p_cod_tra_padre) is  null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese la Transacción a imprimir.';
   elsif lf_val_imp_ope_riesgo  = 'P' then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Operación Pendiente de Aprobación, no se puede imprimir.';
   elsif lf_val_imp_ope_riesgo  = 'R' then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Operación Rechazada, no se puede imprimir.';    
  /*  elsif lf_val_imp_ope_riesgo  = 'N' then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Operación no es de Riesgo, no se puede imprimir.';
  elsif p_hora is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese la hora de la Operación. Presione F9 para ver Lista de Operaciones';*/
   end if;   
  if p_hora is null then
    -- Obtengo el select de la lista de valores para la Hora
    v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'HORA');
    -- reemplazo el codigo de transaccion en el select
    v_val_posibles := replace(v_val_posibles,'&COD_TRANS',p_cod_tra_padre);
    -- reemplazo el nro de caja en el select
    v_val_posibles := replace(v_val_posibles,'&NRO_CAJA',p_nro_caja);
    /* se devuelve los valores posibles para el codigo de transaccion a imprimir
    Datos a devolver por campo: [Nombre_campo~Valor_defecto~Valores_Posibles] */
    begin
      v_can_campos := 1;
      Select '[' || 'DES_TRA_PADRE' ||'~'||descripcion|| ']'
        into v_det_campos
        from ge_transacciones
       where cod_modulo = v_cod_modulo
         and cod_modalidad = v_cod_modalidad
         and cod_transaccion = to_number(p_cod_tra_padre);

    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'No existe Transaccion definida en el Sistema';
        v_det_campos := '[' || 'DES_TRA_PADRE' ||'~'||' '|| ']';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
        v_det_campos := '[' || 'DES_TRA_PADRE' ||'~'||' '|| ']';
    end;
    if v_cod_respuesta = '000' then
      v_det_campos := v_det_campos ||
                      '[' ||
                      'HORA~X~'||
                      fuj_pro_val_posibles(v_val_posibles) ||
                      ']';
      v_can_campos := v_can_campos + 1;
    end if;
  
  else
    -- obtengo datos de la operacion ------------------------------------
    begin
      v_can_campos := 5;
      select b.nro_documento, b.nro_cuenta, a.denominacion, b.cod_moneda,
             b.monto
        into v_nro_documento, v_nro_cuenta, v_denominacion, v_cod_moneda,
             v_monto
        from ge_cuentas a, cj_movimientos b, ge_par_ope_riesgos r
       where a.nro_cuenta(+) = b.nro_cuenta
         and b.nro_caja = to_number(p_nro_caja)
         and b.hora = p_hora
         and b.cod_tra_padre = to_number(p_cod_tra_padre)
         and b.cod_tra_padre = r.cod_transaccion
         and b.cod_mod_padre = r.cod_modulo
         and b.cod_mad_padre = r.cod_modalidad
        -- and b.cod_moneda = r.cod_moneda         
         and b.estado = 'N' -- normal
         and b.nro_secuencia = 1
         and b.cod_usuario = v_cod_usuario
         and nvl(b.can_impresion,0) = 0;

         
      -- Obtengo los datos de la caja ---------------------------------------
      prj_obt_datos_caja(p_nro_caja,
                         v_cod_moneda,
                         v_cod_oficina,
                         v_fec_caja,
                         v_estado,
                         v_sal_actual,
                         v_sal_cheques);
      if v_estado in (0,2) then  -- error, la caja no esta abierta
         v_cod_respuesta := '003'; -- error
         v_msj_respuesta := 'Caja aun no fue abierta en esta Moneda';
      elsif v_estado in (1,3,4) then -- caja
         v_det_campos := '[' || 'NRO_DOCUMENTO' ||'~'||to_char(v_nro_documento)|| ']' ||
                         '[' || 'NRO_CUENTA' ||'~'||v_nro_cuenta|| ']' ||
                         '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                         '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']' ||
                         '[' || 'MONTO' ||'~'||v_monto|| ']';
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'No existe movimiento registrado en esta Caja';
        v_det_campos := '[' || 'NRO_DOCUMENTO' ||'~ ]'||
                        '[' || 'NRO_CUENTA' ||'~ ]' ||
                        '[' || 'DES_CUENTA' ||'~ ]' ||
                        '[' || 'COD_MONEDA' ||'~ ]' ||
                        '[' || 'MONTO' ||'~ ]';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
        v_det_campos := '[' || 'NRO_DOCUMENTO' ||'~ ]'||
                        '[' || 'NRO_CUENTA' ||'~ ]' ||
                        '[' || 'DES_CUENTA' ||'~ ]' ||
                        '[' || 'COD_MONEDA' ||'~ ]' ||
                        '[' || 'MONTO' ||'~ ]';
    end;

  end if;
 /* falta armar el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_121;
/

