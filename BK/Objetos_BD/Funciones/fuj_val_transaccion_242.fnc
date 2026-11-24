create or replace function it.FUJ_VAL_TRANSACCION_242(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2)      -- nro de operacion de cambios
return LONG is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 242;    -- transaccion de venta
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  v_nom_cliente       varchar2(200) := null;
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 9;        -- cantidad de campos
  v_det_campos    varchar2(4000) :=      -- valores devueltos por defecto
           '[' || 'ENT_CONCEPTO' ||'~ ]' || 
           '[' || 'ENT_MONEDA' ||'~ ]' ||
           '[' || 'ENT_MONTO' ||'~ ]' ||  
           '[' || 'REC_CONCEPTO1' ||'~ ]' || 
           '[' || 'REC_MONEDA1' ||'~ ]' ||
           '[' || 'REC_MONTO1' ||'~ ]' ||
           '[' || 'REC_CONCEPTO2' ||'~ ]' || 
           '[' || 'REC_MONEDA2' ||'~ ]' ||
           '[' || 'REC_MONTO2' ||'~ ]' ||
           '[' || 'REC_CONCEPTO3' ||'~ ]' || 
           '[' || 'REC_MONEDA3' ||'~ ]' ||
           '[' || 'REC_MONTO3' ||'~ ]';

  -- variables
  v_ent_concepto varchar2(60) := null;
  v_ent_moneda   varchar2(3)  := null;
  v_ent_monto    number(18,2) := null;   
  v_rec_concepto1 varchar2(60) := null;
  v_rec_moneda1   varchar2(3)  := null;
  v_rec_monto1    number(18,2) := null;  
  v_rec_concepto2 varchar2(60) := null;
  v_rec_moneda2   varchar2(3)  := null;
  v_rec_monto2    number(18,2) := null;  
  v_rec_concepto3 varchar2(60) := null;
  v_rec_moneda3   varchar2(3)  := null;
  v_rec_monto3    number(18,2) := null;  
  
  v_existe       varchar2(1)  := 'N';
  -- Cursor de movimientos de la operacion
  cursor movimientos is
  Select nro_secuencia,cod_moneda, monto, estado, 
        decode(a.cod_transaccion,606,b.descripcion||' NTRO. BANCO',
           decode(b.tip_valor,'C',b.descripcion||' OTROS BANCOS',b.descripcion)) descripcion, 
        b.tip_valor, a.cod_ofi_origen,a.cod_tra_padre
    from lc_tip_operaciones b, ge_movimientos a
   where nro_documento = to_number(p_nro_boleta)
     and estado = 'J'
     and reversado = 'N'
     and b.caja = 'S' -- solo si pasa por caja
     and b.cod_tip_operacion = a.cod_tip_ope_cambio
     and a.cod_mad_padre = 72  -- venta
   order by nro_secuencia;   
  mv movimientos%rowtype;   
begin
 -- Valido la boleta
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Cambios.';
 else  
    for mv in movimientos loop
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
          v_msj_respuesta := 'Realice la Apertura de Caja previamente';
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
       if mv.cod_tra_padre = 265 then
         Begin
             Select 'CREDITO EN CTA. '||a.nro_cuenta||' M.E.'              
               into v_ent_concepto
               from lc_tip_operaciones b, ge_movimientos a
              where nro_documento = to_number(p_nro_boleta)
                and estado = 'J'
                and reversado = 'N'
                and b.cod_tip_operacion = a.cod_tip_ope_cambio
                and a.cod_mad_padre = 72 -- venta
                and a.nro_secuencia = 1
                and b.cod_tip_operacion = 30;
              Exception 
                 When others then 
                    v_ent_concepto  := null;                   
           End;     
       end if; 
       -- Cargo los datos a desplegar 
       if mv.nro_secuencia = 1 then
          -- datos a entregar
          v_ent_concepto := mv.descripcion;
          v_ent_moneda   := mv.cod_moneda;
          v_ent_monto    := mv.monto;
       else
          -- datos a recibir
          if v_rec_concepto1 is null then
            v_rec_concepto1 := mv.descripcion;
            v_rec_moneda1   := mv.cod_moneda;
            v_rec_monto1    := mv.monto;
          elsif v_rec_concepto2 is null then
            v_rec_concepto2 := mv.descripcion;
            v_rec_moneda2   := mv.cod_moneda;
            v_rec_monto2    := mv.monto;            
          elsif v_rec_concepto3 is null then
            v_rec_concepto3 := mv.descripcion;
            v_rec_moneda3   := mv.cod_moneda;
            v_rec_monto3    := mv.monto;    
          else
            v_cod_respuesta := '003';
            v_msj_respuesta := 'Operacion invalida. Verifique';
          end if;  
        end if;
     end loop;
     if v_existe = 'N' and v_cod_respuesta = '000' then
         v_cod_respuesta := '007'; -- error
         v_msj_respuesta := 'Operacion ya fue procesada o no corresponde.';
     end if;
     if v_cod_respuesta = '000' then
       begin
          select decode(nvl(nro_documento2,0),0,concepto,fue_obt_nom_persona(nro_documento2)) nom_persona
            into v_nom_cliente
            from ge_movimientos
           where nro_documento = to_number(p_nro_boleta)
             and reversado = 'N'
             and cod_mod_padre = 7
             and cod_transaccion = 760;
       exception
         when others then
            v_nom_cliente := null;
                 
       end;
     end if;
     -- cargo los datos a desplegar si no hay errores
     v_det_campos := 
           '[' || 'ENT_CONCEPTO' ||'~'||v_ent_concepto||']' || 
           '[' || 'ENT_MONEDA' ||'~'||v_ent_moneda||']' || 
           '[' || 'ENT_MONTO' ||'~'||v_ent_monto||']' ||        
           '[' || 'REC_CONCEPTO1' ||'~'||v_rec_concepto1||']' || 
           '[' || 'REC_MONEDA1' ||'~'||v_rec_moneda1||']' || 
           '[' || 'REC_MONTO1' ||'~'||v_rec_monto1||']' || 
           '[' || 'REC_CONCEPTO2' ||'~'||v_rec_concepto2||']' || 
           '[' || 'REC_MONEDA2' ||'~'||v_rec_moneda2||']' || 
           '[' || 'REC_MONTO2' ||'~'||v_rec_monto2||']' || 
           '[' || 'REC_CONCEPTO3' ||'~'||v_rec_concepto3||']' || 
           '[' || 'REC_MONEDA3' ||'~'||v_rec_moneda3||']' || 
           '[' || 'REC_MONTO3' ||'~'||v_rec_monto3||']'|| 
            '[' || 'NOMBRE' ||'~'||v_nom_cliente||']'; 

  end if;         
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_242;
/

