CREATE OR REPLACE PROCEDURE IT.PRP_PRO_PREVISIONES
  is
 v_lugar varchar2(200);
 v_fun_pre_res4_activado        ge_par_dinamicos.val_parametro%type  := fug_obt_pardinamico('FUN_PRE_RES4_HABILITADO'); 
begin
   v_lugar := 'inicio';
   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 6;
   --
   
   v_lugar:= 'prp_gen_previsiones';
   dbms_output.put_line('prp_gen_previsiones');
   prp_gen_previsiones;

/*   v_lugar:= 'prp_gen_pre_resolucion4';
   dbms_output.put_line('prp_gen_pre_resolucion4');
   prp_gen_pre_resolucion4;*/
     
     
/*   v_lugar:= 'prp_gen_pre_dif_resolucion4';
   dbms_output.put_line('prp_gen_pre_dif_resolucion4');
   prp_gen_pre_dif_resolucion4;*/
   dbms_output.put_line('fin');
   
   --
   v_lugar:= 'fin';
exception
when others then
    raise_application_error(-20005, 'lugar '||v_lugar ||'-'||sqlerrm);
end PRP_PRO_PREVISIONES;
/

