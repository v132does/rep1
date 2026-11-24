create or replace procedure it.prl_arm_msj_swift_tmp is
/*
Procedimiento para armar el mensaje swift completo
luego de la importación del archivo de los ACK recibidos
*/
rg_tra lc_arm_msj_swift_tmp%rowtype;
v_var_fin number(15) := 0;
v_var_sig_msj varchar(1000) := null;
v_var_cant_imp number(20) := 0;
v_can_registros number(20):= 0;
v_can_reg_procesados number(20) := 0;
v_aux_msj_swift number(15) := 0;
v_error_sql varchar2(300):= null;
Cursor lc_swift is
  Select * 
    from lc_msj_swift_tmp
    order by nro_orden;
PROCEDURE lp_ins_lc_arm_msj_swift_tmp is  
  Begin
     insert into lc_arm_msj_swift_tmp 
                 (nro_ref_externa,msj_swift,cod_msj_swift)
          values (rg_tra.nro_ref_externa,rg_tra.msj_swift,rg_tra.cod_msj_swift);
       rg_tra.nro_ref_externa := null;
       rg_tra.msj_swift       := null;
       rg_tra.cod_msj_swift            := null;
       v_var_cant_imp         := v_var_cant_imp + 1;
  exception
     when others then
        RAISE_APPLICATION_ERROR(-20000,sqlerrm);        
  End;
begin
   sql_util.ejecute_dml('truncate table lc_arm_msj_swift_tmp',v_error_sql);
   Select count(1)
     Into v_can_registros
     From lc_msj_swift_tmp;
   For l in lc_swift loop
      v_can_reg_procesados := v_can_reg_procesados + 1;
      v_var_fin := instr(l.texto,'}$');
      -- NÚMERO REFERENCIA EXTERNA
      if rg_tra.nro_ref_externa is null then
         if substr(l.texto,1,4) = ':20:' then  
            rg_tra.nro_ref_externa := substr(l.texto,5); 
            if v_var_cant_imp > 0 then 
               rg_tra.msj_swift := v_var_sig_msj|| substr(l.texto,1,v_var_fin);
            end if;
         end if;
      end if; 
      -- MSJ_SWIFT  
      if v_var_fin = 0 and v_can_reg_procesados = 1 then 
         rg_tra.msj_swift :=  l.texto; -- para el primer mensaje
      elsif v_var_fin = 0 and v_can_reg_procesados > 1 then
         rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || l.texto;
      elsif v_var_fin > 0 then -- fin del mensaje
            rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || substr(l.texto,1,v_var_fin);
            v_var_sig_msj    := substr(l.texto,v_var_fin+2);
            v_aux_msj_swift  := instr(rg_tra.msj_swift,'{2:I103');
            --Solo inserta si es un MT103 enviado
            if v_aux_msj_swift > 0 then
               rg_tra.cod_msj_swift := '103';
               lp_ins_lc_arm_msj_swift_tmp;
            else 
               --Si no inserta debe limpiar los registros.
               rg_tra.nro_ref_externa := null;
               rg_tra.msj_swift       := null;
               rg_tra.cod_msj_swift   := null;
               v_var_cant_imp         := v_var_cant_imp + 1;            
            end if;   
      end if;
       -- Para insertar el último mensaje
      if v_can_registros = v_can_reg_procesados then
         v_aux_msj_swift  := instr(rg_tra.msj_swift,'{2:I103');
         --Solo inserta si es un MT103 enviado
         if v_aux_msj_swift > 0 then
            rg_tra.cod_msj_swift := '103';
            lp_ins_lc_arm_msj_swift_tmp;
         else
            --Si no inserta debe limpiar los registros.
            rg_tra.nro_ref_externa := null;
            rg_tra.msj_swift       := null;
            rg_tra.cod_msj_swift   := null;
            v_var_cant_imp         := v_var_cant_imp + 1;      
         end if;  
      end if;   
   End loop;
exception
   when others then
     RAISE_APPLICATION_ERROR(-20001,sqlerrm);   
end prl_arm_msj_swift_tmp;
/

