create or replace package it.PAG_CDB is

  procedure pr_val_par_cdb(p_nro_documento ba_personas.nro_documento%type,
                           p_tip_documento ba_personas.cod_tip_documento%type,
                           p_cod_persona   out ba_personas.cod_persona%type,
                           p_parametro     out varchar,
                           p_correo        out varchar,
                           p_rubro         out varchar,
                           p_cod_error     out number,
                           p_men_error     out varchar);

  procedure pr_obt_sal_cta(p_nro_documento ba_personas.nro_documento%type,
                           p_tip_documento ba_personas.cod_tip_documento%type,
                           p_nro_cuenta    in out ah_cta_vistas.nro_cuenta%type,
                           p_moneda        out ah_cta_vistas.cod_moneda%type,
                           p_saldo         out number,
                           p_cod_error     out number,
                           p_men_error     out varchar);

  procedure pr_obt_dat_clientes(p_nro_documento  ba_personas.nro_documento%type,
                                p_tip_documento  ba_personas.cod_tip_documento%type,
                                p_cli_habilitado out varchar,
                                p_pri_nombre     out ba_per_fisicas.pri_nombre%type,
                                p_seg_nombre     out ba_per_fisicas.seg_nombre%type,
                                p_pri_apellido   out ba_per_fisicas.pri_apellido%type,
                                p_seg_apellido   out ba_per_fisicas.seg_apellido%type,
                                p_nro_doc        out ba_personas.nro_documento%type,
                                p_tip_doc        out ba_personas.cod_tip_documento%type,
                                p_fec_nacimiento out ba_per_fisicas.fec_nacimiento%type,
                                p_nacionalidad   out ba_paises.nacionalidad%type,
                                p_direccion      out ba_direcciones.direccion%type,
                                p_barrio         out ba_barrios.descripcion%type,
                                p_ciudad         out ba_ciudades.descripcion%type,
                                p_departamento   out ba_departamentos.descripcion%type,
                                p_num_telefono   out varchar,
                                p_correo         out ba_personas.dir_correo%type,
                                p_act_economica  out ge_actividades.descripcion%type,
                                p_profesion      out ba_profesiones.descripcion%type,
                                p_lug_trabajo    out cr_inf_laborales.lug_trabajo%type,
                                p_cod_error      out number,
                                p_men_error      out varchar);

  procedure pr_obt_cta_ahorros(p_nro_documento ba_personas.nro_documento%type,
                               p_tip_documento ba_personas.cod_tip_documento%type,
                               p_cta_lista     OUT SYS_REFCURSOR,
                               p_cod_error     out number,
                               p_men_error     out varchar);

end PAG_CDB;
/

