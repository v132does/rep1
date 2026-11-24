create or replace procedure it.prl_imp_ack_msj_swift is
begin
  prl_arm_msj_swift_tmp;
  prl_act_msj_swift;
Exception
  When others then
     RAISE_APPLICATION_ERROR(-20001,sqlerrm);   
end prl_imp_ack_msj_swift;
/

