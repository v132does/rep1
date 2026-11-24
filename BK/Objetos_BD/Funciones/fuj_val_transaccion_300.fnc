CREATE OR REPLACE FUNCTION IT."FUJ_VAL_TRANSACCION_300" (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_moneda in varchar2 default pag_gen.FU_OBT_MON_LOCAL,
      p_cod_retencion in varchar2 default null)      -- Codigo de moneda
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 300;        -- Transaccion
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
  -- detalle de campos. Por defecto van los campos en blanco
  v_can_campos    number(3) := 7;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=       -- valor por defecto
              '[' || 'COD_MONEDA      '||'~ ]' ||
              '[' || 'DEP_CTA_CANTIDAD'||'~ ]' ||
              '[' || 'DEP_CTA_MONTO'   ||'~ ]' ||
              '[' || 'COB_VAR_MONTO'   ||'~ ]' ||
              '[' || 'COB_VAR_CANTIDAD'||'~ ]' ||
              '[' || 'TOT_MONTO'       ||'~ ]' ||
              '[' || 'TOT_CANTIDAD'    ||'~ ]';
  v_dep_cta_cantidad number := 0;
  v_dep_cta_monto    number := 0;
  v_cob_var_cantidad number := 0;
  v_cob_var_monto    number := 0;
  v_tot_cantidad     number := 0;
  v_tot_monto        number := 0;
  v_can_reg          number := 0;
  v_tip_monto        varchar2(1);
  v_cod_retencion    number(1);
  cursor c_dia is 
    select x.concepto, x.nro_caja,
           count(*) cant_boletas, sum(x.monto) total
      from (select (case when (a.cod_tra_padre in
                 (select c.cod_transaccion
                    from ge_gru_transacciones_det c
                   where c.cod_transaccion = a.cod_tra_padre
                     and c.cod_gru_transaccion =
                     fug_obt_pardinamico('GRU_DEP_CHE_COB',
                                          a.cod_mod_padre,
                                          a.cod_mad_padre,
                                          a.cod_moneda) )
                     ) then 'DEPOSITO EN CUENTA'
                  else ('COBROS VARIOS')end) concepto,
                 a.nro_caja,a.cod_usuario, 
                 a.monto
            from cj_movimientos a
           where a.fecha = pae_cnf.fu_obt_fec_actual(v_cod_modulo)
             and (a.cod_mod_padre = v_cod_modulo
              or (a.cod_mod_padre = 6   --RI: 16/12/2010
             and FUP_EXI_GRU_TRANSAC(803, a.cod_tra_padre, 9, 91) = 'S'))
             and (a.cod_mad_padre = v_cod_modalidad
              or (a.cod_mod_padre = 6
             and FUP_EXI_GRU_TRANSAC(803, a.cod_tra_padre, 9, 91) = 'S'))  --RI: 16/12/2010           
             and a.nro_caja = p_nro_caja
             --and a.cod_usuario = v_cod_usuario
             and (a.cod_usuario = v_cod_usuario  
              or (a.cod_usuario <> v_cod_usuario   --RI: 02/12/2010
             and FUP_EXI_GRU_TRANSAC(803, a.cod_tra_padre, 9, 91) = 'S'))            
             and a.cod_moneda = pag_gen.fu_obt_mon_local
             and a.cod_tra_padre != v_cod_transaccion
             and a.cod_tra_padre not in (v_cod_transaccion,202,203,110,133)
             and a.estado != 'R'
             and a.tip_monto = v_tip_monto
             and a.tip_monto in ('O','S','T')-- O = R1, S = R2, T = R3
--           and a.hora < to_char(sysdate,'hh24:mi:ss') 
--           and to_char(a.fec_insercion,'hh24:mi:ss') < to_char(sysdate,'hh24:mi:ss') 
             and trunc(a.fec_insercion) <= trunc(sysdate)                             --CRO-JM-2014: JIRA-DYDMR-1053 Diferencia entre Cidesa y Listado ITGF
             and not exists (select 1 from cj_cortes_tmp b
                              where b.fecha = a.fecha
                                and b.hora = a.hora
                                and b.cod_usuario = a.cod_usuario
                                and b.nro_secuencia = a.nro_secuencia)
             
             ) x
  group by x.concepto, x.nro_caja; /*AP 1659 - No corresponde ya agrupar por usuario por lo mencionado aqui abajo*/
  --RI:02/12/2010: cuando el movimientos es de pago de prestamos c/cheque y es ingresado en ITGF
  --y luego retomado en caja, el usuario con que se graba el movimiento en caja es el usuario
  --original que realizó el cobro no el usuario del cajero.
  --RI:16/12/2010: tambien para el caso se da que el modulo y modalidad padre no corresponde al
  --de caja sino al de prestamos.
begin
  if p_cod_retencion is null then
    v_cod_retencion := 1;
  else
    v_cod_retencion := p_cod_retencion;
  end if;
  if v_cod_retencion = 1 then
    v_tip_monto := 'O';
  elsif v_cod_retencion = 2 then
    v_tip_monto := 'T';
  elsif v_cod_retencion = 3 then
    v_tip_monto := 'S';
  end if;
  if p_cod_retencion is not null and p_cod_moneda is not null then
      for k in c_dia loop
        if k.concepto = 'DEPOSITO EN CUENTA' then
          v_dep_cta_cantidad := k.cant_boletas;
          v_dep_cta_monto    := k.total;
        else
          v_cob_var_cantidad := k.cant_boletas;
          v_cob_var_monto    := k.total;
        end if;
        v_can_reg := v_can_reg + 1;
        if v_can_reg > 2 then
          v_cod_respuesta := '001'; -- error
          v_msj_respuesta := 'ERROR: Registros no válidos.';
        end if;
      end loop;
  end if;
  v_tot_cantidad := nvl(v_dep_cta_cantidad,0) + nvl(v_cob_var_cantidad,0);
  v_tot_monto    := nvl(v_dep_cta_monto,0) + nvl(v_cob_var_monto,0);
    
  -- Valido la moneda
  if p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda.';
  else
    -- Valido la moneda ingresada
    if p_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
      prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
    else
      v_cod_respuesta := '006'; -- error, no existe registro de caja
      v_msj_respuesta := 'ERROR: Solo para Moneda Local.';
    end if;
  end if;
  -- Retención
  
  if p_cod_retencion > 3 then
    v_cod_respuesta := '001';
    v_msj_respuesta := 'ERROR: Ingrese una Retención válida.';
  end if;
  
  
 if v_cod_respuesta = '000' then -- no hubo errores
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
    elsif v_estado = 2 then -- caja cerrada
       v_cod_respuesta := '007';
       v_msj_respuesta := 'Caja Cerrada.';
    end if;
       v_det_campos := '['||'COD_MONEDA'      ||'~'||ltrim(p_cod_moneda)               ||']'||
                      -- '['||'COD_RETENCION'   ||'~'||ltrim(to_char(p_cod_retencion))   ||']'||
                       '['||'DEP_CTA_CANTIDAD'||'~'||ltrim(to_char(v_dep_cta_cantidad))||']'||
                       '['||'DEP_CTA_MONTO'   ||'~'||ltrim(to_char(v_dep_cta_monto))   ||']'||
                       '['||'COB_VAR_MONTO'   ||'~'||ltrim(to_char(v_cob_var_monto))   ||']'||
                       '['||'COB_VAR_CANTIDAD'||'~'||ltrim(to_char(v_cob_var_cantidad))||']'||
                       '['||'TOT_MONTO'       ||'~'||ltrim(to_char(v_tot_monto))       ||']'||
                       '['||'TOT_CANTIDAD'    ||'~'||ltrim(to_char(v_tot_cantidad))    ||']';

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
end FUJ_VAL_TRANSACCION_300;
/

