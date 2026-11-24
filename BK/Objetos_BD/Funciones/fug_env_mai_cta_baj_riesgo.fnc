create or replace function it.fug_env_mai_cta_baj_riesgo(p_cod_persona in ba_personas.dir_correo%type)
  return varchar2 is

  v_direccion ba_tab_dat_adicionales.val_parametro%type;
  v_cod_error          number(6);
  v_mensaje            varchar(4000);
  pragma autonomous_transaction;
begin
  v_direccion := fue_tab_dat_adicional('BA_PERSONAS',
                                           'EMAIL_ONBOARDING',
                                           p_cod_persona);
                                           
  /*v_direccion := nvl(fue_tab_dat_adicional('BA_PERSONAS',
                                           'EMAIL_ONBOARDING',
                                           p_cod_persona),
                     IT.FUG_OBT_DIR_MAIL_PER(p_cod_persona));*/
  if v_direccion is not null then
    
   /*it.pag_pla.pr_env_not_onboarding(p_cod_persona,
                         null,
                         v_direccion,
                         fug_obt_pardinamico('ONB_MAI_LIM_EXCEDIDO'),
                         v_cod_error,
                         v_mensaje);*/ --ver (?) 

    commit;
    return 'S';
  else
    return 'N';
 end if;
exception
  when others then
    return 'N';
end fug_env_mai_cta_baj_riesgo;
/

