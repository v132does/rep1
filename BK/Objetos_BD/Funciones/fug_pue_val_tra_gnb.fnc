CREATE OR REPLACE FUNCTION IT.fug_pue_val_tra_gnb (
 p_tip_mensaje in varchar2,       --MT103/MT102
 p_duplicado in varchar2  default null) --duplicado S/N
return varchar2
IS
 -- varibles
 v_fec_actual  date := pag_cal.FU_OBT_FEC_ACTUAL(9);
 v_hor_actual  varchar2(10);
 v_lugar       varchar(200);
 v_es_feriado varchar2(1);
 v_hor_max_val_snp_gnb ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'MAX_HOR_VAL_SNP_GNB');
 v_hor_ini_sipap varchar2(10);
 v_habilitado  varchar2(10);
     
    
/*Funcion para validas si se puede consultar a GNBPY o No
Validamos para los mt103 / mt 102
  Retorna "N"
  - Si es feriado     
  - Si es menor a la hora de inicio de sipap   
  - Si es mayor a la hora de cierre parametrizada para procesar. (MAX_HOR_VAL_SNP_GNB)   
  Sino "S"
*/     
     
     
  begin
     --****** Inicio de Proceso Principal *******
     --Verificamos primero si el parametro de validacion esta activo
    v_habilitado:='N';
    if p_tip_mensaje = 'MT103' THEN
       v_habilitado:= upper(nvl(fug_obt_pardinamico( 'VAL_CTA_GNB_SNP_103'),'N'));
    elsif p_tip_mensaje = 'MT102' THEN
       v_habilitado:= upper(nvl(fug_obt_pardinamico( 'VAL_CTA_GNB_SNP_102'),'N'));
    end if;
    
    --Si esta habilitado seguimos validando
    if nvl(v_habilitado,'N') = 'S' then
            --Verificamos si no es duplicado          
             if  nvl(p_duplicado,'N') = 'N' then

                --Verificar si fecha sistema es feriado--
                 v_lugar :='-1.Verificar si es feriado: ' || trunc(sysdate);
                 select decode(nvl(count(*),0),0,'N','S')
                   into v_es_feriado
                   from ba_feriados
                  where fecha = trunc(sysdate)
                    and cod_oficina = fug_obt_ofi_usuario(user);

                    --Si es feriado, ya no se procesa operativamente 
                  if nvl(v_es_feriado,'N') = 'S' then
                       return 'N';
                  else
                     --Obtenemos la hora de Inicio del Periodo 1, que es el primero que se abre siempre  
                     begin
                      select a.hor_inicio
                        into v_hor_ini_sipap
                            from ge_snp_horarios a
                               where trunc(fecha) = trunc(v_fec_actual)      
                                 and a.cod_periodo= 1;
                                
                     exception
                       when no_data_found then
                           v_hor_ini_sipap:= null;
                       when others then 
                           v_lugar := v_lugar|| '-Err.'||sqlerrm;
                           return v_lugar;
                     end;
                                   
                      v_hor_actual := to_char(sysdate,'hh24mi') ;
                      -- Si la hora es menor al inicio de dia de Sipap, no se levantara WF  
                      if to_number(v_hor_actual) < to_number(v_hor_ini_sipap) then
                           return 'N';
                      else
                         --Carga de Variables--
                         --Val si es mayor a Hora par.sipap 
                         if to_number(v_hor_max_val_snp_gnb) < to_number(v_hor_actual) then
                              return 'N';
                              --return 'S';
                         else
                            --Sino se cumple ninguna, retornamos que se puede operar
                            return 'S';
                         end if;
                       end if; 
                 end if;
         else
              return 'N';
         end if;
   
   else
      return 'N';
   end if;
     
end;
/

