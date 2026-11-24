create or replace function it.FUJ_VAL_TRANSACCION_247(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2)      -- nro de operacion de cambios
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 247;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 6;        -- cantidad de campos
  v_det_campos    varchar2(4000) :=      -- valores devueltos por defecto
           '[' || 'COD_TRANSACCION' ||'~ ]' || 
           '[' || 'DES_TRANSACCION' ||'~ ]' ||
           '[' || 'OBSERVACION' ||'~ ]' ||
           '[' || 'TOTAL' ||'~ ]' ||
           '[' || 'COD_MONEDA' ||'~ ]' || 
           '[' || 'EFECTIVO' ||'~ ]' ||
           '[' || 'CHEQUE' ||'~ ]' ||
           '[' || 'OTROS_CHE' ||'~ ]'  ;  
  -- variables
  v_cod_tra         number(4)  := null;
  v_des_transaccion varchar2(60) := null;
  v_observacion     varchar2(100) := null;
  v_cod_moneda      varchar2(3)  := null;
  v_total           number(18,2) := null;            
  v_efectivo        number(18,2) := null;   
  v_cheque          number(18,2) := null;   
  v_otro_cheque     number(18,2) := null;   
  v_existe          varchar2(1) := 'N';
  -- Cursor de movimientos de la operacion
  cursor movimientos is
  Select nro_secuencia,nro_documento, t.descripcion ,hora,cod_moneda,
        monto,a.cod_transaccion,concepto
  from ge_movimientos a,
       ge_transacciones t
  where estado = 'J'
     and a.nro_documento = to_number(p_nro_boleta)
     and reversado = 'N'
     and a.cod_transaccion = t.cod_transaccion
     and a.cod_modulo = t.cod_modulo
     and a.cod_modalidad = t.cod_modalidad
     --DYDMR-2548 ITGF - Retomar Mov Pend p/ Caja - Cobro de Cargos - SC 21582
     --and cod_tra_padre in (150,323,324,536,309,305,322,532)
     and (nvl(FUP_EXI_GRU_TRANSAC(31, a.cod_tra_padre, 4, 41), 'N') = 'S'
         or exists (select 1
                        from ge_transacciones t
                       where t.cod_transaccion = a.cod_tra_padre
                         and t.cod_modulo = a.cod_mod_padre
                         and t.cod_modalidad = a.cod_mad_padre
                         and t.cod_tasa is not null
                         and t.rutina1 is null
                         and nvl(t.afecta,'N') = 'N'
                         and fug_obt_tip_mov_contable(t.cod_modulo, t.cod_modalidad, t.cod_transaccion) = 'C'))
   order by nro_secuencia;   
  mv movimientos%rowtype;   
begin
 -- Valido la boleta
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de la Operación.';
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
          v_msj_respuesta := 'Caja no esta habilitada en '||mv.cod_moneda||' para esta Operacion';
       elsif v_fec_caja <> v_fec_actual then
          v_cod_respuesta := '005'; -- error
          v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';                
/*       elsif v_cod_oficina <> mv.cod_ofi_origen then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Operacion no corresponde a esta Oficina';                
*/       end if;
       if v_cod_respuesta <> '000' then 
          exit; -- sale cuando ya hay error
       end if;   
       -- Cargo los datos a desplegar 
       if v_des_transaccion is null then
          v_cod_tra         := mv.cod_transaccion;
          v_des_transaccion := mv.descripcion;
          v_cod_moneda   := mv.cod_moneda;
          v_observacion  := mv.concepto;
       else
          If mv.cod_transaccion = 740 then --Efectivo
            v_efectivo := mv.monto;
            v_total := nvl(v_total,0) + mv.monto;
          elsif mv.cod_transaccion = 606 then --C/Ntro.Banco
            v_cheque   := mv.monto;
            v_total := nvl(v_total,0) + mv.monto;
          elsif mv.cod_transaccion in (607,610,632) then --C/O/Bancos
            v_otro_cheque := mv.monto;
            v_total := nvl(v_total,0) + mv.monto;
          End if;
        end if;
     end loop;
     if v_existe = 'N' and v_cod_respuesta = '000' then
         v_cod_respuesta := '007'; -- error
         v_msj_respuesta := 'Operacion ya fue procesada o no corresponde.';
     end if;
     -- cargo los datos a desplegar si no hay errores
       v_det_campos := 
           '[' || 'COD_TRANSACCION' ||'~'||v_cod_tra||']' || 
           '[' || 'DES_TRANSACCION' ||'~'||v_des_transaccion||']' || 
           '[' || 'OBSERVACION' ||'~'||v_observacion||']' || 
           '[' || 'TOTAL' ||'~'||v_total||']' || 
           '[' || 'COD_MONEDA' ||'~'||v_cod_moneda||']' || 
           '[' || 'EFECTIVO' ||'~'||v_efectivo||']' || 
           '[' || 'CHEQUE' ||'~'||v_cheque||']' || 
           '[' || 'OTROS_CHE' ||'~'||v_otro_cheque||']';
  end if;         
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_247;
/

