CREATE OR REPLACE PACKAGE IT.pag_pla IS

  /* Alta persona */
  PROCEDURE pr_alt_persona(p_tipo              in ba_personas.tipo%type, -- fisica o juridica
                           p_nombres           in ba_personas.nom_completo%type,
                           p_apellidos         in ba_personas.nom_completo%type,
                           p_nro_documento     in ba_personas.nro_documento%type,
                           p_tip_documento     in ba_personas.cod_tip_documento%type,
                           p_est_civil         in ba_per_fisicas.est_civil%type,
                           p_fec_nacimiento    in ba_per_fisicas.fec_nacimiento%type,
                           p_cod_sexo          in ba_per_fisicas.cod_sexo%type,
                           p_fec_vto_documento in ba_personas.fec_vto_documento%type,
                           p_direccion         in ba_direcciones.direccion%type,
                           p_cod_ciudad        in ba_ciudades.cod_ciudad%type,
                           p_cod_pais          in ba_ciudades.cod_pais%type,
                           p_rub_primario      in ba_personas.cod_rub_primario%type,
                           p_num_celular       in ba_telefonos.telefono%type,
                           p_dir_correo        in ba_personas.dir_correo%type,
                           p_est_documento     in varchar2,
                           p_est_pru_vida      in varchar2,
                           p_cod_pai_nac       in ba_per_fisicas.cod_pai_nacionalidad%TYPE,
                           p_cod_ciu_nac       in ba_per_fisicas.cod_ciu_nacimiento%TYPE,
                           p_nro_casa          in ba_direcciones.numero%TYPE,
                           p_cal_secundaria    in ba_direcciones.direccion%TYPE,
                           p_cod_barrio        in ba_direcciones.cod_barrio%TYPE,
                           p_cod_departamento  in ba_direcciones.cod_departamento%TYPE,
                           p_piso              in ba_direcciones.piso%TYPE,
                           p_edificio          in ba_direcciones.edificio%TYPE,
                           p_referencias       in ba_direcciones.observacion%TYPE,
                           p_est_bancarizacion in varchar2,
                           p_usu_plataforma    in varchar2,
                           p_latitud           in ba_direcciones.latitud%TYPE DEFAULT null,
                           p_longitud          in ba_direcciones.longitud%TYPE DEFAULT null,
                           p_fec_emision       in ba_personas.fec_vto_documento%type DEFAULT null,
                           p_est_match_doc     in varchar2,
                           p_es_pep            in varchar2,
                           p_isocr             in varchar2 default null,
                           p_cod_persona       out ba_personas.cod_persona%type,
                           p_est_verificacion  out varchar2,
                           p_cre_productos     out varchar2,
                           p_est_ios_excepcion out varchar2,
                           p_cod_error         out number,
                           p_mensaje           out varchar2);

  /* Inhibir Persona */
  FUNCTION fu_inh_persona(p_cod_persona IN ge_per_inhibidas.cod_persona%TYPE,
                          p_cod_causa   IN ge_per_inhibidas.cod_causa%type default null)
    return varchar2;

  /* Modificacion de datos de la persona*/
  FUNCTION fu_mod_persona(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                          p_tipo          IN ba_personas.tipo%TYPE,
                          p_profesion     IN ba_per_fisicas.cod_profesion%TYPE,
                          p_niv_educacion IN ba_per_fisicas.cod_niv_estudio%TYPE,
                          --Datos complejos
                          p_dir_correo         IN ba_personas.dir_correo%TYPE,
                          p_nro_documento      IN ba_personas.nro_documento%TYPE,
                          p_fec_vto_documento  IN ba_personas.fec_vto_documento%TYPE,
                          p_cod_rub_primario   IN ba_personas.cod_rub_primario%TYPE,
                          p_cod_rub_secundario IN ba_personas.cod_rub_secundario%TYPE,
                          p_cod_rub_terciaria  IN ba_personas.cod_rub_terciario%TYPE,
                          p_cod_tip_documento  IN ba_personas.cod_tip_documento%TYPE,
                          p_es_contribuyente   IN ba_personas.tip_iva%TYPE,
                          --Persona fisica
                          p_nombres              IN ba_personas.nom_completo%TYPE,
                          p_apellidos            IN ba_personas.nom_completo%TYPE,
                          p_est_civil            IN ba_per_fisicas.est_civil%TYPE,
                          p_fec_nacimiento       IN ba_per_fisicas.fec_nacimiento%TYPE,
                          p_cod_ciu_nacimiento   IN ba_per_fisicas.cod_ciu_nacimiento%TYPE,
                          p_cod_pai_nacionalidad IN ba_per_fisicas.cod_pai_nacionalidad%TYPE,
                          p_cod_sexo             IN ba_per_fisicas.cod_sexo%TYPE)
    return varchar2;

  /* Modificacion de datos de direcciones de la persona*/
  FUNCTION fu_mod_dir_persona(p_cod_persona      IN ba_personas.cod_persona%TYPE,
                              p_cod_direccion    IN ba_direcciones.cod_direccion%TYPE,
                              p_tipo             IN ba_direcciones.tipo%TYPE,
                              p_pri_calle        IN ba_direcciones.direccion%TYPE,
                              p_sec_calle        IN ba_direcciones.direccion%TYPE,
                              p_cod_pais         IN ba_direcciones.cod_pais%TYPE,
                              p_cod_ciudad       IN ba_direcciones.cod_ciudad%TYPE,
                              p_cod_barrio       IN ba_direcciones.cod_barrio%TYPE,
                              p_referencia       IN ba_direcciones.observacion%TYPE,
                              p_numero           IN ba_direcciones.numero%TYPE,
                              p_departamento     IN ba_direcciones.departamento%TYPE,
                              p_piso             IN ba_direcciones.piso%TYPE,
                              p_edificio         IN ba_direcciones.edificio%TYPE,
                              p_cod_departamento IN ba_direcciones.cod_departamento%TYPE,
                              p_zon_geografica   in varchar2)
                            --  p_zon_geografica   IN ba_direcciones.zon_geografica%TYPE)
    return varchar2;

  /* Modificacion de datos de telefonos de la persona*/
  FUNCTION fu_mod_tel_persona(p_cod_persona  IN ba_telefonos.cod_persona%TYPE,
                              p_tipo         IN ba_telefonos.tipo%TYPE,
                              p_tip_linea    IN ba_telefonos.tip_linea%TYPE,
                              p_telefono     IN ba_telefonos.telefono%TYPE,
                              p_principal    IN ba_telefonos.principal%TYPE,
                              p_area         IN ba_telefonos.area%TYPE,
                              p_interno      IN ba_telefonos.interno%TYPE,
                              p_cod_telefono IN ba_telefonos.cod_telefono%TYPE)
    return varchar2;

  /* Modificacion de datos laborales de la persona */
  FUNCTION fu_mod_lab_persona(p_cod_persona   IN cr_inf_laborales.cod_persona%TYPE,
                              p_nro_secuencia IN cr_inf_laborales.nro_secuencia%TYPE,
                              p_tip_cargo     IN cr_inf_laborales.tip_cargo%TYPE,
                              p_lug_trabajo   IN cr_inf_laborales.lug_trabajo%TYPE,
                              p_fec_ingreso   IN cr_inf_laborales.fec_ingreso%TYPE,
                              p_cod_moneda    IN cr_inf_laborales.cod_moneda%TYPE,
                              p_tip_empleo    IN cr_inf_laborales.tip_empleo%TYPE)
    return varchar2;

  /*Modificacion de datos de referencias */
  FUNCTION fu_mod_ref_persona(P_COD_PERSONA    IN CR_REF_COMERCIALES.COD_PERSONA%TYPE,
                              P_TIP_REFERENCIA IN CR_REF_COMERCIALES.TIP_REFERENCIA%TYPE,
                              P_NRO_SECUENCIA  IN CR_REF_COMERCIALES.NRO_SECUENCIA%TYPE,
                              P_DES_ENTIDAD    IN CR_REF_COMERCIALES.DES_ENTIDAD%TYPE,
                              -- P_COD_TIP_CUENTA  IN CR_REF_COMERCIALES.COD_TIP_CUENTA%TYPE,
                              P_NRO_CUENTA IN CR_REF_COMERCIALES.NRO_CUENTA%TYPE)
    return varchar2;

  /* Modificacion de datos de vinculos */
  FUNCTION fu_mod_vin_persona(p_cod_persona     IN ba_vinculos.cod_persona%TYPE,
                              p_cod_per_vinculo IN ba_vinculos.cod_per_vinculo%TYPE,
                              p_cod_per_vin_ant IN ba_vinculos.cod_per_vinculo%TYPE,
                              p_tipo            IN ba_vinculos.tipo%TYPE,
                              p_fec_vencimiento IN ba_vinculos.fec_vencimiento%TYPE)
    return varchar2;

  /* Modificacion de datos de Ingresos y Egresos*/
  FUNCTION fu_mod_ing_egr_per(p_cod_persona  IN cr_per_ing_egresos.cod_persona%TYPE,
                              p_cod_concepto IN cr_per_ing_egresos.cod_concepto%TYPE,
                              p_cod_con_ant  IN cr_per_ing_egresos.cod_concepto%TYPE,
                              p_ing_egreso   IN cr_per_ing_egresos.ing_egreso%TYPE,
                              p_importe      IN cr_per_ing_egresos.importe%TYPE)
    return varchar2;
  PROCEDURE pr_upd_ba_per_ima_documentos(p_cod_persona       in ba_per_ima_documentos.cod_persona%TYPE,
                                         p_cod_tip_documento in ba_per_ima_documentos.cod_tip_documento%type,
                                         p_id_crear          in ba_per_ima_documentos.cod_id_crear%type,
                                         p_url_crear         in ba_per_ima_documentos.url_crear%type,
                                         p_cod_error         out number,
                                         p_men_error         out varchar2,
                                         p_fec_emision       in ba_per_ima_documentos.fec_emision%TYPE default null,
                                         p_usu_insercion     in ba_per_ima_documentos.usu_insercion%type default null,
                                         p_est_acuse_web     in ba_per_ima_documentos.est_acuse_web%type default 'N',
                                         p_fec_acuse_web     in ba_per_ima_documentos.fec_acuse_web%type default null
                                         );

  PROCEDURE pr_ins_checklist(p_cod_persona       in ba_per_ima_documentos.cod_persona%TYPE,
                             p_cod_error         out number,
                             p_men_error         out varchar2,
                             p_cod_tip_documento in ba_per_ima_documentos.cod_tip_documento%type DEFAULT null,
                             p_fec_emision       in ba_per_ima_documentos.fec_emision%TYPE DEFAULT null);

  PROCEDURE pr_act_est_checklist;
  /* Insertar GE_CLIENTES */
  FUNCTION fu_ins_ge_clientes(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2;
  /*Contactos*/
  Function fu_ins_tra_contacto(p_cod_persona      in ge_con_clientes.cod_persona%type,
                               p_nro_cta_contacto in ge_con_clientes.nro_cta_contacto%type,
                               p_alias            in ge_con_clientes.alias%type,
                               p_nombre           in ge_con_clientes.nombre%type,
                               p_apellido         in ge_con_clientes.apellido%type,
                               p_tip_documento    in ge_con_clientes.tip_documento%type,
                               p_nro_documento    in ge_con_clientes.nro_documento%type,
                               p_nro_celular      in ge_con_clientes.nro_celular%type,
                               p_dir_correo       in ge_con_clientes.dir_correo%type,
                               p_cod_ente         in ge_con_clientes.cod_ente%type,
                               p_cod_moneda       in ge_con_clientes.cod_moneda%type)
    return varchar2;
  procedure pr_ins_con_onboarding(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                  p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                  p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error      out number,
                                  p_mensaje        out varchar2);

  FUNCTION fu_ins_ba_per_ima_documentos(p_cod_persona       in ba_per_ima_documentos.cod_persona%TYPE,
                                        p_ima_documento     in ba_per_ima_documentos.ima_doc%TYPE,
                                        p_cod_tip_documento in ba_per_ima_documentos.cod_tip_documento%TYPE,
                                        p_fec_vencimiento   in ba_per_ima_documentos.fec_vencimiento%TYPE,
                                        p_fec_emision       in ba_per_ima_documentos.fec_emision%TYPE default null,
                                        p_observacion       in ba_per_ima_documentos.observacion%type default null,
                                        p_usu_insercion     in ba_per_ima_documentos.usu_insercion%type default null)

   RETURN varchar2;
  procedure pr_env_not_onboarding(p_cod_persona   in ba_personas.cod_persona%type,
                                  p_nro_documento in ba_personas.nro_documento%type,
                                  p_correo        in ba_tab_dat_adicionales.val_parametro%type,
                                  p_tip_producto  in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error     out number,
                                  p_mensaje       out varchar2);

  procedure pr_act_dat_persona(p_cod_persona      in ba_personas.cod_persona%type,
                               p_profesion        in ba_personas.cod_rub_primario%type,
                               p_direccion        in ba_direcciones.direccion%type,
                               p_cod_pais         in ba_direcciones.cod_pais%type,
                               p_cod_ciudad       in ba_direcciones.cod_ciudad%type,
                               p_nro_casa         IN ba_direcciones.numero%TYPE,
                               p_cal_secundaria   IN ba_direcciones.direccion%TYPE,
                               p_cod_barrio       IN ba_direcciones.cod_barrio%TYPE,
                               p_cod_departamento IN ba_direcciones.cod_departamento%TYPE,
                               p_piso             IN ba_direcciones.piso%TYPE,
                               p_edificio         IN ba_direcciones.edificio%TYPE,
                               p_referencias      IN ba_direcciones.observacion%TYPE,
                               p_telefono         in varchar2,
                               p_correo           in ba_personas.dir_correo%type,
                               p_latitud          in ba_direcciones.latitud%TYPE,
                               p_longitud         in ba_direcciones.longitud%TYPE,
                               p_cod_error        out number,
                               p_mensaje          out varchar2);

  PROCEDURE pr_alt_per_jur_onb(p_nombre              in ba_personas.nom_completo%type,
                                 p_nro_documento       in ba_personas.nro_documento%type,
                                 p_tip_documento       in ba_personas.cod_tip_documento%type,
                                 p_naturaleza          in ba_per_juridicas.naturaleza%type,
                                 p_cod_pais            in ba_ciudades.cod_pais%type,
                                 p_dir_correo          in ba_personas.dir_correo%type,
                                 p_rub_primario        in ba_personas.cod_rub_primario%type,
                                 p_cod_ciudad          in ba_ciudades.cod_ciudad%type,
                                 p_direccion           in ba_direcciones.direccion%type,
                                 p_fon_transferencia   in cr_inf_fondos.fon_transferencias%type,
                                 p_fon_salario         in cr_inf_fondos.fon_salario%type,
                                 p_fon_prestamo        in cr_inf_fondos.fon_prestamos%type,
                                 p_fon_vta_activos     in cr_inf_fondos.fon_vta_activos%type,
                                 p_fon_ren_financieras in cr_inf_fondos.fon_ren_financieras%type,
                                 p_fon_herencia        in cr_inf_fondos.fon_herencia%type,
                                 p_fon_ahorro          in cr_inf_fondos.fon_ahorro%type,
                                 p_fon_otros           in cr_inf_fondos.fon_otros%type,
                         p_tiene_doc           in varchar2,
                                 p_cod_persona         out ba_personas.cod_persona%type,
                                 p_cod_error           out number,
                                 p_mensaje             out varchar2,
                                 p_nro_documento_soli  in ba_personas.nro_documento%type,
                                 p_cod_onboarding      in varchar2,
                                 p_tip_cliente         out ba_onb_empresas.tip_cliente%type);

   PROCEDURE pr_alt_vin_fir_per_onb(p_nombres        in ba_personas.nom_completo%type,
                                   p_apellidos      in ba_personas.nom_completo%type,
                                   p_nro_documento  in ba_personas.nro_documento%type,
                                   p_tip_documento  in ba_personas.cod_tip_documento%type,
                                   p_cod_pais       in ba_personas.cod_pais%type,
                                   p_dir_correo     in ba_personas.dir_correo%type,
                                   p_rub_primario   in ba_personas.cod_rub_primario%type,
                                   p_num_celular    in varchar2,
                                   p_fec_nacimiento in ba_per_fisicas.fec_nacimiento%type,
                                   p_cod_sexo       in ba_per_fisicas.cod_sexo%type,
                                   p_tip_guardado   in varchar2, --F=(FIRMANTE) U=(USUARIO)
                                   p_fatca          in varchar2,
                                   p_cod_persona    out ba_personas.cod_persona%type,
                                   p_cod_error      out number,
                                   p_mensaje        out varchar2);

  PROCEDURE pr_alt_vinculo(p_cod_persona_emp in ba_personas.cod_persona%TYPE,
                           p_cod_persona     in ba_personas.cod_persona%TYPE,
                           p_tipo            in varchar2,
                           p_naturaleza      in ba_per_juridicas.naturaleza%TYPE,
                           p_cod_error       out number,
                           p_mensaje         out varchar2);

  /* Alta persona sin bloqueos en datos adicionales */
  PROCEDURE pr_alt_onb_persona(p_tipo              in ba_personas.tipo%type, -- fisica o juridica
                               p_nombres           in ba_personas.nom_completo%type,
                               p_apellidos         in ba_personas.nom_completo%type,
                               p_nro_documento     in ba_personas.nro_documento%type,
                               p_tip_documento     in ba_personas.cod_tip_documento%type,
                               p_est_civil         in ba_per_fisicas.est_civil%type,
                               p_fec_nacimiento    in ba_per_fisicas.fec_nacimiento%type,
                               p_cod_sexo          in ba_per_fisicas.cod_sexo%type,
                               p_fec_vto_documento in ba_personas.fec_vto_documento%type,
                               p_direccion         in ba_direcciones.direccion%type,
                               p_cod_ciudad        in ba_ciudades.cod_ciudad%type,
                               p_cod_pais_res      in ba_direcciones.cod_pais%type,
                               p_rub_primario      in ba_personas.cod_rub_primario%type,
                               p_num_celular       in ba_telefonos.telefono%type,
                               p_dir_correo        in ba_personas.dir_correo%type,
                               p_est_documento     in varchar2,
                               p_est_pru_vida      in varchar2,
                               p_cod_pai_nac       in ba_per_fisicas.cod_pai_nacionalidad%TYPE,
                               p_cod_ciu_nac       in ba_per_fisicas.cod_ciu_nacimiento%TYPE,
                               p_nro_casa          in ba_direcciones.numero%TYPE,
                               p_cal_secundaria    in ba_direcciones.direccion%TYPE,
                               p_cod_barrio        in ba_direcciones.cod_barrio%TYPE,
                               p_cod_departamento  in ba_direcciones.cod_departamento%TYPE,
                               p_piso              in ba_direcciones.piso%TYPE,
                               p_edificio          in ba_direcciones.edificio%TYPE,
                               p_referencias       in ba_direcciones.observacion%TYPE,
                               p_est_bancarizacion in varchar2,
                               p_usu_plataforma    in varchar2,
                               p_latitud           in ba_direcciones.latitud%TYPE DEFAULT null,
                               p_longitud          in ba_direcciones.longitud%TYPE DEFAULT null,
                               p_fec_emision       in ba_personas.fec_vto_documento%type DEFAULT null,
                               p_est_match_doc     in varchar2,
                               p_es_pep            in varchar2,
                               p_isocr             in varchar2 default null,
                               p_ocupacion         in ba_per_fisicas.cod_profesion%type,
                               p_cod_pais_doc      in ba_personas.cod_pais%TYPE,
                               p_cod_persona       out ba_personas.cod_persona%type,
                               p_est_verificacion  out varchar2,
                               p_cre_productos     out varchar2,
                               p_est_ios_excepcion out varchar2,
                               p_cod_error         out number,
                               p_mensaje           out varchar2);


  PROCEDURE pr_upd_dat_onboarding(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                  p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                  p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error      out number,
                                  p_mensaje        out varchar2);

  PROCEDURE pr_upd_ant_onb_telefono(p_cod_persona    in ba_personas.cod_persona%type,
                                     p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                     p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                     p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                     p_cod_error      out number,
                                     p_mensaje        out varchar2);

  PROCEDURE pr_upd_ant_onb_correo(p_cod_persona    in ba_personas.cod_persona%type,
                                   p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                   p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                   p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                   p_cod_error      out number,
                                   p_mensaje        out varchar2);

  PROCEDURE pr_ins_dat_onboarding(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                  p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                  p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error      out number,
                                  p_mensaje        out varchar2);

  procedure pr_act_dat_onb_persona(p_cod_persona      in ba_personas.cod_persona%type,
                                   p_profesion        in ba_personas.cod_rub_primario%type,
                                   p_direccion        in ba_direcciones.direccion%type,
                                   p_cod_pais_res     in ba_direcciones.cod_pais%type,
                                   p_cod_ciudad       in ba_direcciones.cod_ciudad%type,
                                   p_nro_casa         IN ba_direcciones.numero%TYPE,
                                   p_cal_secundaria   IN ba_direcciones.direccion%TYPE,
                                   p_cod_barrio       IN ba_direcciones.cod_barrio%TYPE,
                                   p_cod_departamento IN ba_direcciones.cod_departamento%TYPE,
                                   p_piso             IN ba_direcciones.piso%TYPE,
                                   p_edificio         IN ba_direcciones.edificio%TYPE,
                                   p_referencias      IN ba_direcciones.observacion%TYPE,
                                   p_telefono         in varchar2,
                                   p_correo           in ba_personas.dir_correo%type,
                                   p_latitud          in ba_direcciones.latitud%TYPE,
                                   p_longitud         in ba_direcciones.longitud%TYPE,
                                   p_cod_error        out number,
                                   p_mensaje          out varchar2);                                  

END pag_pla;
/
