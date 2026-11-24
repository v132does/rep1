create or replace function it.FUJ_VAL_TRANSACCION_243(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2)      -- nro de operacion de cambios
return long is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 243;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida    long;        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta long := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 6;        -- cantidad de campos
  v_det_campos    varchar2(4000) :=      -- valores devueltos por defecto
           '[' || 'REC_CONCEPTO' ||'~ ]' || 
           '[' || 'REC_MONEDA' ||'~ ]' ||
           '[' || 'REC_MONTO' ||'~ ]' ||
           '[' || 'ENT_CONCEPTO' ||'~ ]' || 
           '[' || 'ENT_MONEDA' ||'~ ]' ||
           '[' || 'ENT_MONTO' ||'~ ]' ;  
  -- variables
  v_rec_concepto varchar2(60) := null;
  v_rec_moneda   varchar2(3)  := null;
  v_rec_monto    number(18,2) := null;  
  v_ent_concepto varchar2(60) := null;
  v_ent_moneda   varchar2(3)  := null;
  v_ent_monto    number(18,2) := null;   
  v_existe       varchar2(1)  := 'N';
  v_nom_cliente  varchar2(200) := null;
  v_nro_documento varchar2(20) := null; 
  v_equ_local    number(18,2) := null;  
  -- Cursor de movimientos de la operacion
  cursor movimientos is
  Select nro_secuencia,cod_moneda, monto, estado, b.descripcion, b.tip_valor,
         a.cod_ofi_origen, mto_equ_local, caja
    from lc_tip_operaciones b, ge_movimientos a
   where nro_documento = to_number(p_nro_boleta)
     and estado = 'J'
     and reversado = 'N'
     and (b.caja = 'S' or a.cod_transaccion <> 760)--solo si pasa por caja,puede pasar 1solo
     and b.caja = 'S' -- solo si pasa por caja
     and b.cod_tip_operacion = a.cod_tip_ope_cambio
     and a.cod_mad_padre in (73)  -- arb
   order by nro_secuencia;   
  mv movimientos%rowtype;   
begin
 -- Valido la boleta
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Cambios.';
 else  
    for mv in movimientos loop
       --solo si pasa x caja, hace lo pertinente
       if mv.caja ='S' then
          v_existe := 'S';
          -- Obtengo los datos de la caja en la moneda   ----------------------------
          prj_obt_datos_caja(p_nro_caja,
                             mv.cod_moneda,
                             v_cod_oficina,
                             v_fec_caja,
                             v_estado,
                             v_sal_actual,
                             v_sal_cheques);
          if v_estado = -1 then
             v_cod_respuesta := '006'; -- error, no existe registro de caja
             v_msj_respuesta := 'Caja inexistente!!';         
          elsif v_estado in (0,2) then
             v_cod_respuesta := '004'; -- error
             v_msj_respuesta := 'Caja no esta habilitada en '||mv.cod_moneda||' para esta Operacion';
          elsif v_fec_caja <> v_fec_actual then
             v_cod_respuesta := '005'; -- error
             v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';                
          --elsif v_cod_oficina <> mv.cod_ofi_origen then
          --   v_cod_respuesta := '006'; -- error
          --   v_msj_respuesta := 'Operacion no corresponde a esta Oficina';                
          end if;
          if v_cod_respuesta <> '000' then 
             exit; -- sale cuando ya hay error
          end if;   
       end if;--pasa caja
       -- Cargo los datos a desplegar 
       if mv.nro_secuencia = 1 then
          -- datos a recibir
          v_rec_concepto := mv.descripcion;
          v_rec_moneda   := mv.cod_moneda;
          v_rec_monto    := mv.monto;
       else
          -- datos a entregar
          if v_ent_concepto is null then
            v_ent_concepto := mv.descripcion;
            v_ent_moneda   := mv.cod_moneda;
            v_ent_monto    := mv.monto;
          else
            v_cod_respuesta := '003';
            v_msj_respuesta := 'Operacion invalida. Verifique';
          end if;  
        end if;
        v_equ_local    := mv.mto_equ_local;
     end loop;
     if v_existe = 'N' and v_cod_respuesta = '000' then
         v_cod_respuesta := '007'; -- error
         v_msj_respuesta := 'Operacion ya fue procesada o no corresponde.';
     end if;
     if v_cod_respuesta = '000' then
       begin
          select decode(nvl(nro_documento2,0),0,concepto,fue_obt_nom_persona(nro_documento2)) nom_persona,
                 referencia nro_documento
            into v_nom_cliente, v_nro_documento
            from ge_movimientos
           where nro_documento = to_number(p_nro_boleta)
             and reversado = 'N'
             and cod_mod_padre = 7
             and cod_transaccion = 760;
       exception
         when others then
            v_nom_cliente := null;
            v_nro_documento := null;      
       end;
     end if;

     -- cargo los datos a desplegar si no hay errores
     v_det_campos :=    
           '[' || 'REC_CONCEPTO' ||'~'||v_rec_concepto||']' || 
           '[' || 'REC_MONEDA' ||'~'||v_rec_moneda||']' || 
           '[' || 'REC_MONTO' ||'~'||v_rec_monto||']' || 
           '[' || 'ENT_CONCEPTO' ||'~'||v_ent_concepto||']' || 
           '[' || 'ENT_MONEDA' ||'~'||v_ent_moneda||']' || 
           '[' || 'ENT_MONTO' ||'~'||v_ent_monto||']'|| 
           '[' || 'EQU_LOCAL' ||'~'||v_equ_local||']'|| 
           '[' || 'NOMBRE' ||'~'||v_nom_cliente||']';
  end if;         
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_243;
/

