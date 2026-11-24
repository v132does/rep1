create or replace trigger it.ab_ge_log_pag_int_salario before
   delete or insert or update on ge_log_pag_int_salario
   for each row
declare

/* Registrar campos de auditoria para insercion de datos. */
   procedure lp_reg_aud_ins;
/* Registrar campos de auditoria para modificacion del registro. */
   procedure lp_reg_aud_mod;

/* Registrar campos de auditoria para insercion de datos. */
   procedure lp_reg_aud_ins is
   begin
      :new.fec_insercion := sysdate;
      :new.usu_insercion := substr(
         user,
         1,
         10
      );
   end;
/* Registrar campos de auditoria para modificacion del registro. */
   procedure lp_reg_aud_mod is
   begin
      :new.fec_modificacion := sysdate;
      :new.usu_modificacion := substr(
         user,
         1,
         10
      );
   end;
begin
   -- Verificar que se realice por programa
   if nvl(
      pae_cnf.g_aplicacion,
      'N'
   ) = 'N' then
      raise_application_error(
         -20000,
         'Solo pueden realizarse modificaciones a través del Sistema'
      );
   end if;
      -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
end;
/