create or replace function it.FUJ_VAL_TRANSACCION_201(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_moneda in varchar2)      -- Codigo de moneda
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 201;        -- Transaccion
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'OK';     -- MENSAJE sin errores
  v_est_modulo    ba_modulos.estado%TYPE;
  -- detalle de campos. Por defecto van los campos en blanco
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=       -- valor por defecto
              '[' || 'MTO_APERTURA'    ||'~ ]' || 
              '[' || 'MTO_CHEQUES'   ||'~ ]';
begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := v_cod_modulo;
  v_est_modulo := PAE_CNF.FU_OBT_EST_MODULO(v_cod_modulo); --Estado Modulo
  
 -- Valido la moneda 
 if p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda.';
 else 
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;   
 if v_cod_respuesta = '000' then -- no hubo errores
    --Validar estado del modulo
    IF v_est_modulo <> 2 THEN
      v_cod_respuesta := '004'; -- error
      v_msj_respuesta := 'Cierre Operativo del dia anterior aun no ha finalizado. No se puede aperturar Caja.';
    END IF;
    -- Obtengo los datos de la caja ---------------------------------------
    prj_obt_datos_caja(p_nro_caja,
                       p_cod_moneda,
                       v_cod_oficina,
                       v_fec_caja,
                       v_estado,
                       v_sal_actual,
                       v_sal_cheques);
    if v_estado = -1 then
        v_cod_respuesta := '006'; -- error, no existe registro de caja
        v_msj_respuesta := 'Caja inexistente!!';  
     elsif v_estado in (1,3,4) then  -- error, la caja ya esta abierta
       v_cod_respuesta := '003'; -- error
       v_msj_respuesta := 'Caja no puede ser abierta porque se halla ';         
       if v_estado = 1 then
          v_msj_respuesta := v_msj_respuesta || ' abierta.';
       elsif v_estado = 3 then
          v_msj_respuesta := v_msj_respuesta || ' re-abierta.';
       elsif v_estado = 4 then
          v_msj_respuesta := v_msj_respuesta || ' arqueo.';
       end if;
    elsif v_estado = 2 then -- caja cerrada
       v_det_campos := '[' || 'MTO_APERTURA'    ||'~'||ltrim(to_char(v_sal_actual))|| ']' ||
                       '[' || 'MTO_CHEQUES'    ||'~'||ltrim(to_char(v_sal_cheques))|| ']';
    end if;
 end if; 

 /* armo finalmente el mensaje de respuesta */ 
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
                  
  return(v_msj_salida);
exception
 when others then 
     /* si hubo problemas, armo finalmente el mensaje de respuesta */    
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm||'~'||
                     ltrim(to_char(v_can_campos,'000'))||'~'||
                     v_det_campos;
     return(v_msj_salida);
end FUJ_VAL_TRANSACCION_201;
/
