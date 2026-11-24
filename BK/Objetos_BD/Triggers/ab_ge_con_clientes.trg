CREATE OR REPLACE TRIGGER IT.ab_ge_con_clientes
 before delete or insert or update
 on it.ge_con_clientes
 for each row


declare

/* registrar campos de auditoria para insercion de datos. */
procedure lp_reg_aud_ins;
/* registrar campos de auditoria para modificacion del registro. */
procedure lp_reg_aud_mod;

/* registrar campos de auditoria para insercion de datos. */
procedure lp_reg_aud_ins
 is
begin
   :new.fec_insercion := sysdate;
   :new.usu_insercion := substr(user,1,10);
end;
/* registrar campos de auditoria para modificacion del registro. */
procedure lp_reg_aud_mod
 is
begin
   :new.fec_modificacion := sysdate;
   :new.usu_modificacion := substr(user,1,10);
end;
begin
   -- verificar que se realice por programa
   if nvl(pae_cnf.g_aplicacion,'N') = 'N' then
      raise_application_error(-20000,
      'Solo pueden realizarse modificaciones a traves del Sistema');
   end if;
   
   -- No debe controlar que el modulo se encuentre habilitado
   --pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
   
   -- registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
end;
/

