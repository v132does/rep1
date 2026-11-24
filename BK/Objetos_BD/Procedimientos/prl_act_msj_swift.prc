create or replace procedure it.prl_act_msj_swift is
Cursor msj_swift is
 Select nro_ref_externa, msj_swift
   From lc_arm_msj_swift_tmp;
begin
  For m in msj_swift loop
      Begin
        Update lc_transferencias l
           Set l.msj_swift = m.msj_swift
         Where l.nro_ref_externa = m.nro_ref_externa;
      Exception 
         When others then
           null; --si no puede actualizar un registro no debe hacer nada.    
      End;
  End loop;
Exception 
  When others then  
     RAISE_APPLICATION_ERROR(-20001,sqlerrm);   
end prl_act_msj_swift;
/

