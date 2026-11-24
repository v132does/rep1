CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_261
 (p_nro_operacion  in varchar2,   -- Nro de referencia de la operacion
  p_nro_caja       in varchar2,   -- Nro de Caja
  p_cod_bien       in number
 )
RETURN varchar2
IS
  v_cod_usuario   ge_movimientos.cod_usuario%type := user;
  v_cod_moneda    ge_movimientos.cod_moneda%type;  
  v_efectivo      ge_movimientos.monto%type;
  v_cheque        ge_movimientos.monto%type;
--  v_cta_contable  ge_movimientos.monto%type;
  v_monto         ge_movimientos.monto%type := 0;
  v_movimientos   varchar2(1):= 'N';
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  v_can_campos    number(3) := 0;        -- cantidad de campos
  v_det_campos    varchar2(4000) := null;
--
  v_cod_modulo      ge_movimientos.cod_modulo%type := 9;      -- modulo Caja
  v_cod_transaccion ge_movimientos.cod_transaccion%type := 261;
  v_fec_actual      date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hora            ge_movimientos.hora%type;
  v_monto_cheque_n  ge_movimientos.monto%type;
  v_tip_cheque      ge_movimientos.cod_transaccion%type; 
  v_cliente         ba_personas.nom_completo%type; 
--
  cursor c_cobros is
    select cod_transaccion, sum(monto) monto, 
           min(hora) hora, cod_moneda
      from ge_movimientos c
     where cod_tra_padre = v_cod_transaccion
       and fecha  = v_fec_actual
       and cod_transaccion not in (2612,2613) --Transacciones de diferencia entre el bien y el mto. de venta
       and nro_documento = p_cod_bien
       and c.hora = (select min (hora)
                     from ge_movimientos d
                    where d.fecha = c.fecha
                      and d.cod_usuario = c.cod_usuario
                      and d.nro_documento = c.nro_documento
                      and d.estado = 'J'                      
                      and d.cod_tra_padre = c.cod_tra_padre)
     group by cod_transaccion, cod_moneda;
Begin
-------------------------PROCESO PRINCIPAL-------------------------
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= v_cod_modulo; End;

   v_can_campos := 13;
   v_det_campos :=
           '[' || 'HORA' ||'~ ]' ||    
           '[' || 'CLIENTE' ||'~ ]' ||    
           '[' || 'COD_MONEDA' ||'~ ]' ||
           '[' || 'MONTO' ||'~ ]' ||     
           '[' || 'EFECTIVO' ||'~ ]' ||
           '[' || 'CHEQUE' ||'~ ]' || 
           '[' || 'CHE_NTR_BCO' ||'~ ]' ||
           '[' || 'TIP_CHEQUE' ||'~ ]' /*||
           '[' || 'CTA_CONTABLE' ||'~ ]'*/;

    for reg in c_cobros loop
       begin
         select b.cod_per_venta||'-'||p.nom_completo
           into v_cliente
           from bu_bienes b,
                ba_personas p
          where cod_bien = p_cod_bien
            and b.cod_per_venta = p.cod_persona;
       exception
         when others then
           null;
       end;
       v_movimientos := 'S';
       v_hora        := reg.hora;
       v_cod_moneda  := reg.cod_moneda;
       if reg.cod_transaccion = 740 then
         v_efectivo := reg.monto;
       elsif reg.cod_transaccion in (607, 610, 632) then
         v_cheque := reg.monto;
         if reg.cod_transaccion = 607 then
           v_tip_cheque := 1;
         elsif reg.cod_transaccion = 610 then
           v_tip_cheque := 2;
         elsif reg.cod_transaccion = 632 then
           v_tip_cheque := 3;
         end if;
       elsif reg.cod_transaccion = 606 then
         v_monto_cheque_n := reg.monto;
/*       elsif reg.cod_transaccion = 842 then
         v_cta_contable := reg.monto;*/
       end if;
    end loop;
    v_monto := nvl(v_efectivo,0) + nvl(v_cheque,0) + nvl(v_monto_cheque_n,0); 
    if v_movimientos = 'S' then
      v_det_campos :=
        fuj_des_campo('HORA'           , v_hora, null, null)||      
        fuj_des_campo('CLIENTE'        , v_cliente, null, null)||
        fuj_des_campo('COD_MONEDA'     , v_cod_moneda, null, null)||
        fuj_des_campo('MONTO'          , nvl(v_monto,0), null, null)||
        fuj_des_campo('EFECTIVO'       , nvl(v_efectivo,0), null, 'D')||
        fuj_des_campo('CHEQUE'         , nvl(v_cheque,0), null, 'D')||
        fuj_des_campo('CHE_NTR_BCO'    , nvl(v_monto_cheque_n,0), null, 'D')||          
        fuj_des_campo('TIP_CHEQUE'     , v_tip_cheque, null, 'D')/*|| 
        fuj_des_campo('CTA_CONTABLE'   , nvl(v_cta_contable,0), null, null)*/ ;
    else
      v_cod_respuesta := '004';
      v_msj_respuesta := 'ERROR: Bien no existe o no está pendiente';
    end if;
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     nvl(v_msj_respuesta,'OK')||'~'||
                     ltrim(to_char(v_can_campos,'000'))||'~'||
                     v_det_campos;
 return(v_msj_salida);
exception
    when others then
       v_cod_respuesta := '999';
       v_msj_salida := p_nro_operacion||'~'||
                       v_cod_respuesta||'~'||
                       SQLERRM;
       return(v_msj_salida);
end;
/

