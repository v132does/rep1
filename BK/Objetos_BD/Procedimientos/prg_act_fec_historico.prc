create or replace procedure it.prg_act_fec_historico(p_est_proceso varchar2) is

-------------------------------------------------------------------------------------
--Creado por : LCABRERA --
--Uso: Programa que debe actualizar la fecha desde la cual se puede consultar 
--la vista GV_MOVIMIENTOS. Teniendo en cuenta el inicio del proceso de Cierre 
--o Uso Fuera del proceso del cierre para la  vista
---DESOPIMI-81 - Optimización - Mejorar vista GV_MOVIMIENTOS - DYD-SDSL-3483
-------------------------------------------------------------------------------------



  v_fecha                date := pag_cal.fu_obt_fec_actual(1);
  v_hor_inicio           varchar2(8);
  v_hor_fin              varchar2(8);
  v_can_dia_mov_cierre   number := to_number(fug_obt_pardinamico('CAN_DIA_MOV_CIERRE'));
  v_fec_ini_mov_completo date := to_date(fug_obt_pardinamico('FEC_INI_MOV_COMPLETO'),'dd/mm/yyyy');
  v_fec_actualizar       date;
  
begin
  
  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  --Al Iniciar el proceso 11-Cierre Operativo, se calcula y actualiza la fecha desde el cual se puede 
  --consultar durante la ejecución del Cierre
  if p_est_proceso = 'I' then

    v_fec_actualizar := v_fecha - v_can_dia_mov_cierre;
    
  elsif p_est_proceso = 'F' then
    --Al finalizar el Proceso 11- Cierre se asigna el parámetro configurado para habilitar las fechas para consultar 
    --en GV_MOVIMIENTOS 
     v_fec_actualizar := v_fec_ini_mov_completo;

  end if;
  
  if v_fec_actualizar is not null then
   begin
      update ge_par_generales 
      set fec_his_desde = v_fec_actualizar;
    exception
      when others then
        RAISE_APPLICATION_ERROR(-20000,'PRG_ACT_FEC_CON_MOV_HIST-No se pudo actualizar Fecha. Estado Proc.: ' ||
                                p_est_proceso || ' ' || SQLERRM);
    end;
  end if;
 

  ---Actualización en LOG para verificaciones posteriores  
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('PRG_ACT_FEC_HISTORICO','PRG_ACT_FEC_HISTORICO', v_fecha, v_hor_inicio, v_hor_fin,
                      'Parámetro Recibido: '|| nvl(p_est_proceso, 'Nulo') ||' # '|| 
                      'Valor v_can_dia_mov_cierre: '|| v_can_dia_mov_cierre||' # '||
                      'Valor v_fec_ini_mov_completo: '||v_fec_ini_mov_completo||' # '||
                      'Se actualiza con el dato: '||v_fec_actualizar);

  
exception
  when others then
        RAISE_APPLICATION_ERROR(-20001,'PRG_ACT_FEC_CON_MOV_HIST-No se pudo actualizar Fecha. Estado Proc.: ' ||
                                p_est_proceso || ' ' || SQLERRM);
            
end;
/

