CREATE OR REPLACE PROCEDURE IT.prg_upd_reg_onb(p_cod_onboarding in out ba_onb_empresas.cod_onb_emp%type,
                                               p_cod_pantalla   in ba_onb_empresas.cod_pantalla%type,
                                               p_onb_finalizado in ba_onb_empresas.onb_finalizado%type,
                                               p_dat_Persona    in ba_onb_empresas.dat_persona%type,
                                               p_dat_Empresa    in ba_onb_empresas.empresa%type,
                                               p_dat_Firmantes  in ba_onb_empresas.firmantes%type,
                                               p_dat_Documentos in ba_onb_empresas.documentos%type,
                                               p_dat_Usuarios   in ba_onb_empresas.usuarios%type,
                                               p_dat_Productos  in ba_onb_empresas.productos%type,
                                               p_telefono       in ba_onb_empresas.telefono%type,
                                               p_ruc_empresa    in ba_onb_empresas.ruc_empresa%type,
                                               p_cod_error      out number,
                                               p_mensaje        out varchar2,
                                               p_origen         in varchar2,
                                               p_tyc_Aprobado   in ba_onb_empresas.tyc_aprobado%type) is
  v_existe varchar2(1);
BEGIN
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

  p_cod_error := 0;
  p_mensaje   := nvl(fug_obt_pardinamico('DES_MSG_EXITO'), 'Transaccion Exitosa!');

  if p_telefono is null then
     p_cod_error := 5;
     p_mensaje   := 'El número de teléfono del solicitante no puede ser nulo';
     prg_ins_log_programas('PRG_UPD_REG_ONB', substr('Cod_Error: ' || p_cod_error ||
                              ' p_mensaje: ' || p_mensaje || ' ' ||
                              dbms_utility.format_error_stack || ' - ' ||
                              dbms_utility.format_error_backtrace, 1, 4000), null, null);
     return;
  end if;

  if p_cod_onboarding is null then
    select s_cod_onb_emp.nextval into p_cod_onboarding from dual;
    begin
      insert into ba_onb_empresas
        (COD_ONB_EMP,
         FEC_REGISTRO,
         EMPRESA,
         DAT_PERSONA,
         FIRMANTES,
         DOCUMENTOS,
         USUARIOS,
         PRODUCTOS,
         COD_PANTALLA,
         ONB_FINALIZADO,
         TELEFONO,
         RUC_EMPRESA,
         ORIGEN,
         TYC_APROBADO
         )
      values
        (p_cod_onboarding,
         sysdate,
         p_dat_Empresa,
         p_dat_Persona,
         p_dat_Firmantes,
         p_dat_Documentos,
         p_dat_Usuarios,
         p_dat_Productos,
         p_cod_pantalla,
         p_onb_finalizado,
         p_telefono,
         p_ruc_empresa,
         p_origen,
         p_tyc_Aprobado);
    exception
      when others then
        p_cod_error      := 1;
        p_mensaje        := 'Error al realizar insert en ba_onb_empresas';
        p_cod_onboarding := null;
        prg_ins_log_programas('PRG_UPD_REG_ONB', substr('Cod_Error: ' || p_cod_error ||
                              ' p_mensaje: ' || p_mensaje || ' ' ||
                              dbms_utility.format_error_stack || ' - ' ||
                              dbms_utility.format_error_backtrace, 1, 4000), null, null);
    end;

  else
    begin
      select 'S'
        into v_existe
        from ba_onb_empresas t
       where t.cod_onb_emp = p_cod_onboarding;
    exception
      when no_data_found then
        v_existe    := 'N';
        p_cod_error := 2;
        p_mensaje   := 'No existe cod_onboarding recibido';
      when others then
        p_cod_error := 3;
        p_mensaje   := 'Error al realizar consulta en ba_onb_empresas';
    end;
    if nvl(v_existe, 'N') = 'S' and nvl(p_cod_error, 0) = 0 then
      if p_ruc_empresa is not null then -- agregamos el atributo ruc_empresa al update
          update ba_onb_empresas t
             set FEC_REGISTRO   = sysdate,
                 EMPRESA        = p_dat_Empresa,
                 DAT_PERSONA    = p_dat_Persona,
                 FIRMANTES      = p_dat_Firmantes,
                 DOCUMENTOS     = p_dat_Documentos,
                 USUARIOS       = p_dat_Usuarios,
                 PRODUCTOS      = p_dat_Productos,
                 COD_PANTALLA   = p_cod_pantalla,
                 ONB_FINALIZADO = p_onb_finalizado,
                 TELEFONO       = p_telefono,
                 RUC_EMPRESA    = p_ruc_empresa,
                 ORIGEN         = p_origen,
                 TYC_APROBADO   = p_tyc_Aprobado
           where t.cod_onb_emp = p_cod_onboarding;
          if sql%notfound then
            p_cod_error := 4;
            p_mensaje   := 'No existe cod_onboarding recibido';
          end if;
       else  -- no se incluye el atributo ruc_empresa al update
            update ba_onb_empresas t
             set FEC_REGISTRO   = sysdate,
                 EMPRESA        = p_dat_Empresa,
                 DAT_PERSONA    = p_dat_Persona,
                 FIRMANTES      = p_dat_Firmantes,
                 DOCUMENTOS     = p_dat_Documentos,
                 USUARIOS       = p_dat_Usuarios,
                 PRODUCTOS      = p_dat_Productos,
                 COD_PANTALLA   = p_cod_pantalla,
                 ONB_FINALIZADO = p_onb_finalizado,
                 TELEFONO       = p_telefono,
                 ORIGEN         = p_origen,
                 TYC_APROBADO   = p_tyc_Aprobado
           where t.cod_onb_emp = p_cod_onboarding;
          if sql%notfound then
            p_cod_error := 4;
            p_mensaje   := 'No existe cod_onboarding recibido';
          end if;
       end if;

    end if;
  end if;

  if nvl(p_cod_error, 0) != 0 then
    prg_ins_log_programas('PRG_UPD_REG_ONB', substr('Cod_Error: ' || p_cod_error ||
                          ' p_mensaje: ' || p_mensaje || ' ' ||
                          dbms_utility.format_error_stack || ' - ' ||
                          dbms_utility.format_error_backtrace, 1, 4000), null, null);
  end if;

EXCEPTION
  WHEN OTHERS THEN
    p_cod_error := 999;
    prg_ins_log_programas('PRG_UPD_REG_ONB', substr('Cod_Error: ' || p_cod_error ||
                          ' p_mensaje: ' || p_mensaje || ' ' ||
                          dbms_utility.format_error_stack || ' - ' ||
                          dbms_utility.format_error_backtrace, 1, 4000), null, null);
END prg_upd_reg_onb;
/
