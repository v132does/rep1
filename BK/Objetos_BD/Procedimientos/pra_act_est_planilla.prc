CREATE OR REPLACE PROCEDURE IT.PRA_ACT_EST_PLANILLA
 (P_NUMERO IN NUMBER
 ,P_TIPO IN NUMBER
 )
 IS
begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 3;
  update ge_planillas
     set estado = 4,
         cod_usu_emision = user,
         fec_emision     = pae_cnf.fu_obt_fec_actual(pae_cnf.G_COD_MODULO)
   where nro_planilla  = p_numero and
         tipo          = p_tipo and
         estado        = 2;
exception
  when others then
   raise_application_error(-20000,'Act. estado planilla '||SQLERRM);
end;
/

