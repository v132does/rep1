CREATE OR REPLACE PROCEDURE IT.prt_gen_dat_altas(p_cod_procesadora IN VARCHAR2) IS
   /*Definicion de variables utilizadas*/
   c_tip_implementacion         ge_par_generales.tip_implementacion%TYPE := fug_obt_tip_implementacion;
   v_sec_env_datos              ta_env_cuentas.sec_env_datos%TYPE;
   v_fec_actual                 ge_calendarios.fec_actual%TYPE;
   v_nro_secuencia              ta_env_cuentas.sec_env_datos%TYPE;
   v_cod_persona                ba_personas.cod_persona%TYPE;
   v_cod_campana                ge_solicitudes.cod_campana%TYPE;
   v_des_ciudad                 ba_ciudades.descripcion%TYPE;
   v_des_ciudad2                ba_ciudades.descripcion%TYPE;
   v_cod_modulo                 ge_modalidades.cod_modulo%TYPE;
   v_cod_modalidad              ge_modalidades.cod_modalidad%TYPE;
   v_cod_cue_oficina            ba_oficinas.cod_oficina%TYPE;
   v_tip_envio                  ge_dir_envios.tip_envio%TYPE;
   v_dir_cliente                ta_env_cuentas.direccion%TYPE;
   v_dir_recibo                 ta_env_cuentas.dir_recibo%TYPE;
   v_observacion                ba_direcciones.observacion%TYPE;
   v_nro_solicitud              ge_solicitudes.nro_solicitud%TYPE;
   v_cod_per_codeudor           ba_personas.cod_persona%TYPE;
   v_nom_codeudor               ba_personas.nom_completo%TYPE;
   v_nro_doc_codeudor           ba_personas.nro_documento%TYPE;
   v_cod_cli_entidad            ta_solicitudes.cod_persona%TYPE;
   v_tip_persona_codeudor       ba_personas.tipo%TYPE;
   v_tip_doc_codeudor           ba_tip_documentos.abreviatura%TYPE;
   v_pri_nombre_codeudor        ba_per_fisicas.pri_nombre%TYPE;
   v_seg_nombre_codeudor        ba_per_fisicas.seg_nombre%TYPE;
   v_pri_apellido_codeudor      ba_per_fisicas.pri_apellido%TYPE;
   v_seg_apellido_codeudor      ba_per_fisicas.seg_apellido %TYPE;
   v_sexo_codeudor              ba_per_fisicas.cod_sexo%TYPE;
   v_fec_nacimiento_codeudor    ba_per_fisicas.fec_nacimiento%TYPE;
   v_lug_nacimiento_codeudor    ba_per_fisicas.cod_pai_nacionalidad%TYPE;
   v_est_civil_codeudor         ba_per_fisicas.est_civil%TYPE;
   v_ocupacion_codeudor         ba_profesiones.ref_externa%TYPE;
   v_dir_correo_codeudor        ba_personas.dir_correo%TYPE;
   v_cod_per_oficta             ba_personas.cod_persona%TYPE;
   v_nom_oficta                 ba_personas.nom_completo%TYPE;
   v_nro_doc_oficta             ba_personas.nro_documento%TYPE;
   v_tip_persona_oficta         ba_personas.tipo%TYPE;
   v_tip_doc_oficta_n           ba_tip_documentos.abreviatura%TYPE;
   v_pri_nombre_oficta          ba_per_fisicas.pri_nombre%TYPE;
   v_seg_nombre_oficta          ba_per_fisicas.seg_nombre%TYPE;
   v_pri_apellido_oficta        ba_per_fisicas.pri_apellido%TYPE;
   v_seg_apellido_oficta        ba_per_fisicas.seg_apellido %TYPE;
   v_sexo_oficta                ba_per_fisicas.cod_sexo%TYPE;
   v_fec_nacimiento_oficta      ba_per_fisicas.fec_nacimiento%TYPE;
   v_lug_nacimiento_oficta      ba_per_fisicas.cod_pai_nacionalidad%TYPE;
   v_est_civil_oficta           ba_per_fisicas.est_civil%TYPE;
   v_ocupacion_oficta           ba_profesiones.ref_externa%TYPE;
   v_dir_correo_oficta          ba_personas.dir_correo%TYPE;
   v_por_pag_minimo             ta_solicitudes.por_pag_minimo%TYPE;
   v_mto_min_pago               ta_solicitudes.mto_min_pago%TYPE;
   v_cod_per_promotor           ba_personas.cod_persona%TYPE;
   v_nom_promotor               ba_personas.nom_completo%TYPE;
   v_nro_doc_promotor           ba_personas.nro_documento%TYPE;
   v_tip_persona_promotor       ba_personas.tipo%TYPE;
   v_tip_doc_promotor           ba_tip_documentos.abreviatura%TYPE;
   v_pri_nombre_promotor        ba_per_fisicas.pri_nombre%TYPE;
   v_seg_nombre_promotor        ba_per_fisicas.seg_nombre%TYPE;
   v_pri_apellido_promotor      ba_per_fisicas.pri_apellido%TYPE;
   v_seg_apellido_promotor      ba_per_fisicas.seg_apellido %TYPE;
   v_sexo_promotor              ba_per_fisicas.cod_sexo%TYPE;
   v_fec_nacimiento_promotor    ba_per_fisicas.fec_nacimiento%TYPE;
   v_lug_nacimiento_promotor    ba_per_fisicas.cod_pai_nacionalidad%TYPE;
   v_est_civil_promotor         ba_per_fisicas.est_civil%TYPE;
   v_ocupacion_promotor         ba_profesiones.ref_externa%TYPE;
   v_dir_correo_promotor        ba_personas.dir_correo%TYPE;
   v_cod_banco                  ta_env_cuentas.cod_banco%TYPE;
   v_cod_sucursal               ta_sucursales.cod_sucursal%TYPE;
   v_cod_encargado              ta_env_cuentas.cod_encargado%TYPE;
   v_retencion                  ta_env_cuentas.cod_retencion%TYPE;
   v_cod_procesadora            ta_env_cuentas.cod_procesadora%TYPE;
   v_nro_doc_procesadora        ta_env_cuentas.nro_doc_procesadora%TYPE;
   v_nro_doc_cod_procesadora    ta_env_cuentas.nro_doc_procesadora%TYPE;
   v_nro_doc_adi_procesadora    ta_env_cuentas.nro_doc_procesadora%TYPE;
   v_cod_usu_promotor           ge_solicitudes.cod_usu_promotor%TYPE;
   v_cod_oficina                ge_par_generales.cod_ofi_matriz%TYPE;
   v_gas_no_aplicar             ta_cta_tarjetas_nov.gas_no_aplicar%type;
   v_aplica_impuesto            ta_env_cuentas.apl_impuesto%TYPE;
   v_plan_contado               ta_env_tarjetas.pla_contado%TYPE;
   v_ope_plan_contado           ta_env_tarjetas.ope_pla_contado%TYPE;
   v_plan_efectivo              ta_env_tarjetas.pla_ade_efectivo%type;
   v_ope_plan_efectivo          ta_env_tarjetas.ope_pla_ade_efectivo%type;
   v_imp_per_plan_contado       ta_env_tarjetas.imp_per_pla_contado%TYPE;
   v_por_per_plan_contado       ta_env_tarjetas.por_per_pla_contado%TYPE;
   v_plan_ade_efectivo          ta_env_tarjetas.pla_ade_efectivo%TYPE;
   v_ope_plan_ade_efectivo      ta_env_tarjetas.ope_pla_ade_efectivo%TYPE;
   v_impo_per_plan_ade_efectivo ta_env_tarjetas.imp_per_pla_ade_efectivo%TYPE;
   v_por_per_adelanto_efectivo  ta_env_tarjetas.por_per_ade_efectivo%TYPE;
   v_per_finan                  ta_env_tarjetas.pue_financiar%TYPE;
   v_usu_actualizacion          ta_solicitudes.usu_modificacion%TYPE;
   v_tipo_persona_titular       ba_personas.tipo%TYPE;
   v_tipo_persona_titular_inn   ba_personas.tipo%TYPE;
   v_cod_persona_titular        ba_personas.cod_persona%TYPE;
   v_tipo_documento_titular     ba_tip_documentos.abreviatura%TYPE;
   v_nro_documento_titular      ba_personas.nro_documento%TYPE;
   v_nombre_1_titular           ba_per_fisicas.pri_nombre%TYPE;
   v_nombre_2_titular           ba_per_fisicas.seg_nombre%TYPE;
   v_apellido_1_titular         ba_per_fisicas.pri_apellido%TYPE;
   v_apellido_2_titular         ba_per_fisicas.seg_apellido%TYPE;
   v_razon_social_titular       ba_per_juridicas.raz_social%TYPE;
   v_den_com_titular            ba_per_juridicas.nom_comercial%TYPE;
   v_pais_documento_titular     ba_per_fisicas.cod_pai_nacionalidad%TYPE;
   v_sexo_titular               ba_per_fisicas.cod_sexo%TYPE;
   v_fecha_nacimiento_titular   ba_per_fisicas.fec_nacimiento%TYPE;
   v_lugar_nacimiento_titular   ba_paises.descripcion%TYPE;
   v_ruc_para_extracto_titular  ba_personas.nro_documento%TYPE;
   v_estado_civil_titular       ba_per_fisicas.est_civil%TYPE;
   v_ocupacion_titular          ba_profesiones.ref_externa%TYPE;
   v_direccion_email_titular    ba_personas.dir_correo%TYPE;
   v_ciudad_direccion           ba_ciudades.ref_externa%TYPE;
   v_ciudad_direccion2          ba_ciudades.ref_externa%TYPE;
   v_zona_direccion             ba_barrios.cod_barrio%TYPE;
   v_departamento_direccion     ba_departamentos.ref_externa%TYPE;
   v_departamento_direccion2    ba_departamentos.ref_externa%TYPE;
   v_pais_direccion             ba_paises.ref_externa%TYPE;
   v_pais_direccion2            ba_paises.ref_externa%TYPE;
   v_tip_cobro                  ta_solicitudes.tip_cobro%TYPE;
   v_tipo_tarjeta               ta_env_tarjetas.tip_tarjeta%TYPE;
   v_lin_cuotas                 ta_cta_tarjetas.lin_cuotas%TYPE;
   v_nro_cuenta                 ge_cuentas.nro_cuenta%TYPE;
   v_nro_cta_debito             ge_cuentas.nro_cuenta%TYPE;
   v_tip_cta_debito             ge_cuentas.cod_modulo%TYPE;
   v_cod_for_pago               ta_env_cuentas.cod_for_pago%TYPE;

   v_cod_pro_bancard     VARCHAR2(10) := fug_obt_pardinamico('COD_PRO_BANCARD', NULL, NULL, NULL, NULL);
   v_cod_pro_bepsa       VARCHAR2(10) := fug_obt_pardinamico('COD_PRO_BEPSA', NULL, NULL, NULL, NULL);
   v_lugar               VARCHAR2(100) := 'INICIANDO';
   v_tel_cliente         VARCHAR2(25);
   v_dir_extendida       VARCHAR2(150);
   v_nro_celular_titular VARCHAR2(20);

   v_per_pag_minimo      varchar2(1 ) := 'N';
   v_per_tas_interes     varchar2(1 ) := 'N';
   v_per_cod_interes     number  (1 );
   v_mto_int_corriente   number  (16,2);
   v_per_cod_mora        number  (1 );
   v_mto_int_moratorio   number  (16,2);
   v_mto_int_compra      number  (16,2);
   v_per_cod_compra      number  (1 );
   v_mto_por_pago        number  (18,2);

   v_pla_contado           varchar2(2);
   v_ope_pla_contado       varchar2(1);
   v_pla_ade_efectivo      varchar2(2);
   v_ope_pla_ade_efectivo  varchar2(1);

   ---Variables -- RE DE-575
   v_nro_solicitud2 varchar2(15); -- variable para grabar en novedades de ta_env_cuentas
   v_edificio       ba_direcciones.edificio%type;
   v_piso           ba_direcciones.piso%type;
   v_dpto           ba_direcciones.departamento%type;
   --**--
   v_ret_extracto     ta_env_cuentas.ret_extracto%type;
   v_mot_ret_extracto ta_env_cuentas.cau_retencion%type;
   --**--
   v_plz_dur_tar_inn  number(3);
   v_ren_automatica   varchar2(1) := 'S';
   v_cargo varchar2(1):= fug_obt_pardinamico('COB_CARGOS'); --DYDMR-16300
   
   v_emp_adherida    ta_env_cuentas.emp_adherida%type;
   v_pre_embozada    ta_solicitudes.pre_embozada%type;
   -------------------------------------------------------------------------------------------------------------
   -------------------------------------------------------------------------------------------------------------
   -- CURSORES PARA BANCARD
   -------------------------------------------------------------------------------------------------------------
   -------------------------------------------------------------------------------------------------------------
   /*Cursor de Cuentas de Bancard*/
   CURSOR c_cuentas IS
      SELECT DISTINCT t.*,
                      a.cod_tip_tarjeta,
                      t.tip_cobro tip_cob,
                      a.tip_tas_financiacion,
                      a.tip_com_emision,
                      nvl(a.franqueo, 'N') franqueo,
                      decode(z.tipo, 'F', 1, 2) tip_cuenta,
                      substr(a.afinidad, 3, 2) cod_afinidad,
                      nvl(a.cta_vip, 'N') cta_vip,
                      a.tip_gas_financiero,
                      nvl(a.cta_personalizada, 'N') cta_personalizada,
                      a.tip_generacion,
                      z.nom_completo,
                      NULL costo_no_aplicar,
                      NULL aplica_impuesto,
                      t.usu_modificacion AS usu_actualizacion,
                      NULL tipo_pago,
                      NULL lin_cuotas,
                      NULL mto_int_compras,
                      'P' sigla,
                      a.ref_externa cod_afinidad_externa
        FROM tv_solicitudes t, ba_personas z, ta_tipos a
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (t.cod_oficina = a.cod_oficina OR a.cod_oficina IS NULL)
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND a.ref_externa IS NOT NULL
         AND t.tipo = 'T'
         AND z.cod_persona = t.cod_persona

      UNION
      SELECT DISTINCT t.*,
                      a.cod_tip_tarjeta,
                      t.tip_cobro tip_cob,
                      a.tip_tas_financiacion,
                      a.tip_com_emision,
                      nvl(a.franqueo, 'N') franqueo,
                      decode(z.tipo, 'F', 1, 2) tip_cuenta,
                      substr(a.afinidad, 3, 2) cod_afinidad,
                      a.cta_vip,
                      a.tip_gas_financiero,
                      a.cta_personalizada,
                      a.tip_generacion,
                      z.nom_completo,
                      NULL costo_no_aplicar,
                      NULL aplica_impuesto,
                      t.usu_modificacion AS usu_actualizacion,
                      NULL tipo_pago,
                      NULL lin_cuotas,
                      NULL mto_int_compras,
                      'P' sigla,
                      a.ref_externa cod_afinidad_externa
        FROM tv_solicitudes t, ba_personas z, ta_tipos a
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (t.cod_oficina = a.cod_oficina OR a.cod_oficina IS NULL)
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND a.ref_externa IS NOT NULL
         AND t.tipo = 'T'
         AND z.cod_persona = t.cod_persona
         AND EXISTS (SELECT 1
                FROM ta_tipos x
               WHERE t.cod_modulo = x.cod_modulo
                 AND t.cod_modalidad = x.cod_modalidad
                 AND t.afinidad = x.afinidad
                 AND nvl(t.sub_afinidad, 'ZZ') = nvl(x.sub_afinidad, 'ZZ')
                 AND a.cod_ent_procesadora = x.cod_ent_procesadora
                 AND x.tip_generacion IS NOT NULL)
      UNION
      SELECT DISTINCT t.*,
                      a.cod_tip_tarjeta,
                      t.tip_cobro tip_cob,
                      a.tip_tas_financiacion,
                      a.tip_com_emision,
                      nvl(a.franqueo, 'N') franqueo,
                      decode(z.tipo, 'F', 1, 2) tip_cuenta,
                      substr(a.afinidad, 3, 2) cod_afinidad,
                      a.cta_vip,
                      a.tip_gas_financiero,
                      a.cta_personalizada,
                      a.tip_generacion,
                      z.nom_completo,
                      NULL costo_no_aplicar,
                      NULL aplica_impuesto,
                      t.usu_modificacion AS usu_actualizacion,
                      NULL tipo_pago,
                      NULL lin_cuotas,
                      NULL mto_int_compras,
                      'P' sigla,
                      a.ref_externa cod_afinidad_externa
        FROM tv_solicitudes t, ba_personas z, ta_tipos a
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (t.cod_oficina = a.cod_oficina OR a.cod_oficina IS NULL)
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND a.ref_externa IS NOT NULL
         AND t.tipo = 'A'
         AND t.nro_solicitud IS NULL
         AND t.nro_cuenta IS NOT NULL
         AND z.cod_persona = t.cod_persona
         AND EXISTS (SELECT 1
                FROM ta_tipos x
               WHERE t.cod_modulo = x.cod_modulo
                 AND t.cod_modalidad = x.cod_modalidad
                 AND t.afinidad = x.afinidad
                 AND nvl(t.sub_afinidad, 'ZZ') = nvl(x.sub_afinidad, 'ZZ')
                 AND a.cod_ent_procesadora = x.cod_ent_procesadora
                 AND x.tip_generacion IS NOT NULL)
    AND a.nro_bin = (select max(tt.nro_bin)
                           from ta_tipos tt
                          where tt.cod_modulo = a.cod_modulo
                            and tt.cod_modalidad = a.cod_modalidad
                            and tt.afinidad = a.afinidad
                            and NVL(tt.sub_afinidad,'ZZ') = NVL(a.sub_afinidad,'ZZ')
                            and tt.cod_ent_procesadora = a.cod_ent_procesadora);

   /********* Cursor para Novedades de Bancard**********/
   --Verificar la modificaciones
   CURSOR novedades IS
      SELECT DISTINCT t.cod_tip_cierre,
                      t.nro_cuenta,
                      t.lin_cuotas,
                      t.tip_cobro,
                      t.deb_automatico,
                      t.dir_envio,
                      t.nro_cta_debito,
                      t.usu_modificacion,
                      t.nro_documento,
                      t.lin_credito,
                      t.nro_tarjeta,
                      t.tel_principal,
                      j.cod_modulo,
                      j.cod_modalidad,
                      a.tip_generacion,
                      a.ref_externa cod_afinidad_externa,
                      j.nro_solicitud,
                      c.cod_persona,
                      t.cat_riesgo,
                      a.afinidad,
                      a.sub_afinidad,
                      'P' bloque,
                      a.tas_personalizada,
                      null  pla_ope_mto_contado ,
                      null  pla_ope_por_contado ,
                      null  pla_ope_mto_adelanto,
                      null  pla_ope_por_adelanto,
                      t.por_pag_minimo,
                      t.mto_min_pag_minimo,
                      t.mto_fij_pag_minimo,
                      t.tas_int_corriente,
                      t.tas_int_mora,
                      t.tas_int_compra,
                      -- MP-2298-AUT_BAJA_TARJETAS
                      (select estado
                         from ta_can_aut_tarjetas m
                        where m.nro_cuenta = j.nro_cuenta
                          and m.fecha = t.fecha
                          and m.estado in ('P','C')) mot_nov_cuenta,
                      t.cob_cargo, --MDPCLACLI-3
                      t.ret_extracto,
                      t.mot_ret_extracto
        FROM ta_tipos a, ta_cta_tarjetas j, ta_cta_tarjetas_nov t, ge_cta_clientes c
       WHERE nvl(t.enviado, 'N') <> 'S'
         AND nvl(t.aprobado, 'N') = 'S'
         AND j.nro_cuenta = t.nro_cuenta
         AND a.cod_modulo = j.cod_modulo
         AND a.cod_modalidad = j.cod_modalidad
         AND a.afinidad = j.afinidad
         AND nvl(a.sub_afinidad, 'ZZ') = nvl(j.sub_afinidad, 'ZZ')
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND c.nro_cuenta = t.nro_cuenta
         and j.estado != 'C'
       union all
      select distinct null cod_tip_cierre   ,
                      t.nro_cuenta          ,
                      null lin_cuotas       ,
                      null tip_cobro        ,
                      null deb_automatico   ,
                      null dir_envio        ,
                      null nro_cta_debito   ,
                      t.usu_modificacion    ,
                      null nro_documento    ,
                      null lin_credito      ,
                      t.nro_tarjeta         ,
                      null tel_principal    ,
                      b.cod_modulo          ,
                      b.cod_modalidad       ,
                      a.tip_generacion      ,
                      a.ref_externa         ,
                      b.nro_solicitud       ,
                      c.cod_persona         ,
                      null cat_riesgo       ,
                      a.afinidad            ,
                      a.sub_afinidad        ,
                      'A' bloque            ,
                      a.tas_personalizada   ,
                      t.pla_ope_mto_contado ,
                      t.pla_ope_por_contado ,
                      t.pla_ope_mto_adelanto,
                      t.pla_ope_por_adelanto,
                      null,
                      null,
                      null,
                      null,
                      null,
                      null,
                      null mot_nov_cuenta,
                      null,
                      null,
                      null
        from ta_tipos a, ta_tarjetas j, ta_tarjetas_nov t, ge_cta_clientes c, ta_cta_tarjetas b
       where nvl(t.enviado , 'N')      <> 'S'
         and nvl(t.aprobado, 'N')      = 'S'
         and j.nro_cuenta              = b.nro_cuenta
         and a.cod_modulo              = b.cod_modulo
         and a.cod_modalidad           = b.cod_modalidad
         and a.afinidad                = b.afinidad
         and nvl(a.sub_afinidad, 'ZZ') = nvl(b.sub_afinidad, 'ZZ')
         and j.nro_cuenta              = t.nro_cuenta
         and c.nro_cuenta              = t.nro_cuenta
         and c.cod_persona             = j.cod_persona
         and j.nro_tarjeta             = t.nro_tarjeta
         and c.relacion                = 'A'
         and b.estado                  != 'C'
         and a.cod_ent_procesadora     = v_cod_procesadora;

   /******Cursor de Tarjetas de Bancard**********************************************/
   --personas fisicas--
   CURSOR c_tarjetas_adicional IS
      SELECT DISTINCT r.cod_persona,
                      r.nom_embozado,
                      r.nro_solicitud,
                      z.nro_documento,
                      'F' tipo,
                      y.pri_apellido || ', ' || y.pri_nombre nom_completo,
                      a.afinidad afinidad,
                      a.cod_tip_tarjeta,
                      a.tip_generacion,
                      a.plz_dur_tarjeta,
                      a.tas_personalizada,

                      r.pla_ope_por_contado,
                      r.pla_ope_mto_contado,
                      r.pla_ope_por_adelanto,
                      r.pla_ope_mto_adelanto,
                      t.mto_min_pago,

                      NULL per_finan,
                      t.usu_modificacion AS usu_actualizacion,
                      t.nro_cuenta,
                      --Para los datos de adicionales
                      y.pri_nombre,
                      y.seg_nombre,
                      y.pri_apellido,
                      y.seg_apellido,
                      y.cod_sexo,
                      CASE TRIM(w.abreviatura)
                         WHEN 'CI' THEN
                          'CIP'
                         ELSE
                          TRIM(w.abreviatura)
                      END AS tip_documento,
                      y.fec_nacimiento,
                      decode(y.est_civil, 'S', 'S', 'C', 'C', 'V', 'V', 'D', 'D', 'B', 'C', 'S') est_civil,
                      z.dir_correo,
                      a.ref_externa cod_afinidad_externa
                      --Para paises y Ocupacion
                     ,
                      p.ref_externa cod_pais,
                      x.ref_externa cod_ocupacion,
                      t.tip_plastico
        FROM tv_solicitudes     t,
             ta_sol_adicionales r,
             ba_personas        z,
             ba_per_fisicas     y,
             ta_tipos           a,
             ba_profesiones     x,
             ba_paises          p,
             ba_tip_documentos  w
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (t.cod_oficina = a.cod_oficina OR a.cod_oficina IS NULL)
         AND ((c_tip_implementacion <> 1 AND nvl(t.cod_campana, 0) = nvl(a.cod_campana, 0)) OR
             c_tip_implementacion = 1)
         AND a.ref_externa IS NOT NULL
         AND a.tip_generacion IS NOT NULL
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND t.tipo = 'A'
         AND (r.nro_solicitud = t.nro_solicitud OR
             (r.nro_cuenta = t.nro_cuenta AND r.nro_solicitud IS NULL))
         AND r.cod_persona = t.cod_persona
         AND (r.nro_solicitud = v_nro_solicitud OR
             (r.nro_cuenta = v_nro_cuenta AND r.nro_solicitud IS NULL))
         AND ((r.cod_persona = v_cod_persona AND r.nro_solicitud IS NULL) OR
             r.nro_solicitud IS NOT NULL)
         AND z.cod_persona = r.cod_persona
         AND z.cod_tip_documento = w.cod_tip_documento
         AND y.cod_persona = r.cod_persona
         AND y.cod_profesion = x.cod_profesion(+)
         AND y.cod_pai_nacionalidad = p.cod_pais(+)
     AND a.nro_bin = (select max(tt.nro_bin) from ta_tipos tt
                          where tt.cod_modulo = a.cod_modulo
                            and tt.cod_modalidad = a.cod_modalidad
                            and tt.afinidad = a.afinidad
                            and NVL(tt.sub_afinidad,'ZZ') = NVL(a.sub_afinidad,'ZZ')
                            and tt.cod_ent_procesadora = a.cod_ent_procesadora)
      UNION
      --personas fisicas / CON campaña --
      SELECT DISTINCT r.cod_persona,
                      r.nom_embozado,
                      r.nro_solicitud,
                      z.nro_documento,
                      'F' tipo,
                      y.pri_apellido || ', ' || y.pri_nombre nom_completo,
                      a.afinidad afinidad,
                      a.cod_tip_tarjeta,
                      a.tip_generacion,
                      a.plz_dur_tarjeta,
                      a.tas_personalizada,
                      r.pla_ope_por_contado,
                      r.pla_ope_mto_contado,
                      r.pla_ope_por_adelanto,
                      r.pla_ope_mto_adelanto,
                      t.mto_min_pago,
                      NULL per_finan,
                      t.usu_modificacion AS usu_actualizacion,
                      t.nro_cuenta,
                      --Para los datos de adicionales
                      y.pri_nombre,
                      y.seg_nombre,
                      y.pri_apellido,
                      y.seg_apellido,
                      y.cod_sexo,
                      CASE TRIM(w.abreviatura)
                         WHEN 'CI' THEN
                          'CIP'
                         ELSE
                          TRIM(w.abreviatura)
                      END AS tip_documento,
                      y.fec_nacimiento,
                      decode(y.est_civil, 'S', 'S', 'C', 'C', 'V', 'V', 'D', 'D', 'B', 'C', 'S'),
                      z.dir_correo,
                      a.ref_externa cod_afinidad_externa
                      --Para paises y Ocupacion
                     ,
                      p.ref_externa cod_pais,
                      x.ref_externa cod_ocupacion,
                      t.tip_plastico
        FROM tv_solicitudes     t,
             ta_sol_adicionales r,
             ba_personas        z,
             ba_per_fisicas     y,
             ta_tipos           a,
             ba_profesiones     x,
             ba_paises          p,
             ba_tip_documentos  w
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (t.cod_oficina = a.cod_oficina OR a.cod_oficina IS NULL)
         AND ((c_tip_implementacion <> 1 AND nvl(t.cod_campana, 0) <> nvl(a.cod_campana, 0)) OR
             c_tip_implementacion = 1)
         AND a.ref_externa IS NOT NULL
         AND a.tip_generacion IS NOT NULL
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND t.tipo = 'A'
         AND (r.nro_solicitud = t.nro_solicitud OR
             (r.nro_cuenta = t.nro_cuenta AND r.nro_solicitud IS NULL))
         AND r.cod_persona = t.cod_persona
         AND (r.nro_solicitud = v_nro_solicitud OR
             (r.nro_cuenta = v_nro_cuenta AND r.nro_solicitud IS NULL))
         AND ((r.cod_persona = v_cod_persona AND r.nro_solicitud IS NULL) OR
             r.nro_solicitud IS NOT NULL)
         AND z.cod_persona = r.cod_persona
         AND z.cod_tip_documento = w.cod_tip_documento
         AND y.cod_persona = r.cod_persona
         AND y.cod_profesion = x.cod_profesion(+)
         AND y.cod_pai_nacionalidad = p.cod_pais(+)
         AND EXISTS (SELECT 1
                FROM ta_tipos x
               WHERE t.cod_modulo = x.cod_modulo
                 AND t.cod_modalidad = x.cod_modalidad
                 AND t.afinidad = x.afinidad
                 AND nvl(t.sub_afinidad, 'ZZ') = nvl(x.sub_afinidad, 'ZZ')
                 AND a.cod_ent_procesadora = x.cod_ent_procesadora
                 AND t.cod_campana <> nvl(x.cod_campana, 0)
                 AND x.cod_campana IS NULL)
         AND NOT EXISTS (SELECT 1
                FROM ta_tipos x
               WHERE t.cod_modulo = x.cod_modulo
                 AND t.cod_modalidad = x.cod_modalidad
                 AND t.afinidad = x.afinidad
                 AND nvl(t.sub_afinidad, 'ZZ') = nvl(x.sub_afinidad, 'ZZ')
                 AND a.cod_ent_procesadora = x.cod_ent_procesadora
                 AND t.cod_campana = nvl(x.cod_campana, 0));

   --personas fisicas--
   CURSOR c_tarjetas_principal IS
      SELECT DISTINCT t.cod_persona,
                      t.nom_embozado,
                      t.nro_solicitud,
                      z.nro_documento,
                      'F' tipo,
                      y.pri_apellido || ', ' || y.pri_nombre nom_completo,
                      a.afinidad afinidad,
                      a.cod_tip_tarjeta,
                      a.tip_generacion,
                      a.plz_dur_tarjeta,
                      a.ref_externa cod_afinidad_externa,
                      NULL plan_contado,
                      NULL ope_plan_contado,
                      NULL imp_per_plan_contado,
                      NULL por_pre_plan_contado,
                      NULL plan_ade_efectivo,
                      NULL ope_plan_ade_efectivo,
                      NULL impo_per_plan_ade_efectivo,
                      NULL por_per_adelanto_efectivo,
                      NULL per_finan,
                      t.usu_modificacion AS usu_actualizacion,
                      t.nro_cuenta,
                      --Para paises y Ocupacion
                      p.ref_externa cod_pais,
                      x.ref_externa cod_ocupacion,
                      t.tip_plastico
        FROM tv_solicitudes t,
             ba_personas    z,
             ba_per_fisicas y,
             ta_tipos       a
             --Para paises y Ocupacion
            ,
             ba_paises      p,
             ba_profesiones x
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (t.cod_oficina = a.cod_oficina OR a.cod_oficina IS NULL)
         AND ((c_tip_implementacion <> 1 AND nvl(t.cod_campana, 0) = nvl(a.cod_campana, 0)) OR
             c_tip_implementacion = 1)
         AND a.ref_externa IS NOT NULL
         AND a.tip_generacion IS NOT NULL
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND t.tipo = 'T'
         AND t.nro_solicitud = v_nro_solicitud
         AND z.cod_persona = t.cod_persona
         AND y.cod_persona = t.cod_persona
         AND y.cod_pai_nacionalidad = p.cod_pais(+)
         AND y.cod_profesion = x.cod_profesion(+)
      UNION -- PARA LAS PERSONAS JURIDICAS NO SE IMPRIME PLASTICO
      SELECT DISTINCT t.cod_persona,
                      t.nom_embozado,
                      t.nro_solicitud,
                      z.nro_documento,
                      '0' tipo,
                      y.raz_social nom_completo,
                      a.afinidad afinidad,
                      a.cod_tip_tarjeta,
                      a.tip_generacion,
                      a.plz_dur_tarjeta,
                      a.ref_externa cod_afinidad_externa,
                      NULL plan_contado,
                      NULL ope_plan_contado,
                      NULL imp_per_plan_contado,
                      NULL por_pre_plan_contado,
                      NULL plan_ade_efectivo,
                      NULL ope_plan_ade_efectivo,
                      NULL impo_per_plan_ade_efectivo,
                      NULL por_per_adelanto_efectivo,
                      NULL per_finan,
                      t.usu_modificacion AS usu_actualizacion,
                      t.nro_cuenta,
                      --Para paises y Ocupacion
                      NULL cod_pais,
                      NULL cod_ocupacion,
                      t.tip_plastico
        FROM tv_solicitudes t, ba_personas z, ba_per_juridicas y, ta_tipos a
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (t.cod_oficina = a.cod_oficina OR a.cod_oficina IS NULL)
         AND ((c_tip_implementacion <> 1 AND nvl(t.cod_campana, 0) <> nvl(a.cod_campana, 0)) OR
             c_tip_implementacion = 1)
         AND a.ref_externa IS NOT NULL
         AND a.tip_generacion IS NOT NULL
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND t.tipo = 'T'
         AND t.nro_solicitud = v_nro_solicitud
         AND z.cod_persona = t.cod_persona
         AND y.cod_persona = t.cod_persona
       ORDER BY 3, 6;

   ----------------------------FINALIZA BANCARD-----------------------------------------------------------------
   -------------------------------------------------------------------------------------------------------------
   -------------------------------------------------------------------------------------------------------------
   -- CURSORES PARA BEPSA
   -------------------------------------------------------------------------------------------------------------
   CURSOR c_cuentas_bep IS
      SELECT DISTINCT t.*,
                      a.cod_tip_tarjeta,
                      t.tip_cobro            tip_cob,
                      a.tip_tas_financiacion,
                      a.tip_com_emision,
                      a.franqueo,
                      a.tip_cuenta,
                      a.afinidad             cod_afinidad,
                      a.cta_vip,
                      a.tip_gas_financiero,
                      a.cta_personalizada,
                      a.tip_generacion,
                      z.nom_completo,
                      z.nro_documento,
                      z.tipo                 tipo_per
        FROM tv_solicitudes t, ba_personas z, ta_tipos a
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND t.tipo = 'T' -- por titulares, porque en tv_solicitudes hay adicionales tambien
         AND z.cod_persona = t.cod_persona
         AND EXISTS (SELECT 1
                FROM ta_tipos x
               WHERE x.cod_modalidad = a.cod_modalidad
                 AND x.cod_modulo = a.cod_modulo
                 AND x.afinidad = a.afinidad
                 AND nvl(x.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
                 AND x.nro_bin = a.nro_bin
                 AND x.tip_generacion IS NOT NULL);
   --principales--
   CURSOR c_tarjetas_principal_bep IS
      SELECT DISTINCT t.cod_persona,
                      t.nom_embozado,
                      t.nro_solicitud,
                      z.nro_documento,
                      '1' tipo,
                      y.pri_apellido || ', ' || y.pri_nombre nom_completo,
                      a.afinidad afinidad,
                      a.cod_tip_tarjeta,
                      a.tip_generacion,
                      a.plz_dur_tarjeta
        FROM tv_solicitudes t, ba_personas z, ba_per_fisicas y, ta_tipos a
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (c_tip_implementacion <> 1 OR nvl(t.cod_campana, 1) = nvl(a.cod_campana, 1))
         AND a.tip_generacion IS NOT NULL
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND t.tipo = 'T'
         AND t.nro_solicitud = v_nro_solicitud
         AND z.cod_persona = t.cod_persona
         AND y.cod_persona = t.cod_persona
       ORDER BY 3, 6;

   --adicionales--
   CURSOR c_tarjetas_adicional_bep IS
      SELECT DISTINCT r.cod_persona,
                      r.nom_embozado,
                      r.nro_solicitud,
                      z.nro_documento,
                      '3' tipo,
                      y.pri_apellido || ', ' || y.pri_nombre nom_completo,
                      a.afinidad afinidad,
                      a.cod_tip_tarjeta,
                      a.tip_generacion,
                      a.plz_dur_tarjeta
        FROM tv_solicitudes t, ge_sol_adicionales r, ba_personas z, ba_per_fisicas y, ta_tipos a
       WHERE t.cod_estado = 'APR'
         AND t.cod_modulo = a.cod_modulo
         AND t.cod_modalidad = a.cod_modalidad
         AND t.afinidad = a.afinidad
         AND nvl(t.sub_afinidad, 'ZZ') = nvl(a.sub_afinidad, 'ZZ')
         AND (c_tip_implementacion <> 1 OR nvl(t.cod_campana, 1) = nvl(a.cod_campana, 1))
         AND a.tip_generacion IS NOT NULL
         AND a.cod_ent_procesadora = v_cod_procesadora
         AND t.tipo = 'A'
         AND r.nro_solicitud = t.nro_solicitud
         AND r.nro_solicitud = v_nro_solicitud
         AND z.cod_persona = r.cod_persona
         AND y.cod_persona = r.cod_persona;

   ---------------------------------------------------------------------------------------------------
   PROCEDURE lp_dir_envio IS
      v_cod_departamento  ba_departamentos.cod_departamento%type := NULL;
      v_cod_departamento2 ba_departamentos.cod_departamento%type := NULL;
   BEGIN
      /*Carga los datos de la direccion y telefono de envio*/
      v_lugar := 'lp_dir_envio';
      ---0. limpio los valores a leer ------------------------------------
      v_tip_envio               := NULL;
      v_dir_cliente             := NULL;
      v_dir_recibo              := NULL;
      v_dir_extendida           := NULL;
      v_des_ciudad              := NULL;
      v_des_ciudad2             := NULL;
      v_tel_cliente             := NULL;
      v_observacion             := NULL;
      v_ciudad_direccion        := NULL;
      v_ciudad_direccion2       := NULL;
      v_zona_direccion          := NULL;
      v_departamento_direccion  := NULL;
      v_departamento_direccion2 := NULL;
      v_pais_direccion          := NULL;
      v_pais_direccion2         := NULL;
      v_edificio                := NULL;
      v_piso                    := NULL;
      v_dpto                    := NULL;
      ---1. Leo la vista de acuerdo a los datos que me pasa --------------
      begin

      SELECT e.tip_envio,
             decode(e.tip_envio, 'D', d.direccion || ' ' || d.numero||' '||d.dir_lateral, 'C',
                    'CASILLERO: ' || e.referencia, 'A', 'CASILLA DE CORREO: ' || e.referencia, 'R',
                    'RETENER EN ' || o.descripcion, 'N', 'NO IMPRIMIR') dir_envio,
             c.descripcion des_ciudad,
             c2.descripcion des_ciudad2,
             t.area || decode(t.area, NULL, NULL, '-') || t.telefono tel_cliente,
             d.observacion,
             c.ref_externa cod_ref_ciudad,
             c2.ref_externa cod_ref_ciudad2,
             b.cod_barrio,
             nvl(de.ref_externa, 11) cod_ref_departamento, --codigo de departamento de la procesadora, x defecto 11=central
             nvl(de2.ref_externa, 11) cod_ref_departamento2, --codigo de departamento de la procesadora, x defecto 11=central
             p.ref_externa cod_ref_pais,
             p2.ref_externa cod_ref_pais2,
             de.cod_departamento,
             de2.cod_departamento,
             d.edificio,
             d.piso,
             d.departamento
        INTO v_tip_envio,
             v_dir_cliente,
             v_des_ciudad,
             v_des_ciudad2,
             v_tel_cliente,
             v_observacion,
             v_ciudad_direccion,
             v_ciudad_direccion2,
             v_zona_direccion,
             v_departamento_direccion,
             v_departamento_direccion2,
             v_pais_direccion,
             v_pais_direccion2,
             v_cod_departamento,
             v_cod_departamento2,
             v_edificio,
             v_piso,
             v_dpto
        FROM ba_barrios         b,
             ba_departamentos   de,
             ba_departamentos   de2,
             ba_ciudades        c,
             ba_ciudades        c2,
             ba_paises          p,
             ba_paises          p2,
             ba_telefonos       t,
             ba_direcciones     d,
             ge_dir_retenciones o,
             ge_dir_envios      e
       WHERE p.cod_pais(+) = d.cod_pais
         AND de.cod_departamento(+) = c.cod_departamento
         AND c.cod_pais(+) = d.cod_pais
         AND c.cod_ciudad(+) = d.cod_ciudad
         AND b.cod_pais(+) = d.cod_pais
         AND b.cod_ciudad(+) = d.cod_ciudad
         AND b.cod_barrio(+) = d.cod_barrio
            --
         AND p2.cod_pais(+) = o.cod_pais
         AND de2.cod_departamento(+) = c2.cod_departamento
         AND c2.cod_pais(+) = o.cod_pais
         AND c2.cod_ciudad(+) = o.cod_ciudad
            --
         AND t.cod_persona(+) = e.cod_persona
         AND t.principal(+) = 'S'
         AND d.cod_persona(+) = e.cod_persona
         AND d.cod_direccion(+) = e.referencia
         AND o.cod_dir_retencion(+) = e.referencia
         AND e.cod_persona = v_cod_persona_titular
         AND (e.nro_cuenta = v_nro_cuenta OR e.nro_cuenta IS NULL)
         AND rownum = 1;
      exception
        when no_data_found then
          null;
      end;

      ---Si el tipo de envio es Retencion asignar los valores de ciudad y pais a las variables correspondientes
      IF v_tip_envio = 'R' THEN
         v_des_ciudad             := v_des_ciudad2;
         v_ciudad_direccion       := v_ciudad_direccion2;
         v_departamento_direccion := v_departamento_direccion2;
         v_pais_direccion         := v_pais_direccion2;
      END IF;
      --
      IF v_tel_cliente IS NULL THEN
         BEGIN
            SELECT x.area || decode(x.area, NULL, NULL, '-') || x.telefono
              INTO v_tel_cliente
              FROM ba_telefonos x
             WHERE x.cod_persona = v_cod_persona_titular
               AND x.principal = 'N'
               AND x.cod_telefono = (SELECT MIN(y.cod_telefono)
                                       FROM ba_telefonos y
                                      WHERE y.cod_persona = v_cod_persona_titular
                                        AND y.principal = 'N'
                                        AND y.telefono IS NOT NULL)
               AND rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_tel_cliente := NULL;
         END;
      END IF;

      --Busco la direccion de recibo del plastico, viene de la solicitud
      IF v_nro_solicitud IS NOT NULL THEN
         BEGIN
            SELECT substr(decode(t.tip_envio, 'D', d.direccion || ' ' || d.numero|| ' ' ||d.dir_lateral, 'C',
                                 'CASILLERO: ' || t.referencia, 'A',
                                 'CASILLA DE CORREO: ' || t.referencia, 'R',
                                 'RETENER EN ' || o.descripcion), 1, 35) dir_recibo
              INTO v_dir_recibo
              FROM ba_direcciones d, ge_dir_retenciones o, ta_solicitudes t
             WHERE t.nro_solicitud = v_nro_solicitud
               AND ((t.tip_envio = 'D' AND d.cod_persona = t.cod_persona AND
                   d.cod_direccion = t.referencia) OR
                   (t.tip_envio = 'R' AND o.cod_dir_retencion = t.referencia))
               AND rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_dir_recibo := NULL;
         END;
      ELSE
         IF v_nro_cuenta IS NOT NULL THEN
            BEGIN
               SELECT substr(decode(e.tip_envio, 'D', d.direccion || ' ' || d.numero|| ' ' ||d.dir_lateral, 'C',
                                    'CASILLERO: ' || e.referencia, 'A',
                                    'CASILLA DE CORREO: ' || e.referencia, 'R',
                                    'RETENER EN ' || o.descripcion), 1, 35) dir_recibo
                 INTO v_dir_recibo
                 FROM ba_direcciones d, ge_dir_retenciones o, ge_dir_envios e, ta_tarjetas t
                WHERE t.nro_cuenta = v_nro_cuenta
                  AND t.cod_persona = v_cod_persona_titular
                  AND e.cod_persona = t.cod_persona
                  AND e.tip_envio = t.tip_envio
                  AND e.referencia = t.referencia
                  AND (e.nro_cuenta = v_nro_cuenta OR e.nro_cuenta IS NULL)
                  AND d.cod_persona(+) = e.cod_persona
                  AND d.cod_direccion(+) = e.referencia
                  AND o.cod_dir_retencion(+) = e.referencia
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_dir_recibo := NULL;
            END;
         END IF;
      END IF;
      --
      IF v_dir_recibo IS NULL THEN
         v_dir_recibo := substr(v_dir_cliente, 1, 35);
      END IF;

      -- Armar la direccion extendida--
      SELECT substr(v_dir_cliente ||decode(v_edificio,null,null,' Edif. ')||v_edificio
             || decode(v_piso,null,null,' Piso. ')|| v_piso
             || decode(v_dpto,null,null,' Dpto. ')|| v_dpto
             || decode(v_des_ciudad, NULL, NULL, ' - ') || v_des_ciudad, 1, 150)
        INTO v_dir_extendida
        FROM dual;
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      IF nvl(v_cod_departamento,11) = 11 AND v_ciudad_direccion IS NULL THEN
         v_ciudad_direccion  := 1;
      END IF;
      IF nvl(v_cod_departamento2,11) = 11 AND v_ciudad_direccion2 IS NULL THEN
         v_ciudad_direccion2 := 1;
      END IF;
      ---
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 ' Al Obt.Dir.envio: ' || v_cod_persona_titular ||
                                 ' Cuenta: '|| v_nro_cuenta);
   END lp_dir_envio;
   ---------------------------------------------------------------------------------------------------
   PROCEDURE lp_dir_envio_nov IS
      v_cod_departamento  ba_departamentos.cod_departamento%type := NULL;
      v_cod_departamento2 ba_departamentos.cod_departamento%type := NULL;
   BEGIN
      /*Carga los datos de la direccion y telefono de envio*/
      v_lugar := 'lp_dir_envio_nov';
      ---0. limpio los valores a leer ------------------------------------
      v_tip_envio               := NULL;
      v_dir_cliente             := NULL;
      v_dir_recibo              := NULL;
      v_dir_extendida           := NULL;
      v_des_ciudad              := NULL;
      v_des_ciudad2             := NULL;
      v_tel_cliente             := NULL;
      v_observacion             := NULL;
      v_ciudad_direccion        := NULL;
      v_ciudad_direccion2       := NULL;
      v_zona_direccion          := NULL;
      v_departamento_direccion  := NULL;
      v_departamento_direccion2 := NULL;
      v_pais_direccion          := NULL;
      v_pais_direccion2         := NULL;
      v_edificio                := NULL;
      v_piso                    := NULL;
      v_dpto                    := NULL;
      ---1. Leo la vista de acuerdo a los datos que me pasa --------------
      begin
      SELECT e.tip_envio,
             decode(e.tip_envio, 'D', d.direccion || ' ' || d.numero||' '||d.dir_lateral, 'C',
                    'CASILLERO: ' || e.referencia, 'A', 'CASILLA DE CORREO: ' || e.referencia, 'R',
                    'RETENER EN ' || o.descripcion, 'N', 'NO IMPRIMIR') dir_envio,
             c.descripcion des_ciudad,
             c2.descripcion des_ciudad2,
             t.area || decode(t.area, NULL, NULL, '-') || t.telefono tel_cliente,
             d.observacion,
             c.ref_externa cod_ref_ciudad,
             c2.ref_externa cod_ref_ciudad2,
             b.cod_barrio,
             nvl(de.ref_externa, 11) cod_ref_departamento, --codigo de departamento de la procesadora, x defecto 11=central
             nvl(de2.ref_externa, 11) cod_ref_departamento2, --codigo de departamento de la procesadora, x defecto 11=central
             p.ref_externa cod_ref_pais,
             p2.ref_externa cod_ref_pais2,
             de.cod_departamento,
             de2.cod_departamento,
             d.edificio,
             d.piso,
             d.departamento
        INTO v_tip_envio,
             v_dir_cliente,
             v_des_ciudad,
             v_des_ciudad2,
             v_tel_cliente,
             v_observacion,
             v_ciudad_direccion,
             v_ciudad_direccion2,
             v_zona_direccion,
             v_departamento_direccion,
             v_departamento_direccion2,
             v_pais_direccion,
             v_pais_direccion2,
             v_cod_departamento,
             v_cod_departamento2,
             v_edificio,
             v_piso,
             v_dpto
        FROM ba_barrios         b,
             ba_departamentos   de,
             ba_departamentos   de2,
             ba_ciudades        c,
             ba_ciudades        c2,
             ba_paises          p,
             ba_paises          p2,
             ba_telefonos       t,
             ba_direcciones     d,
             ge_dir_retenciones o,
             ge_dir_envios      e
       WHERE p.cod_pais(+) = d.cod_pais
         AND de.cod_departamento(+) = c.cod_departamento
         AND c.cod_pais(+) = d.cod_pais
         AND c.cod_ciudad(+) = d.cod_ciudad
         AND b.cod_pais(+) = d.cod_pais
         AND b.cod_ciudad(+) = d.cod_ciudad
         AND b.cod_barrio(+) = d.cod_barrio
            --
         AND p2.cod_pais(+) = o.cod_pais
         AND de2.cod_departamento(+) = c2.cod_departamento
         AND c2.cod_pais(+) = o.cod_pais
         AND c2.cod_ciudad(+) = o.cod_ciudad
            --
         AND t.cod_persona(+) = e.cod_persona
         AND t.principal(+) = 'S'
         AND d.cod_persona(+) = e.cod_persona
         AND d.cod_direccion(+) = e.referencia
         AND o.cod_dir_retencion(+) = e.referencia
         AND e.cod_persona = v_cod_persona_titular
         AND e.nro_cuenta = v_nro_cuenta
         AND rownum = 1;
      exception
        when no_data_found then
          null;
      end;

      ---Si el tipo de envio es Retencion asignar los valores de ciudad y pais a las variables correspondientes
      IF v_tip_envio = 'R' THEN
         v_des_ciudad             := v_des_ciudad2;
         v_ciudad_direccion       := v_ciudad_direccion2;
         v_departamento_direccion := v_departamento_direccion2;
         v_pais_direccion         := v_pais_direccion2;
      END IF;
      --
      IF v_tel_cliente IS NULL THEN
         BEGIN
            SELECT x.area || decode(x.area, NULL, NULL, '-') || x.telefono
              INTO v_tel_cliente
              FROM ba_telefonos x
             WHERE x.cod_persona = v_cod_persona_titular
               AND x.principal = 'N'
               AND x.cod_telefono = (SELECT MIN(y.cod_telefono)
                                       FROM ba_telefonos y
                                      WHERE y.cod_persona = v_cod_persona_titular
                                        AND y.principal = 'N'
                                        AND y.telefono IS NOT NULL)
               AND rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_tel_cliente := NULL;
         END;
      END IF;

      --Busco la direccion de recibo del plastico, viene de la solicitud
      IF v_nro_solicitud IS NOT NULL THEN
         BEGIN
            SELECT substr(decode(t.tip_envio, 'D', d.direccion || ' ' || d.numero||' '||d.dir_lateral, 'C',
                                 'CASILLERO: ' || t.referencia, 'A',
                                 'CASILLA DE CORREO: ' || t.referencia, 'R',
                                 'RETENER EN ' || o.descripcion, 'N'), 1, 35) dir_recibo
              INTO v_dir_recibo
              FROM ba_direcciones d, ge_dir_retenciones o, ta_solicitudes t
             WHERE t.nro_solicitud = v_nro_solicitud
               AND ((t.tip_envio = 'D' AND d.cod_persona = t.cod_persona AND
                   d.cod_direccion = t.referencia) OR
                   (t.tip_envio = 'R' AND o.cod_dir_retencion = t.referencia))
               AND rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_dir_recibo := NULL;
         END;
      ELSE
         IF v_nro_cuenta IS NOT NULL THEN
            BEGIN
               SELECT substr(decode(e.tip_envio, 'D', d.direccion || ' ' || d.numero||' '||d.dir_lateral, 'C',
                                    'CASILLERO: ' || e.referencia, 'A',
                                    'CASILLA DE CORREO: ' || e.referencia, 'R',
                                    'RETENER EN ' || o.descripcion), 1, 35) dir_recibo
                 INTO v_dir_recibo
                 FROM ba_direcciones d, ge_dir_retenciones o, ge_dir_envios e, ta_tarjetas t
                WHERE t.nro_cuenta = v_nro_cuenta
                  AND t.cod_persona = v_cod_persona_titular
                  AND e.cod_persona = t.cod_persona
                  AND e.tip_envio = t.tip_envio
                  AND e.referencia = t.referencia
                  AND (e.nro_cuenta = v_nro_cuenta OR e.nro_cuenta IS NULL)
                  AND d.cod_persona(+) = e.cod_persona
                  AND d.cod_direccion(+) = e.referencia
                  AND o.cod_dir_retencion(+) = e.referencia
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_dir_recibo := NULL;
            END;
         END IF;
      END IF;
      --
      IF v_dir_recibo IS NULL THEN
         v_dir_recibo := substr(v_dir_cliente, 1, 35);
      END IF;

      -- Armar la direccion extendida--
      SELECT substr(v_dir_cliente ||decode(v_edificio,null,null,' Edif. ')||v_edificio
             || decode(v_piso,null,null,' Piso. ')|| v_piso
             || decode(v_dpto,null,null,' Dpto. ')|| v_dpto
             || decode(v_des_ciudad, NULL, NULL, ' - ') || v_des_ciudad, 1, 150)
        INTO v_dir_extendida
        FROM dual;
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      IF nvl(v_cod_departamento,11) = 11 AND v_ciudad_direccion IS NULL THEN
         v_ciudad_direccion  := 1;
      END IF;
      IF nvl(v_cod_departamento2,11) = 11 AND v_ciudad_direccion2 IS NULL THEN
         v_ciudad_direccion2 := 1;
      END IF;
      ---
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 ' Al Obt.Dir.envio: ' || v_cod_persona_titular ||
                                 ' Cuenta: '|| v_nro_cuenta);
   END lp_dir_envio_nov;
   ---------------------------------------------------------------------------------------------------
   PROCEDURE lp_dat_titular IS
      v_sol_cuenta varchar2(250);
   BEGIN
      /*Carga los datos del titular de la cuenta*/
      v_lugar                     := 'lp_dat_titular';
      v_tipo_persona_titular      := NULL;
      v_tipo_documento_titular    := NULL;
      v_nro_documento_titular     := NULL;
      v_nombre_1_titular          := NULL;
      v_nombre_2_titular          := NULL;
      v_apellido_1_titular        := NULL;
      v_apellido_2_titular        := NULL;
      v_razon_social_titular      := NULL;
      v_den_com_titular           := NULL;
      v_pais_documento_titular    := NULL;
      v_sexo_titular              := NULL;
      v_fecha_nacimiento_titular  := NULL;
      v_lugar_nacimiento_titular  := NULL;
      v_ruc_para_extracto_titular := NULL;
      v_estado_civil_titular      := NULL;
      v_ocupacion_titular         := NULL;
      v_direccion_email_titular   := NULL;
      v_nro_celular_titular       := NULL;
      v_cod_persona_titular       := NULL;
      --Obtener el tipo de persona(F o J)
      IF v_nro_solicitud IS NOT NULL THEN
         SELECT b.tipo, b.cod_persona
           INTO v_tipo_persona_titular, v_cod_persona_titular
           FROM tv_solicitudes a, ba_personas b
          WHERE a.cod_persona = b.cod_persona
            AND a.nro_solicitud = v_nro_solicitud
            AND a.tipo = 'T';
         v_sol_cuenta := 'solicitud';
      ELSIF v_nro_solicitud IS NULL AND v_nro_cuenta IS NOT NULL THEN
         SELECT DISTINCT b.tipo, b.cod_persona
           INTO v_tipo_persona_titular, v_cod_persona_titular
           FROM ge_cta_clientes a, ba_personas b
          WHERE a.cod_persona = b.cod_persona
            AND a.nro_cuenta = v_nro_cuenta
            AND a.relacion = 'P';
         v_sol_cuenta := 'cuenta';
      END IF;

      --Si el titular de la cuenta es una persona Fisica --
      IF v_tipo_persona_titular = 'F' THEN
         SELECT b.nro_documento,
                'F',
                CASE TRIM(w.abreviatura)
                   WHEN 'CI' THEN
                    'CIP'
                   ELSE
                    TRIM(w.abreviatura)
                END,
                c.pri_nombre,
                c.seg_nombre,
                c.pri_apellido,
                c.seg_apellido,
                NULL,
                NULL,
                c.cod_sexo,
                c.fec_nacimiento,
                substr(p.descripcion, 1, 15),
                decode(b.tip_iva, 'CO',
                       TRIM(b.nro_documento) || '-' ||
                        REPLACE(fue_obt_ruc_dig_verificador(TRIM(b.nro_documento)), '-', ''), NULL),
                decode(c.est_civil, 'S', 'S', 'C', 'C', 'V', 'V', 'D', 'D', 'B', 'C', 'S'),
                b.dir_correo,
                (SELECT x.telefono
                   FROM ba_telefonos x
                  WHERE x.cod_persona = b.cod_persona
                    AND tip_linea = 'C'
                    AND rownum < 2)
                --Para paises y Ocupacion
               ,
                p.ref_externa cod_ref_pais,
                x.ref_externa cod_ref_profesion
           INTO v_nro_documento_titular,
                v_tipo_persona_titular,
                v_tipo_documento_titular,
                v_nombre_1_titular,
                v_nombre_2_titular,
                v_apellido_1_titular,
                v_apellido_2_titular,
                v_razon_social_titular,
                v_den_com_titular,
                v_sexo_titular,
                v_fecha_nacimiento_titular,
                v_lugar_nacimiento_titular,
                v_ruc_para_extracto_titular,
                v_estado_civil_titular,
                v_direccion_email_titular,
                v_nro_celular_titular,
                v_pais_documento_titular,
                v_ocupacion_titular

           FROM ba_personas       b,
                ba_per_fisicas    c,
                ba_tip_documentos w
                --Para paises y Ocupacion
               ,
                ba_paises      p,
                ba_profesiones x
          WHERE b.cod_persona = v_cod_persona_titular
            AND b.cod_persona = c.cod_persona
            AND b.cod_tip_documento = w.cod_tip_documento
               --Para paises y Ocupacion
            AND c.cod_pai_nacionalidad = p.cod_pais(+)
            AND c.cod_profesion = x.cod_profesion(+);

      ELSE
         -- SI EL TITULAR ES UNA PERSONA JURIDICA ('J')
         SELECT b.nro_documento,
                'J',
                CASE TRIM(w.abreviatura)
                   WHEN 'CI' THEN
                    'CIP'
                   ELSE
                    TRIM(w.abreviatura)
                END,
                NULL,
                NULL,
                NULL,
                NULL,
                substr(c.raz_social, 1, 30),
                substr(c.nom_comercial, 1, 40),
                NULL,
                NULL,
                NULL,
                NULL,
                TRIM(b.nro_documento), --RUC PARA EXTRACTO TITULAR- ASUMIENDO QUE SI ES JURIDICA SE CARGA COMO NRO DOC SU RUC
                NULL,
                NULL,
                NULL,
                --obtengo el nro de cel
                (SELECT x.area || decode(x.area, NULL, NULL, '-') || x.telefono
                   FROM ba_telefonos x
                  WHERE x.cod_persona = b.cod_persona
                    AND tip_linea = 'C'
                    AND rownum < 2)
           INTO v_nro_documento_titular,
                v_tipo_persona_titular,
                v_tipo_documento_titular,
                v_nombre_1_titular,
                v_nombre_2_titular,
                v_apellido_1_titular,
                v_apellido_2_titular,
                v_razon_social_titular,
                v_den_com_titular,
                v_pais_documento_titular,
                v_sexo_titular,
                v_fecha_nacimiento_titular,
                v_lugar_nacimiento_titular,
                v_ruc_para_extracto_titular,
                v_estado_civil_titular,
                v_ocupacion_titular,
                v_direccion_email_titular,
                v_nro_celular_titular
           FROM ba_personas b, ba_per_juridicas c, ba_tip_documentos w
          WHERE b.cod_persona = v_cod_persona_titular
            AND b.cod_persona = c.cod_persona
            AND b.cod_tip_documento = w.cod_tip_documento;
      END IF;
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      if v_direccion_email_titular is not null then
        if v_pre_embozada <> 'S' then --DYDMR-19712 que el control se mantenga solo para las que no son pre embozadas.
          v_direccion_email_titular := pat_val.fu_val_correo(v_direccion_email_titular, v_cod_persona_titular);
        else  --DYDMR-19712 Error ABM Tarjetas de Crédito - Carácter invalido en correo electrónico
          begin
            v_direccion_email_titular := pat_val.fu_val_correo(v_direccion_email_titular, v_cod_persona_titular);
          exception
            when others then
              v_direccion_email_titular :=  null;
          end;
        end if;
      end if;
      IF v_tipo_documento_titular = 'CRP' THEN
         v_tipo_documento_titular := 'CAD';
      END IF;
      ---
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20124,
                                    v_lugar || ': No se encuentra datos del titular de la ' ||
                                    v_sol_cuenta || ' N° ' ||
                                    nvl(v_nro_solicitud, v_nro_cuenta) ||
                                    --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
                                    ' Cliente: ' || v_cod_persona_titular ||
                                    ' - ' || SQLERRM);
         END IF;
   END lp_dat_titular;
   ---------------------------------------------------------------------------------------------------
   PROCEDURE lp_dat_codeudor IS
   BEGIN
      /*Carga los datos del codeudor si tiene*/
      v_lugar := 'lp_dat_codeudor';
      ---0. limpio los valores a leer ------------------------------------
      v_cod_per_codeudor        := NULL;
      v_nom_codeudor            := NULL;
      v_nro_doc_codeudor        := NULL;
      v_tip_persona_codeudor    := NULL;
      v_tip_doc_codeudor        := NULL;
      v_pri_nombre_codeudor     := NULL;
      v_seg_nombre_codeudor     := NULL;
      v_pri_apellido_codeudor   := NULL;
      v_seg_apellido_codeudor   := NULL;
      v_sexo_codeudor           := NULL;
      v_fec_nacimiento_codeudor := NULL;
      v_lug_nacimiento_codeudor := NULL;
      v_est_civil_codeudor      := NULL;
      v_ocupacion_codeudor      := NULL;
      v_dir_correo_codeudor     := NULL;
      ---1. Leo la vista de acuerdo a los datos que me pasa --------------
      begin
      SELECT x.cod_persona,
             substr(y.nom_completo, 1, 30),
             y.nro_documento,
             --Traigo los nuevos datos que faltan
             y.tipo,
             CASE TRIM(w.abreviatura)
                WHEN 'CI' THEN
                 'CIP'
                WHEN NULL THEN
                 'CIP'
                ELSE
                 TRIM(w.abreviatura)
             END cod_tip_documento,
             substr(f.pri_nombre, 1, 20),
             substr(f.seg_nombre, 1, 20),
             substr(f.pri_apellido, 1, 20),
             substr(f.seg_apellido, 1, 20),
             f.cod_sexo,
             f.fec_nacimiento,
             substr(p.descripcion, 1, 15),
             decode(f.est_civil, 'S', 'S', 'C', 'C', 'V', 'V', 'D', 'D', 'B', 'C', 'S'),
             a.ref_externa cod_ref_profesion,
             y.dir_correo
        INTO v_cod_per_codeudor,
             v_nom_codeudor,
             v_nro_doc_codeudor,
             v_tip_persona_codeudor,
             v_tip_doc_codeudor,
             v_pri_nombre_codeudor,
             v_seg_nombre_codeudor,
             v_pri_apellido_codeudor,
             v_seg_apellido_codeudor,
             v_sexo_codeudor,
             v_fec_nacimiento_codeudor,
             v_lug_nacimiento_codeudor,
             v_est_civil_codeudor,
             v_ocupacion_codeudor,
             v_dir_correo_codeudor
        FROM ge_sol_codeudores x,
             ba_personas       y,
             ba_per_fisicas    f,
             ba_tip_documentos w,
             --Para Ocupacion
             ba_profesiones a,
             ba_paises      p
       WHERE x.nro_solicitud = v_nro_solicitud
         AND y.cod_persona = x.cod_persona
            --modificado para que traiga datos faltantes de per_fisicas
         AND y.cod_persona = f.cod_persona
         AND y.cod_tip_documento = w.cod_tip_documento
         AND f.cod_profesion = a.cod_profesion(+)
         AND f.cod_pai_nacionalidad = p.cod_pais(+)
         AND rownum < 2; --Solo envia (1) codeudor, si tiene--
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      exception
        when no_data_found then
          null;
      end;
      if v_dir_correo_codeudor is not null then
         if v_pre_embozada <> 'S' then --DYDMR-19712 que el control se mantenga solo para las que no son pre embozadas.
           v_dir_correo_codeudor := pat_val.fu_val_correo(v_dir_correo_codeudor, v_cod_per_codeudor);
         else  --DYDMR-19712 Error ABM Tarjetas de Crédito - Carácter invalido en correo electrónico
           begin
             v_dir_correo_codeudor := pat_val.fu_val_correo(v_dir_correo_codeudor, v_cod_per_codeudor);
           exception
             when others then
             v_dir_correo_codeudor :=  null;
           end;
         end if;
           
      end if;
      ---
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END lp_dat_codeudor;
   ---------------------------------------------------------------------------------------------------
   PROCEDURE lp_dat_oficialcuenta IS
   BEGIN
      /*Carga los datos del oficial de cuenta si tiene*/
      v_lugar := 'lp_dat_oficialcuenta';
      ---0. limpio los valores a leer ------------------------------------
      v_cod_per_oficta        := NULL;
      v_nom_oficta            := NULL;
      v_nro_doc_oficta        := NULL;
      v_tip_persona_oficta    := NULL;
      v_tip_doc_oficta_n      := NULL;
      v_pri_nombre_oficta     := NULL;
      v_seg_nombre_oficta     := NULL;
      v_pri_apellido_oficta   := NULL;
      v_seg_apellido_oficta   := NULL;
      v_sexo_oficta           := NULL;
      v_fec_nacimiento_oficta := NULL;
      v_lug_nacimiento_oficta := NULL;
      v_est_civil_oficta      := NULL;
      v_ocupacion_oficta      := NULL;
      v_dir_correo_oficta     := NULL;
      ---1. Leo la vista de acuerdo a los datos que me pasa --------------
      SELECT x.cod_usu_oficial,
             substr(y.nom_completo, 1, 30),
             y.nro_documento,
             y.tipo,
             CASE TRIM(w.abreviatura)
                WHEN 'CI' THEN
                 'CIP'
                WHEN NULL THEN
                 'CIP'
                ELSE
                 TRIM(w.abreviatura)
             END,
             substr(f.pri_nombre, 1, 20),
             substr(f.seg_nombre, 1, 20),
             substr(f.pri_apellido, 1, 20),
             substr(f.seg_apellido, 1, 20),
             f.cod_sexo,
             f.fec_nacimiento,
             f.cod_pai_nacionalidad,
             decode(f.est_civil, 'S', 'S', 'C', 'C', 'V', 'V', 'D', 'D', 'B', 'C', 'S'),
             a.ref_externa cod_ref_profesion,
             y.dir_correo
        INTO v_cod_per_oficta,
             v_nom_oficta,
             v_nro_doc_oficta,
             v_tip_persona_oficta,
             v_tip_doc_oficta_n,
             v_pri_nombre_oficta,
             v_seg_nombre_oficta,
             v_pri_apellido_oficta,
             v_seg_apellido_oficta,
             v_sexo_oficta,
             v_fec_nacimiento_oficta,
             v_lug_nacimiento_oficta,
             v_est_civil_oficta,
             v_ocupacion_oficta,
             v_dir_correo_oficta
        FROM tv_solicitudes    x,
             ba_usuarios       b,
             ba_personas       y,
             ba_per_fisicas    f,
             ba_tip_documentos w
             --Para Ocupacion
            ,
             ba_profesiones a
       WHERE x.nro_solicitud = v_nro_solicitud
         AND x.cod_usu_oficial = b.cod_usuario
         AND b.cod_persona = y.cod_persona
         AND y.cod_persona = f.cod_persona
         AND y.cod_tip_documento = w.cod_tip_documento
         AND f.cod_profesion = a.cod_profesion(+)
         AND rownum < 2;
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      if v_dir_correo_oficta is not null then
         v_dir_correo_oficta := pat_val.fu_val_correo(v_dir_correo_oficta, v_cod_per_oficta);
      end if;
      ---
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END lp_dat_oficialcuenta;
   ---------------------------------------------------------------------------------------------------
   PROCEDURE lp_dat_promotor IS
   BEGIN
      /*Carga los datos del PROMOTOR*/
      v_lugar := 'lp_dat_promotor';
      ---0. limpio los valores a leer ------------------------------------
      v_cod_per_promotor        := NULL;
      v_nom_promotor            := NULL;
      v_nro_doc_promotor        := NULL;
      v_tip_persona_promotor    := NULL;
      v_tip_doc_promotor        := NULL;
      v_pri_nombre_promotor     := NULL;
      v_seg_nombre_promotor     := NULL;
      v_pri_apellido_promotor   := NULL;
      v_seg_apellido_promotor   := NULL;
      v_sexo_promotor           := NULL;
      v_fec_nacimiento_promotor := NULL;
      v_lug_nacimiento_promotor := NULL;
      v_est_civil_promotor      := NULL;
      v_ocupacion_promotor      := NULL;
      v_dir_correo_promotor     := NULL;
      ---1. Leo la vista de acuerdo a los datos que me pasa --------------
      SELECT x.cod_usu_promotor,
             substr(y.nom_completo, 1, 30),
             y.nro_documento,
             y.tipo,
             CASE TRIM(w.abreviatura)
                WHEN 'CI' THEN
                 'CIP'
                WHEN NULL THEN
                 'CIP'
                ELSE
                 TRIM(w.abreviatura)
             END,
             substr(f.pri_nombre, 1, 20),
             substr(f.seg_nombre, 1, 20),
             substr(f.pri_apellido, 1, 20),
             substr(f.seg_apellido, 1, 20),
             f.cod_sexo,
             f.fec_nacimiento,
             f.cod_pai_nacionalidad,
             decode(f.est_civil, 'S', 'S', 'C', 'C', 'V', 'V', 'D', 'D', 'B', 'C', 'S'),
             a.ref_externa cod_ref_profesion,
             y.dir_correo
        INTO v_cod_per_promotor,
             v_nom_promotor,
             v_nro_doc_promotor,
             v_tip_persona_promotor,
             v_tip_doc_promotor,
             v_pri_nombre_promotor,
             v_seg_nombre_promotor,
             v_pri_apellido_promotor,
             v_seg_apellido_promotor,
             v_sexo_promotor,
             v_fec_nacimiento_promotor,
             v_lug_nacimiento_promotor,
             v_est_civil_promotor,
             v_ocupacion_promotor,
             v_dir_correo_promotor
        FROM tv_solicitudes    x,
             ba_usuarios       b,
             ba_personas       y,
             ba_per_fisicas    f,
             ba_tip_documentos w
             --Para Ocupacion
            ,
             ba_profesiones a
       WHERE x.nro_solicitud = v_nro_solicitud
         AND x.cod_usu_promotor = b.cod_usuario
         AND b.cod_persona = y.cod_persona
         AND y.cod_persona = f.cod_persona
         AND y.cod_tip_documento = w.cod_tip_documento
         AND f.cod_profesion = a.cod_profesion(+)
         AND rownum < 2;
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      if v_dir_correo_promotor is not null then
         v_dir_correo_promotor := pat_val.fu_val_correo(v_dir_correo_promotor, v_cod_per_promotor);
      end if;
      ---
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END lp_dat_promotor;
   ---------------------------------------------------------------------------------------------------
   PROCEDURE lp_car_pardinamicos IS
   BEGIN
      /*Carga todos los parametros dinamicos necesarios*/
      v_lugar := 'lp_car_pardinamicos';
      ---0. limpio los valores a leer ------------------------------------
      v_cod_banco    := NULL;
      v_cod_sucursal := NULL;
      ---1. Leo la vista de acuerdo a los datos que me pasa --------------
      v_cod_banco := fug_obt_parentes(v_cod_procesadora, 'COD_BANCO');

      v_lugar := 'Obtener código de sucursal';
      --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
      v_lugar := v_lugar || ' Cliente: ' || v_cod_persona;
      IF v_cod_campana IS NOT NULL THEN
         v_lugar := v_lugar || '-' || 'Campaña : ' || v_cod_campana;
         BEGIN
            SELECT cod_sucursal
              INTO v_cod_sucursal
              FROM ta_sucursales
             WHERE cod_ent_procesadora = v_cod_procesadora
               AND cod_oficina = v_cod_cue_oficina
               AND cod_campana = v_cod_campana
               AND activo = 'S'
               AND (c_tip_implementacion NOT IN (2, 3) OR
                   cod_sucursal = (SELECT MIN(cod_sucursal)
                                      FROM ta_sucursales
                                     WHERE cod_ent_procesadora = v_cod_procesadora
                                       AND cod_oficina = v_cod_cue_oficina
                                       AND cod_campana = v_cod_campana
                                       AND activo = 'S'));
         EXCEPTION
            WHEN no_data_found THEN
               BEGIN
                  SELECT cod_sucursal
                    INTO v_cod_sucursal
                    FROM ta_sucursales
                   WHERE cod_ent_procesadora = v_cod_procesadora
                     AND cod_oficina = v_cod_cue_oficina
                     AND activo = 'S'
                     AND rownum = 1;
               EXCEPTION
                  WHEN OTHERS THEN
                     IF SQLCODE <= -20000 THEN
                        RAISE;
                     ELSE
                        raise_application_error(-20122,
                                                v_lugar || ': No se encuentra código de sucursal (' ||
                                                v_cod_cue_oficina || ')' || SQLERRM);
                     END IF;
               END;
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20123,
                                          v_lugar || ': No se encuentra código de sucursal (' ||
                                          v_cod_cue_oficina || ')' || SQLERRM);
               END IF;
         END;
      ELSE
         BEGIN
            SELECT cod_sucursal
              INTO v_cod_sucursal
              FROM ta_sucursales
             WHERE cod_ent_procesadora = v_cod_procesadora
               AND cod_oficina = v_cod_cue_oficina
               AND activo = 'S'
               AND cod_campana IS NULL
               AND (c_tip_implementacion NOT IN (2, 3) OR
                   cod_sucursal = (SELECT MIN(cod_sucursal)
                                      FROM ta_sucursales
                                     WHERE cod_ent_procesadora = v_cod_procesadora
                                       AND cod_oficina = v_cod_cue_oficina
                                       AND cod_campana IS NULL
                                       AND cod_sucursal > 0
                                       AND activo = 'S'));
         EXCEPTION
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20124,
                                          v_lugar || ': No se encuentra código de sucursal (' ||
                                          v_cod_cue_oficina || ')' || SQLERRM);
               END IF;
         END;
      END IF;
   END lp_car_pardinamicos;
   /*
   || Jira: MDP-MOD_PRO_ALT_MAS_ABM
   || Si los emails NO son nulas (tienen algún valor),
   || entonces NO deben ser iguales entre si,
   || para evitar que una dirección de correo se encuentre duplicado en otro campo.
   */
   PROCEDURE lp_val_dir_correos IS
      /*
      || Variables a comparar:
      || ---------------------
      || nvl(v_direccion_email_titular,'a')
      || nvl(v_dir_correo_codeudor,'b')
      || nvl(v_dir_correo_oficta,'c')
      || nvl(v_dir_correo_promotor,'d')
      */
   BEGIN
      IF nvl(v_direccion_email_titular, 'a') = nvl(v_dir_correo_codeudor, 'b') OR
         nvl(v_direccion_email_titular, 'a') = nvl(v_dir_correo_oficta, 'c') OR
         nvl(v_direccion_email_titular, 'a') = nvl(v_dir_correo_promotor, 'd') THEN
         raise_application_error(-20000, 'Correo del titular se encuentra duplicado' ||
                                         --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
                                         ' - Cliente: ' || v_cod_persona);
      END IF;
      IF nvl(v_dir_correo_codeudor, 'b') = nvl(v_dir_correo_oficta, 'c') OR
         nvl(v_dir_correo_codeudor, 'b') = nvl(v_dir_correo_promotor, 'd') THEN
         raise_application_error(-20000, 'Correo del codeudor se encuentra duplicado' ||
                                         --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
                                         ' - Cliente: ' || v_cod_persona);
      END IF;
      IF nvl(v_dir_correo_oficta, 'c') = nvl(v_dir_correo_promotor, 'd') THEN
         --- raise_application_error(-20000, 'Correo del oficial se encuentra duplicado');
         --- DYDMR-800 Error al realizar Envio ABM TC a Bancard SC 5179
         --- Bancard valida que el promotor y el supervisor no sean el mismo.
         v_dir_correo_promotor := null;
      END IF;
   END lp_val_dir_correos;
   -------------------------------------------------------------------------------------------------
BEGIN
   --**********************INICIO DEL PROGRAMA PRINCIPAL****************************************--
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   END;
   --variables a utilizar--
   v_fec_actual      := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   v_nro_secuencia   := 0;
   v_cod_procesadora := p_cod_procesadora;

   --Obtener la oficina matriz de la entidad
   SELECT cod_ofi_matriz INTO v_cod_oficina FROM ge_par_generales;

   --borrar datos anteriores si hubiere--
   DELETE FROM ta_env_cuentas WHERE cod_procesadora = v_cod_procesadora;
   DELETE FROM ta_env_tarjetas WHERE cod_procesadora = v_cod_procesadora;

   IF v_cod_procesadora = v_cod_pro_bancard THEN
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      --- Nro de secuencia diario
      SELECT nvl(MAX(nvl(sec_env_datos, 0)), 0)
        INTO v_nro_secuencia
        FROM ta_env_cuentas_his
       WHERE trunc(fec_envio) = v_fec_actual;
      -- bancard
      --cursor principal cuentas--
      FOR r_cue IN c_cuentas LOOP
         v_per_tas_interes         := NULL;
         v_per_cod_interes         := NULL;
         v_mto_int_corriente       := NULL;
         v_per_cod_mora            := NULL;
         v_mto_int_moratorio       := NULL;
         v_per_cod_compra          := NULL;
         v_mto_int_compra          := NULL;
         v_nro_doc_procesadora     := NULL;
         v_nro_doc_cod_procesadora := NULL;
         v_ret_extracto            := null;
         v_mot_ret_extracto        := null;
         v_plz_dur_tar_inn         := null;
         v_tipo_persona_titular_inn:= NULL;
         v_per_pag_minimo          := 'N';
         v_nro_secuencia           := nvl(v_nro_secuencia, 0) + 1;
         v_cod_persona             := r_cue.cod_persona;
         v_nro_solicitud           := r_cue.nro_solicitud;
         v_cod_modulo              := r_cue.cod_modulo;
         v_cod_modalidad           := r_cue.cod_modalidad;
         v_cod_usu_promotor        := r_cue.cod_usu_promotor;
         v_cod_cue_oficina         := r_cue.cod_oficina;
         v_cod_campana             := r_cue.cod_campana;
         v_nro_cuenta              := r_cue.nro_cuenta;
         v_tip_cobro               := r_cue.tip_cob;
         v_lin_cuotas              := r_cue.lin_cuotas;
         v_cod_cli_entidad         := 'S'||to_char(r_cue.nro_solicitud); --r_cue.cod_persona; RE-25/06/2015-JIRA DE-575 se concatena la letra 'S' de solicitud para diferenciar de los codigos de persona
         v_gas_no_aplicar          := FUT_OBT_EXO_CARGO(v_cod_modulo,
                                                        v_cod_modalidad,
                                                        r_cue.afinidad,
                                                        r_cue.sub_afinidad); --Jira 3286
         begin
           select val_parametro
             into v_ret_extracto
             from ba_tab_dat_adicionales
            where tab_relacion = 'TA_SOLICITUDES'
              and referencia = r_cue.nro_solicitud
              and parametro = 'RET_EXTRACTO';
         exception
           when others then
             v_ret_extracto := null;
         end;

         begin
           select val_parametro
             into v_mot_ret_extracto
             from ba_tab_dat_adicionales
            where tab_relacion = 'TA_SOLICITUDES'
              and referencia = r_cue.nro_solicitud
              and parametro = 'MOT_RET_EXTRACTO';
         exception
           when others then
             v_mot_ret_extracto := null;
         end;
         
         /*BSEVOCORE-903 4ta linea - Empresa adherida (ALV - NOV/2021) */
         begin
           select a.val_maximo into v_emp_adherida
             from ba_cod_referencias a
            where a.dominio = 'AFI_EMP_ADHERIDA'
             and a.val_minimo = r_cue.afinidad;
         exception
           when no_data_found then
             v_emp_adherida := null;
           when others then
             v_emp_adherida := null;
         end;
         /*FIN BSEVOCORE-903*/


         --  Jira 707 - DYDMR-707  / RABP-08-08-2014
         declare
           CURSOR c_cargos IS
             select distinct lpad(ba.val_minimo, 3, '000') cod_costo
               from ba_cod_referencias ba
              where ba.dominio = 'TIP_EXO_COSTOS'
              order by 1;
           v_cod_cargo       VARCHAR(1000) := NULL;
           v_contador         NUMBER(6) := 0;
         begin
           FOR car IN c_cargos LOOP
              v_cod_cargo := nvl(v_cod_cargo, '') || car.cod_costo;
           END LOOP;

           if instr(v_cod_cargo, to_char(nvl(substr(v_gas_no_aplicar,0,3),'X'))) > 0 then
              v_aplica_impuesto:= NULL;
              select length(v_gas_no_aplicar)/3
                into v_contador
                from dual;
              FOR i IN 1 .. v_contador LOOP
                v_aplica_impuesto := v_aplica_impuesto || 'N';
              END LOOP;
           else
              v_aplica_impuesto:= NULL;
           end if;
         end;
         v_usu_actualizacion       := r_cue.usu_actualizacion;
         v_por_pag_minimo          := r_cue.por_pag_minimo;
         v_mto_min_pago            := r_cue.mto_min_pago;
         v_mto_int_compra          := r_cue.mto_int_compras;
         v_pre_embozada            := r_cue.pre_embozada;
         lp_dat_codeudor;
         lp_dat_oficialcuenta;
         lp_dat_promotor;
         lp_car_pardinamicos;
         lp_dat_titular;
         lp_dir_envio;
         --
         /*IF v_tip_envio = 'R' THEN
            v_retencion := 'S';
         ELSIF v_tip_envio = 'D' THEN
            v_retencion := 'N';
         ELSE
            v_retencion := NULL;
         END IF;*/
         -- Verificar cuenta de debito
         IF r_cue.nro_cta_debito IS NOT NULL THEN
            -- Enviar en formato viejo, si la cuenta esta en formato IT
            BEGIN
               SELECT decode(cod_modulo, 3, 1, 2)
                 INTO v_tip_cta_debito
                 FROM ge_cuentas
                WHERE nro_cuenta = r_cue.nro_cta_debito;
            EXCEPTION
               WHEN no_data_found THEN
                  v_tip_cta_debito := NULL;
            END;
            IF v_tip_cta_debito IS NULL THEN
               -- no esta en formato IT, no convertir
               v_nro_cta_debito := to_number(r_cue.nro_cta_debito);
               IF substr(v_nro_cta_debito, length(v_nro_cta_debito) - 6, 1) IN ('1', '3') THEN
                  v_tip_cta_debito := 2; --Cta.Cte.
               ELSIF substr(v_nro_cta_debito, length(v_nro_cta_debito) - 6, 1) IN ('2', '4') THEN
                  v_tip_cta_debito := 1; --Ahorro
               ELSE
                  v_tip_cta_debito := NULL;
               END IF;
            ELSE
               v_nro_cta_debito := pag_sue.fu_cod_cuenta(r_cue.nro_cta_debito);
               IF v_nro_cta_debito IS NULL THEN
                  raise_application_error(-20000,
                                          'No se puede convertir la cuenta de debito : ' ||
                                           r_cue.nro_cta_debito ||
                                           --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
                                           ' - Cliente: ' || v_cod_persona);
               END IF;
            END IF;
         ELSE
            v_nro_cta_debito := NULL;
            v_tip_cta_debito := NULL;
         END IF;

         --valida nro documento del principal--
         IF fue_val_campo(v_nro_documento_titular, 'N', 9) = 'N' THEN
            -- verifica si es una cedula con letra al final
            IF fue_val_campo(v_nro_documento_titular, 'N', 8) = 'N' THEN
               SELECT s_nro_doc_procesadora.nextval INTO v_nro_doc_procesadora FROM dual;
            ELSE
               v_nro_doc_procesadora := substr(v_nro_documento_titular, 1, 8);
            END IF;
         ELSE
            v_nro_doc_procesadora := substr(v_nro_documento_titular, 1, 8);
         END IF;

         IF v_nro_doc_codeudor IS NOT NULL THEN
            IF fue_val_campo(v_nro_doc_codeudor, 'N', 9) = 'N' THEN
               SELECT s_nro_doc_procesadora.nextval INTO v_nro_doc_cod_procesadora FROM dual;
            END IF;
         END IF;
         -- Personaliza Pago Mínimo
         If (nvl(r_cue.por_pag_minimo,0) <> 0 or nvl(r_cue.mto_min_pag_minimo,0)  <> 0) Then
            v_per_pag_minimo := 'S';
            v_mto_por_pago   := nvl(r_cue.mto_fij_pag_minimo,0); --nvl(r_cue.por_pag_minimo,0) + nvl(r_cue.mto_fij_pag_minimo,0) + nvl(r_cue.mto_min_pag_minimo,0);
         End If;

         -- Personaliza Tipo Tasa Interes
         IF nvl(r_cue.tas_int_corriente,0) != 0 then
            v_per_tas_interes   := 'S';
            v_per_cod_interes   := 1;
            v_mto_int_corriente := r_cue.tas_int_corriente;

         Elsif nvl(r_cue.tas_int_mora,0) != 0 then
            v_per_tas_interes   := 'S';
            v_per_cod_mora      := 2;
            v_mto_int_moratorio := r_cue.tas_int_mora;

         Elsif nvl(r_cue.tas_int_compra,0) != 0 then
            v_per_tas_interes   := 'S';
            v_per_cod_compra    := 3;
            v_mto_int_compra    := r_cue.tas_int_compra;
         End IF;
         --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
         lp_val_dir_correos;
         ---
         BEGIN
            IF c_tip_implementacion = 2 THEN
               -- valores fijos para Brios
               v_cod_sucursal  := 0; -- siempre casa matriz
               v_cod_encargado := 0; -- no hay encargados
            END IF;

            v_lugar := 'Ins.ta_env_cuentas:';
            --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
            IF r_cue.nro_solicitud is not null then
               v_lugar := v_lugar || ' Solic: ' || r_cue.nro_solicitud;
            END IF;
            IF r_cue.nro_cuenta is not null then
               v_lugar := v_lugar || ' Cta: ' || r_cue.nro_cuenta;
            END if;
            v_lugar := v_lugar || ' Cliente: ' || r_cue.cod_persona;
            ---CORETAIN-1. Si es Innominada debe ir como persona física.
            IF instr(fug_obt_pardinamico('TDC_AFI_INNOMINADAS', 5, r_cue.cod_modalidad), r_cue.afinidad)>0 AND
               v_cod_persona_titular = fug_obt_per_entidad THEN
               v_nro_documento_titular    := replace(v_nro_documento_titular, '-', '0');
               v_tipo_persona_titular_inn := 'F';
               v_tipo_documento_titular   := 'CIP';
               BEGIN
                  SELECT trunc(MONTHS_BETWEEN(a.fec_vencimiento, r_cue.fec_solicitud))
                    INTO v_plz_dur_tar_inn
                    FROM cr_cam_innominadas a
                   WHERE a.cod_campana = r_cue.cod_campana
                     AND a.cod_modulo = r_cue.cod_modulo
                     AND a.cod_modalidad = r_cue.cod_modalidad
                     AND a.afinidad = r_cue.afinidad
                     AND a.lin_credito = r_cue.monto;
               END;
            END IF;
            ---
            INSERT INTO ta_env_cuentas (cod_procesadora    , nro_cuenta             , cod_sucursal           , nom_usuario        ,
                                        cod_persona        , nro_documento          , nro_doc_procesadora    , direccion          ,
                                        dir_ext_2          , dir_ext_3              , dir_recibo             , localidad          ,
                                        cod_zona           , telefono               , cod_encargado          , cod_for_pago       ,
                                        cta_bancaria       , tip_tasa               , franqueo               , cod_retencion      ,
                                        nro_doc_codeudor   , nro_doc_cod_procesadora, tip_cuenta             , cod_tip_cierre     ,
                                        fec_novedad        , tip_tarjeta            , cod_afinidad           , cta_vip            ,
                                        cod_modalidad      , cod_moneda             , estado                 , nro_solicitud      ,
                                        cod_movimiento     , fec_envio              , hor_envio              , sec_env_datos      ,
                                        --
                                        es_personalizado   , pag_minimo             , por_pag_minimo         , tip_per_titular    ,
                                        --
                                        cod_tip_doc_titular, seg_nom_titular        , pri_ape_titular        , seg_ape_titular    ,
                                        raz_social         , nom_comercial          , cod_pai_titular        , cod_sex_titular    ,
                                        fec_nac_titular    , lug_nac_titular        , ruc_titular            , est_civ_titular    ,
                                        act_titular        , dir_cor_titular        , cod_tip_doc_nvo_titular, nro_doc_nvo_titular,
                                        cod_departamento   , cod_ciudad             , nro_tel_movil          , nro_doc_oficial    ,
                                        cod_tip_doc_oficial, seg_vida               , cob_cargo              , tip_costo          ,
                                        ret_extracto       , cau_retencion          , emp_adherida           , bcp_calificacion   ,
                                        situacion          , nro_socio              , bonos                  , tip_lin_normal     ,
                                        lin_cre_normal     , tip_lin_cuota          , lin_cre_cuota          , tas_personalizada  ,
                                        --
                                        cod_tasa           , val_tasa               , cod_tas_moratorio      , val_tas_moratorio  ,
                                        cod_tas_compra     , val_tas_compra         , pag_min_personalizado  , imp_pag_min_fijo   ,
                                        --
                                        tip_cta_bancaria   , val_cgf                , vip_fac_multiplicador  , cobranding         ,
                                        tip_per_codeudor   , cod_tip_doc_codeudor   , pri_nom_codeudor       , seg_nom_codeudor   ,
                                        pri_ape_codeudor   , seg_ape_codeudor       , cod_sex_codeudor       , fec_nac_codeudor   ,
                                        lug_nac_codeudor   , est_civ_codeudor       , act_codeudor           , dir_cor_codeudor   ,
                                        tip_per_oficial    , pri_nom_oficial        , seg_nom_oficial        , pri_ape_oficial    ,
                                        seg_ape_oficial    , cod_sex_oficial        , fec_nac_oficial        , lug_nac_oficial    ,
                                        est_civ_oficial    , act_oficial            , dir_cor_oficial        , pri_nom_titular    ,
                                        cod_cli_entidad    , gas_no_aplicar         , apl_impuesto           , usu_actualizacion  ,
                                        tip_pago           , mot_nov_cuenta         )
                                VALUES (v_cod_procesadora                               ,
                                        v_nro_cuenta                                    ,
                                        v_cod_sucursal                                  ,
                                        REPLACE(substr(r_cue.nom_completo,1,30),';',','),
                                        r_cue.cod_persona                               ,
                                        v_nro_documento_titular                         ,
                                        v_nro_doc_procesadora                           ,
                                        rpad(nvl(substr(v_dir_extendida, 1, 50),' '),50,' '),
                                        rpad(nvl(substr(v_dir_extendida, 51, 50),' '),50,' '),
                                        rpad(nvl(substr(v_dir_extendida, 101, 50),' '),50,' '),
                                        v_dir_recibo                                    ,
                                        v_ciudad_direccion                              ,
                                        NULL                                            ,
                                        v_tel_cliente                                   ,
                                        v_cod_encargado                                 ,
                                        CASE r_cue.deb_automatico       WHEN 'N' THEN 'V'  ELSE 'D'              END,
                                        CASE r_cue.deb_automatico       WHEN 'N' THEN NULL ELSE v_nro_cta_debito END,
                                        CASE r_cue.tip_tas_financiacion WHEN '0' THEN 'P'  ELSE 'N'              END,
                                        r_cue.franqueo                                  ,
                                        CASE v_tip_envio                WHEN 'R' THEN 'S'  ELSE 'N'              END,
                                        v_nro_doc_codeudor                              ,
                                        v_nro_doc_cod_procesadora                       ,
                                        decode(nvl(v_tipo_persona_titular_inn, v_tipo_persona_titular), 'F', 'P', 'E')   ,
                                        r_cue.cod_tip_cierre                            ,
                                        v_fec_actual                                    ,
                                        decode(c_tip_implementacion, 2, substr(r_cue.afinidad, 1, 2), r_cue.cod_tip_tarjeta),
                                        r_cue.cod_afinidad_externa                      ,
                                        'N'                                             ,
                                        r_cue.cod_modalidad                             ,
                                        r_cue.cod_moneda                                ,
                                        'G'                                             ,
                                        r_cue.nro_solicitud                             ,
                                        'A'                                             ,
                                        v_fec_actual                                    ,
                                        NULL                                            ,
                                        v_nro_secuencia                                 ,
                                        --
                                        nvl(r_cue.cta_personalizada, 'N')               ,
                                        --r_cue.mto_min_pago                              ,
                                        r_cue.mto_min_pag_minimo                        ,
                                        r_cue.por_pag_minimo                            ,
                                        --
                                        nvl(v_tipo_persona_titular_inn, v_tipo_persona_titular),
                                        v_tipo_documento_titular                        ,
                                        REPLACE(substr(v_nombre_2_titular, 1, 20), ';', ' '),
                                        REPLACE(substr(v_apellido_1_titular, 1, 20), ';', ' '),
                                        REPLACE(substr(v_apellido_2_titular, 1, 20), ';', ' '),
                                        REPLACE(substr(v_razon_social_titular, 1, 20), ';', ' '),
                                        REPLACE(substr(v_den_com_titular, 1, 20), ';', ' '),
                                        v_pais_documento_titular                        ,
                                        v_sexo_titular                                  ,
                                        v_fecha_nacimiento_titular                      ,
                                        v_lugar_nacimiento_titular                      ,
                                        v_ruc_para_extracto_titular                     ,
                                        v_estado_civil_titular                          ,
                                        nvl(v_ocupacion_titular, 1807)                  ,
                                        REPLACE(substr(v_direccion_email_titular, 1, 60), ';', ' '),
                                        NULL                                            ,
                                        NULL                                            ,
                                        v_departamento_direccion                        ,
                                        v_ciudad_direccion                              ,
                                        v_nro_celular_titular                           ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        decode(nvl(v_tipo_persona_titular_inn, v_tipo_persona_titular), 'F', 'S', 'N')   , -- Seg_vida
                                        --decode(r_cue.tip_com_emision, 'S', 'N', 'S')    ,
                                        v_cargo, --DYDMR-16300
                                        decode(r_cue.tip_com_emision, 'S', NULL, r_cue.tip_com_emision),
                                        v_ret_extracto                                     ,
                                        v_mot_ret_extracto                                            ,
                                        v_emp_adherida                                            ,
                                        pap_cat.fu_obt_cat_crc(r_cue.cod_persona, NULL, 'N'),
                                        -- Jira: MDP-MOD_PRO_ALT_MAS_ABM
                                        --decode(r_cue.pre_embozada,'S','A',r_cue.tip_generacion),
                                        r_cue.tip_generacion, 
                                        NULL                                            ,
                                        NULL                                            ,
                                        CASE WHEN r_cue.mto_aprobado IS NULL THEN NULL ELSE 1 END,
                                        nvl(r_cue.mto_aprobado, 0)                      ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        -- Tipo Tasa Interes
                                        v_per_tas_interes                               ,
                                        v_per_cod_interes                               ,
                                        v_mto_int_corriente                             ,

                                        v_per_cod_mora                                  ,
                                        v_mto_int_moratorio                             ,

                                        v_per_cod_compra                                ,
                                        v_mto_int_compra                                ,

                                        -- Pago Minimo Personalizado
                                        v_per_pag_minimo                                ,
                                        v_mto_por_pago                                  ,

                                        v_tip_cta_debito                                ,
                                        r_cue.tip_gas_financiero                        ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        CASE nvl(v_pri_nombre_codeudor, 'N') WHEN 'N' THEN NULL ELSE 'F' END,
                                        v_tip_doc_codeudor                              ,
                                        REPLACE(substr(v_pri_nombre_codeudor  , 1, 20), ';', ' '),
                                        REPLACE(substr(v_seg_nombre_codeudor  , 1, 20), ';', ' '),
                                        REPLACE(substr(v_pri_apellido_codeudor, 1, 20), ';', ' '),
                                        REPLACE(substr(v_seg_apellido_codeudor, 1, 20), ';', ' '),
                                        v_sexo_codeudor                                 ,
                                        v_fec_nacimiento_codeudor                       ,
                                        v_lug_nacimiento_codeudor                       ,
                                        v_est_civil_codeudor                            ,
                                        v_ocupacion_codeudor                            ,
                                        REPLACE(substr(v_dir_correo_codeudor, 1, 60), ';', ' '),
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        NULL                                            ,
                                        REPLACE(substr(v_nombre_1_titular, 1, 20), ';', ' '),
                                        v_cod_cli_entidad                               ,
                                        v_gas_no_aplicar                                ,
                                        v_aplica_impuesto                               ,
                                        r_cue.usu_actualizacion                         ,
                                        v_tip_cobro                                     ,
                                        NULL                                            );
         EXCEPTION
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20130,
                                          v_lugar || ': insert de TA_ENV_CUENTAS ' || SQLERRM);
               END IF;
         END;
         --cursor tarjetas--
         FOR r_tar IN c_tarjetas_principal LOOP
            --TARJETAS----
            v_plan_contado               := r_tar.plan_contado;
            v_ope_plan_contado           := r_tar.ope_plan_contado;
            v_imp_per_plan_contado       := r_tar.imp_per_plan_contado;
            v_por_per_plan_contado       := r_tar.por_pre_plan_contado;
            v_plan_ade_efectivo          := r_tar.plan_ade_efectivo;
            v_nro_cuenta                 := r_tar.nro_cuenta;
            v_ope_plan_ade_efectivo      := r_tar.ope_plan_ade_efectivo;
            v_impo_per_plan_ade_efectivo := r_tar.impo_per_plan_ade_efectivo;
            v_por_per_adelanto_efectivo  := r_tar.por_per_adelanto_efectivo;
            v_per_finan                  := r_tar.per_finan;
            v_ren_automatica             := 'S';
            v_tipo_tarjeta               := 'P'; -- ESTE CURSOR SELECCIONA SOLO LAS TARJETAS PRINCIPALES
            v_usu_actualizacion          := r_tar.usu_actualizacion;
            lp_dat_codeudor;
            lp_dat_oficialcuenta;
            lp_dat_promotor;
            lp_car_pardinamicos;
            lp_dat_titular;
            --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
            lp_val_dir_correos;
            ---
            BEGIN
               v_lugar := 'Ins.ta_env_tarjetas:';
               --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
               IF r_tar.nro_solicitud is not null then
                  v_lugar := v_lugar || ' Solic: ' || r_tar.nro_solicitud;
               END IF;
               IF r_tar.nro_cuenta is not null then
                  v_lugar := v_lugar || ' Cta: ' || r_tar.nro_cuenta;
               END if;
               v_lugar := v_lugar || ' Cliente: ' || r_tar.cod_persona;
               ---CORETAIN-1. Si es Innominada debe ir como persona física.
               IF v_tipo_persona_titular_inn = 'F' THEN
                  v_nro_documento_titular    := replace(v_nro_documento_titular, '-', '');
                  v_tipo_documento_titular   := 'CIP';
                  v_ren_automatica           := 'N';
               END IF;
               ---
               INSERT INTO ta_env_tarjetas
                  (cod_procesadora, nro_tarjeta, nro_cuenta, nom_usuario, cod_persona,
                   nro_documento, nro_doc_procesadora, dur_tarjeta, tip_tarjeta, ven_tarjeta,
                   cod_encargado, cla_tarjeta, cod_banco, cod_sucursal, cod_afinidad, fec_movimiento,
                   sec_alta, cod_movimiento, nom_embozado, fec_envio, hor_envio, estado,
                   nro_solicitud, cod_modalidad, sec_env_datos, tip_per_titular, cod_tip_doc_titular,
                   pri_nom_titular, seg_nom_titular, pri_ape_titular, seg_ape_titular,
                   cod_pai_titular, cod_sex_titular, fec_nac_titular, lug_nac_titular,
                   est_civ_titular, act_titular, dir_cor_titular, tip_doc_nvo_titular,
                   nro_doc_nvo_titular, tip_plastico, nom_plastico, adi_personalizado,
                   nro_doc_promotor, situacion, ren_automatica, orden_1, orden_2, tip_per_promotor,
                   cod_tip_doc_promotor, pri_nom_promotor, seg_nom_promotor, pri_ape_promotor,
                   seg_ape_promotor, cod_sex_promotor, fec_nac_promotor, lug_nac_promotor,
                   est_civ_promotor, act_promotor, dir_cor_promotor, pla_contado, ope_pla_contado,
                   imp_per_pla_contado, por_per_pla_contado, pla_ade_efectivo, ope_pla_ade_efectivo,
                   imp_per_pla_ade_efectivo, por_per_ade_efectivo, pue_financiar, usu_actualizacion,
                   emboza, nro_socio, mot_novedad)
               VALUES
                  (v_cod_procesadora, NULL,
                    --rpad( '0', 19, '0' ),--nro de tarjeta
                   v_nro_cuenta, REPLACE(substr(r_tar.nom_completo, 1, 26), ';', ','),
                   r_tar.cod_persona, v_nro_documento_titular, v_nro_doc_procesadora,
                    -- documento en la procesadora
                   nvl(v_plz_dur_tar_inn, r_tar.plz_dur_tarjeta),
                    --r_tar.plz_dur_tarjeta,--duracion de la tarjeta en meses
                   v_tipo_tarjeta,
                    --se guarda el tipo de tarjeta
                   to_char(add_months(v_fec_actual, nvl(v_plz_dur_tar_inn, r_tar.plz_dur_tarjeta)), 'MMYY'),
                   rpad('0', 2, '0'),
                   decode(c_tip_implementacion, 2, substr(r_tar.afinidad, 1, 2),
                           r_tar.cod_tip_tarjeta), v_cod_banco, v_cod_sucursal,
                   r_tar.cod_afinidad_externa, v_fec_actual, v_nro_secuencia, 'A',
                    -- Altas
                   r_tar.nom_embozado, v_fec_actual, NULL, 'G', r_tar.nro_solicitud, v_cod_modalidad,
                   v_nro_secuencia, nvl(v_tipo_persona_titular_inn, v_tipo_persona_titular) /*tip_per_titular*/, v_tipo_documento_titular,
                   --28 pri_nom_titular
                   CASE WHEN nvl(v_tipo_persona_titular_inn, 'X') = 'F' THEN 'BBVA INNOM'
                        WHEN v_tipo_persona_titular = 'F' THEN
                           REPLACE(substr(v_nombre_1_titular, 1, 20), ';', ' ') ELSE r_tar.nom_embozado END,

                   REPLACE(substr(v_nombre_2_titular,1,20), ';', ','),
                   --30 pri_ape_titular
                   CASE WHEN nvl(v_tipo_persona_titular_inn, 'X') = 'F' THEN 'BBVA INNOM'
                        WHEN v_tipo_persona_titular = 'F' THEN
                           REPLACE(substr(v_apellido_1_titular, 1, 20), ';', ' ') ELSE r_tar.nom_embozado END,

                   REPLACE(substr(v_apellido_2_titular, 1, 20), ';', ','), v_pais_documento_titular,
                    --Pais nacimiento600,-- Se envia por defecto 600
                   v_sexo_titular, v_fecha_nacimiento_titular, v_lugar_nacimiento_titular,
                    --Lugar de Nacimiento Titular 1, Asunción
                   v_estado_civil_titular, v_ocupacion_titular,
                    -- v_Ocupacion_titular,
                   REPLACE(substr(v_direccion_email_titular, 1, 60), ';', ','), NULL,
                    --v_Tipo_Documento_Nuevo_titular,
                   NULL,
                    --v_Nro_Documento_Nuevo_titular,
                   r_tar.tip_plastico,
                    -- 16-09-2013:RABP-PCC --tipo de plastico toma del campo tip_plastico
                   r_tar.nom_embozado,
                    --nom_plastico,
                   'N',
                    --Se envia siempre N adi_personalizada,
                   NULL,
                    --v_nro_doc_promotor,--nro_doc_promotor,
                   -- Jira: MDP-MOD_PRO_ALT_MAS_ABM
                   --decode(r_cue.pre_embozada,'S','A',r_tar.tip_generacion),
                   r_tar.tip_generacion,
                    --situacion
                   v_ren_automatica,
                    --  ren_automatica,
                   NULL,
                    --SE ENVIA POR DEFAULT NULL pri_orden,
                   NULL,
                    --SE ENVIA POR DEFAULT NULL seg_orden,
                   NULL,
                    --v_tip_persona_promotor,--tip_persona__promotor,
                   NULL,
                    --v_tip_doc_promotor,-- tip_doc__promotor,
                   NULL,
                    --v_pri_nombre_promotor,--pri_nombre__promotor,
                   NULL,
                    --v_seg_nombre_promotor,--seg_nombre__promotor,
                   NULL,
                    --v_pri_apellido_promotor,--pri_apellido__promotor,
                   NULL,
                    -- v_seg_apellido_promotor,--seg_apellido__promotor,
                   NULL,
                    --v_sexo_promotor,--sexo__promotor,
                   NULL,
                    --v_fec_nacimiento_promotor,--fec_nacimiento__promotor,
                   NULL,
                    --v_lug_nacimiento_promotor,-- lug_nacimiento__promotor,
                   NULL,
                    --v_est_civil_promotor,--est_civil__promotor,
                   NULL,
                    --v_ocupacion_promotor,--SE ENVIA POR DEFECTO 1513 OTROSocupacion__promotor,
                   NULL,
                    --v_dir_correo_promotor,--dir_correo__promotor
                   r_tar.plan_contado, r_tar.ope_plan_contado, r_tar.imp_per_plan_contado,
                   r_tar.por_pre_plan_contado, r_tar.plan_ade_efectivo, r_tar.ope_plan_ade_efectivo,
                   r_tar.impo_per_plan_ade_efectivo, r_tar.por_per_adelanto_efectivo,
                   r_tar.per_finan, r_tar.usu_actualizacion,
                   CASE nvl(v_tipo_persona_titular_inn, v_tipo_persona_titular) WHEN 'F' THEN 'S' ELSE 'N' END,
                    --SE ENVIA S POR DEFAULT emboza
                   NULL, NULL);
            EXCEPTION
               WHEN OTHERS THEN
                  IF SQLCODE <= -20000 THEN
                     RAISE;
                  ELSE
                     raise_application_error(-20131,
                                             v_lugar || ': insert de TA_ENV_TARJETAS ' || SQLERRM);
                  END IF;
            END;
         END LOOP;
         FOR r_tar IN c_tarjetas_adicional LOOP
            v_nro_doc_adi_procesadora := Null;
            v_plan_contado            := Null;
            v_ope_plan_contado        := Null;
            v_plan_efectivo           := Null;
            v_ope_plan_efectivo       := Null;
            v_nro_cuenta              := r_tar.nro_cuenta;
            If  r_tar.tas_personalizada = 'S' then
               --Plan Contado
               If nvl(r_Tar.pla_ope_mto_contado,0) <> 0 then
                  v_plan_contado     := '00'; --Constante '00', si está personalizada y es Plan Contado
                  v_ope_plan_contado := 'I';
               End if;
               If nvl(r_tar.pla_ope_por_contado,0) <> 0 then
                  v_plan_contado     := '00'; --Constante '00', si está personalizada y es Plan Contado
                  v_ope_plan_contado := 'P';
               End if;

               --Plan Adelanto Efectivo
               If nvl(r_Tar.pla_ope_mto_adelanto,0) <> 0 then
                  v_plan_efectivo     := '20'; --Constante '20', si está personalizada y es Plan Adelanto
                  v_ope_plan_efectivo := 'I';
               End if;
               If nvl(r_tar.pla_ope_por_adelanto,0) <> 0 then
                  v_plan_efectivo     := '20'; --Constante '20', si está personalizada y es Plan Adelanto
                  v_ope_plan_efectivo := 'P';
               End if;
            End if;
            r_tar.per_finan     := null;
            v_tipo_tarjeta      := 'A'; -- ESTE CURSOR SELECCIONA SOLO LAS TARJETAS ADICIONALES
            v_usu_actualizacion := r_tar.usu_actualizacion;
            lp_dat_codeudor;
            lp_dat_oficialcuenta;
            lp_dat_promotor;
            lp_car_pardinamicos;
            IF fue_val_campo(r_tar.nro_documento, 'N', 9) = 'N' THEN
               SELECT s_nro_doc_procesadora.nextval INTO v_nro_doc_adi_procesadora FROM dual;
            END IF;
            --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
            lp_val_dir_correos;
            ---
            BEGIN
               v_lugar := 'Adic.Ins.ta_env_tarjetas:';
               --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
               IF r_tar.nro_solicitud is not null then
                  v_lugar := v_lugar || ' Solic: ' || r_tar.nro_solicitud;
               END IF;
               IF r_tar.nro_cuenta is not null then
                  v_lugar := v_lugar || ' Cta: ' || r_tar.nro_cuenta;
               END if;
               v_lugar := v_lugar || ' Cliente: ' || r_tar.cod_persona;
               ---

               INSERT INTO ta_env_tarjetas (cod_procesadora , nro_tarjeta         , nro_cuenta              , nom_usuario         ,
                                            cod_persona     , nro_documento       , nro_doc_procesadora     , dur_tarjeta         ,
                                            tip_tarjeta     , ven_tarjeta         , cod_encargado           , cla_tarjeta         ,
                                            cod_banco       , cod_sucursal        , cod_afinidad            , fec_movimiento      ,
                                            sec_alta        , cod_movimiento      , nom_embozado            , fec_envio           ,
                                            hor_envio       , estado              , nro_solicitud           , cod_modalidad       ,
                                            sec_env_datos   , tip_per_titular     , cod_tip_doc_titular     , pri_nom_titular     ,
                                            seg_nom_titular , pri_ape_titular     , seg_ape_titular         , cod_pai_titular     ,
                                            cod_sex_titular , fec_nac_titular     , lug_nac_titular         , est_civ_titular     ,
                                            act_titular     , dir_cor_titular     , tip_doc_nvo_titular     , nro_doc_nvo_titular ,
                                            tip_plastico    , nom_plastico        , adi_personalizado       , nro_doc_promotor    ,
                                            situacion       , ren_automatica      , orden_1                 , orden_2             ,
                                            tip_per_promotor, cod_tip_doc_promotor, pri_nom_promotor        , seg_nom_promotor    ,
                                            pri_ape_promotor, seg_ape_promotor    , cod_sex_promotor        , fec_nac_promotor    ,
                                            lug_nac_promotor, est_civ_promotor    , act_promotor            , dir_cor_promotor    ,
                                            --
                                            pla_contado     , ope_pla_contado     , imp_per_pla_contado     , por_per_pla_contado ,
                                            pla_ade_efectivo, ope_pla_ade_efectivo, imp_per_pla_ade_efectivo, por_per_ade_efectivo,
                                            --
                                            pue_financiar   , usu_actualizacion   , emboza                  , nro_socio           ,
                                            mot_novedad     )
                                    VALUES (v_cod_procesadora,
                                            NULL,
                                            v_nro_cuenta,
                                            REPLACE(substr(r_tar.nom_completo, 1, 26), ';', ','),
                                            r_tar.cod_persona,
                                            r_tar.nro_documento,
                                            v_nro_doc_procesadora,
                                            r_tar.plz_dur_tarjeta,
                                            v_tipo_tarjeta,
                                            to_char(add_months(v_fec_actual, r_tar.plz_dur_tarjeta), 'MMYY'),
                                            --10
                                            rpad('0', 2, '0'),
                                            decode(c_tip_implementacion, 2, substr(r_tar.afinidad, 1, 2),r_tar.cod_tip_tarjeta),
                                            v_cod_banco,
                                            v_cod_sucursal,
                                            r_tar.cod_afinidad_externa,
                                            v_fec_actual,
                                            v_nro_secuencia,
                                            'A',
                                            r_tar.nom_embozado,
                                            v_fec_actual,
                                            --20
                                            NULL,
                                            'G',
                                            r_tar.nro_solicitud,
                                            v_cod_modalidad,
                                            v_nro_secuencia,
                                            r_tar.tipo,
                                            r_tar.tip_documento,
                                            REPLACE(substr(r_tar.pri_nombre, 1, 20), ';', ' '),
                                            REPLACE(substr(r_tar.seg_nombre, 1, 20), ';', ' '),
                                            REPLACE(substr(r_tar.pri_apellido, 1, 20), ';', ' '),
                                            --30
                                            REPLACE(substr(r_tar.seg_apellido, 1, 20), ';', ' '),
                                            v_pais_documento_titular,
                                            r_tar.cod_sexo,
                                            r_tar.fec_nacimiento,
                                            v_lugar_nacimiento_titular,
                                            r_tar.est_civil,
                                            v_ocupacion_titular,
                                            REPLACE(substr(r_tar.dir_correo, 1, 60), ';', ' '),
                                            NULL,
                                            NULL,
                                            --40
                                            r_tar.tip_plastico,
                                            r_tar.nom_embozado,
                                            decode(v_plan_contado,null,'N','S'),
                                            NULL,
                                            -- Jira: MDP-MOD_PRO_ALT_MAS_ABM
                                            --decode(r_cue.pre_embozada,'S','A',r_tar.tip_generacion),
                                            r_tar.tip_generacion,
                                            'S',
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            --50
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            --60
                                            v_plan_contado,
                                            v_ope_plan_contado,
                                            r_tar.pla_ope_mto_contado,
                                            r_tar.pla_ope_por_contado,

                                            v_plan_efectivo,
                                            v_ope_plan_efectivo,
                                            r_tar.pla_ope_mto_adelanto,
                                            r_tar.pla_ope_por_adelanto,
                                            --
                                            r_tar.per_finan,
                                            r_tar.usu_actualizacion,
                                            --70
                                            'S',
                                            NULL,
                                            NULL);
            EXCEPTION
               WHEN OTHERS THEN
                  IF SQLCODE <= -20000 THEN
                     RAISE;
                  ELSE
                     raise_application_error(-20132,
                                             v_lugar || ': insert de TA_ENV_TARJETAS ' || SQLERRM);
                  END IF;
            END;
         END LOOP;
         --fin de tarjetas--
      END LOOP;
      --****************CURSOR DE CUENTAS MODIFICADAS***********************--
      FOR v IN novedades LOOP
         v_dir_extendida           := NULL;
         v_departamento_direccion  := NULL;
         v_ciudad_direccion        := NULL;
         v_tel_cliente             := NULL;
         v_retencion               := NULL;
         v_ret_extracto            := NULL;
         v_mot_ret_extracto        := NULL;
         v_cod_for_pago            := NULL;
         v_tip_cta_debito          := NULL;
         v_nro_cta_debito          := NULL;
         v_tipo_documento_titular  := NULL;
         v_nro_doc_procesadora     := NULL;
         v_nro_doc_cod_procesadora := NULL;
         v_nro_solicitud           := NULL;
         v_cod_persona             := NULL;
         v_nro_secuencia           := nvl(v_nro_secuencia, 0) + 1;
         v_cod_modulo              := v.cod_modulo;
         v_cod_modalidad           := v.cod_modalidad;
         v_nro_cuenta              := v.nro_cuenta;
         v_lin_cuotas              := v.lin_cuotas;
         v_tip_cobro               := v.tip_cobro;
         v_ret_extracto            := v.ret_extracto;
         v_mot_ret_extracto        := v.mot_ret_extracto;
         --
         v_pla_contado             := null;
         v_ope_pla_contado         := null;
         v_pla_ade_efectivo        := null;
         v_ope_pla_ade_efectivo    := null;
         --MB: Jira CRORB-166.-
         v_per_pag_minimo          := 'N';
         v_per_tas_interes         := 'N';
         --**--
         v_ret_extracto     := NULL;
         v_mot_ret_extracto := NULL;

           -- si solicita no impresion, indicamos la retencion
         IF nvl(v.ret_extracto, 'N') = 'S' THEN
            v_ret_extracto     := 'S';
            v_mot_ret_extracto := v.mot_ret_extracto; -- solicitado por el cliente
         END IF;
         --**--
         IF v.nro_solicitud IS NOT NULL THEN -- RE DE-575
           v_nro_solicitud2 := 'S'||v.nro_solicitud;
         END IF;

         IF v.deb_automatico = 'S' THEN
            v_cod_for_pago := 'D';
         ELSIF v.deb_automatico = 'N' THEN
            v_cod_for_pago := 'V';
         ELSE
            v_cod_for_pago := NULL;
         END IF;
         --
         v_retencion := NULL;
         IF v.dir_envio IS NOT NULL THEN
            lp_dat_titular;
            lp_dir_envio_nov;
            --
            IF v_tip_envio = 'R' THEN
               v_retencion := 'S';
            ELSIF v_tip_envio = 'D' THEN
               v_retencion := 'N';
            ELSE
               v_retencion := NULL;
            END IF;
         END IF;
         --
         -- Verificar cuenta de debito
         IF v.nro_cta_debito IS NOT NULL THEN
            -- Enviar en formato viejo, si la cuenta esta en formato IT
            BEGIN
               SELECT decode(cod_modulo, 3, 1, 2)
                 INTO v_tip_cta_debito
                 FROM ge_cuentas
                WHERE nro_cuenta = v.nro_cta_debito;
            EXCEPTION
               WHEN no_data_found THEN
                  v_tip_cta_debito := NULL;
            END;
            IF v_tip_cta_debito IS NULL THEN
               -- no esta en formato IT, no convertir
               v_nro_cta_debito := v.nro_cta_debito;
               IF substr(v_nro_cta_debito, length(v_nro_cta_debito) - 6, 1) IN ('1', '3') THEN
                  v_tip_cta_debito := 2; --Cta.Cte.
               ELSIF substr(v_nro_cta_debito, length(v_nro_cta_debito) - 6, 1) IN ('2', '4') THEN
                  v_tip_cta_debito := 1; --Ahorro
               ELSE
                  v_tip_cta_debito := NULL;
               END IF;
            ELSE
               v_nro_cta_debito := pag_sue.fu_cod_cuenta(v.nro_cta_debito);
               IF v_nro_cta_debito IS NULL THEN
                  raise_application_error(-20000,
                                          'No se puede convertir la cuenta de debito : ' ||
                                           v.nro_cta_debito ||
                                           --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
                                           ' - Cliente: ' || v_cod_persona );
               END IF;
            END IF;
         ELSE
            v_nro_cta_debito := NULL;
            v_tip_cta_debito := NULL;
         END IF;
         --- Jira 3286
         v_gas_no_aplicar := FUT_OBT_EXO_CARGO(v.cod_modulo,
                                               v.cod_modalidad,
                                               v.afinidad,
                                               v.sub_afinidad);
         --  Jira 707 - DYDMR-707   / RABP-08-08-2014
         declare
           CURSOR c_cargos IS
             select distinct lpad(ba.val_minimo, 3, '000') cod_costo
               from ba_cod_referencias ba
              where ba.dominio = 'TIP_EXO_COSTOS'
              order by 1;
           v_cod_cargo       VARCHAR(1000) := NULL;
           v_contador         NUMBER(6) := 0;
         begin
           FOR car IN c_cargos LOOP
              v_cod_cargo := nvl(v_cod_cargo, '') || car.cod_costo;
           END LOOP;

           if instr(v_cod_cargo, to_char(nvl(substr(v_gas_no_aplicar,0,3),'X'))) > 0 then
              v_aplica_impuesto:= NULL;
              select length(v_gas_no_aplicar)/3
                into v_contador
                from dual;
                FOR i IN 1 .. v_contador LOOP
                  v_aplica_impuesto := v_aplica_impuesto || 'N';
                END LOOP;
           else
              v_aplica_impuesto:= NULL;
           end if;
         end;

         ---
         -- Personaliza Tipo Tasa Interes --MB: Jira CRORB-166.-
         IF nvl(v.tas_int_corriente,0) != 0 or nvl(v.tas_int_mora,0) != 0 or nvl(v.tas_int_compra,0) != 0 then
            v_per_tas_interes   := 'S';
         End IF;

         -- Personaliza Pago Mínimo --MB: Jira CRORB-166.-
         If (nvl(v.por_pag_minimo,0) <> 0 or nvl(v.mto_min_pag_minimo,0)  <> 0) Then
            v_per_pag_minimo := 'S';
         End If;
         -->
         --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
         lp_val_dir_correos;
         ---
         BEGIN
            If v.bloque = 'P' then
                INSERT INTO ta_env_cuentas
                   (cod_procesadora, nro_cuenta, cod_banco, direccion,
                     -- (Primeros 90 caracteres de la direccion extendida (para extracto)
                    dir_ext_2,
                     -- (Siguientes 50 caracteres de la direccion extendida (para extracto)
                    dir_ext_3,
                     -- (Siguientes 50 caracteres de la direccion extendida (para extracto)
                    localidad, cod_departamento, cod_ciudad, telefono, cod_retencion, tip_lin_normal,
                    lin_cre_normal, cod_for_pago, tip_cta_bancaria, cta_bancaria, cod_mod_pago, estado,
                    cod_movimiento, fec_envio, hor_envio, sec_env_datos, es_personalizado, /*pag_minimo, --MB: Jira CRORB-166.-
                    por_pag_minimo,*/ tip_pago, cod_tip_doc_nvo_titular, nro_doc_nvo_titular, situacion,
                    usu_modificacion, cod_tip_cierre, bcp_calificacion,
                    gas_no_aplicar,
                    apl_impuesto,    --DYDMR-707
                    tas_personalizada ,
                    cod_tasa          ,
                    val_tasa          ,
                    cod_tas_moratorio ,
                    val_tas_moratorio ,
                    cod_tas_compra    ,
                    val_tas_compra    ,

                    pag_min_personalizado,
                    por_pag_minimo       ,
                    pag_minimo           ,
                    imp_pag_min_fijo, -- Jira 3286
                    mot_nov_cuenta,
                    val_cgf, -- MP-2298-AUT_BAJA_TARJETAS
                    cod_cli_entidad,--RE 25/06/2015 JIRA DE-575
                    RET_EXTRACTO,
                    CAU_RETENCION)
                VALUES
                   (v_cod_procesadora,
                     --cod_procesadora,
                    v.nro_cuenta,
                     --nro_cuenta,
                    v_cod_banco,
                     --cod_banco,
                    rpad(nvl(substr(v_dir_extendida, 1, 50),' '),50,' '),
                    rpad(nvl(substr(v_dir_extendida, 51, 50),' '),50,' '),
                    rpad(nvl(substr(v_dir_extendida, 101, 50),' '),50,' '),
                    v_ciudad_direccion,
                     --localidad
                    nvl(v_departamento_direccion,
                        decode(v.mot_nov_cuenta,'P',11,NULL)), -- MP-2298-AUT_BAJA_TARJETAS),
                     --departamento,
                    nvl(v_ciudad_direccion,
                        decode(v.mot_nov_cuenta,'P',1,NULL)), -- MP-2298-AUT_BAJA_TARJETAS),
                     --envio 1 por asuncion v_ciudad_direccion,
                    v.tel_principal,
                     --telefono,
                    v_retencion, CASE WHEN v.lin_credito IS NULL THEN NULL ELSE 1 END, v.lin_credito,
                     --lim_credito,
                    v_cod_for_pago, v_tip_cta_debito,
                    --Cuando es debito se envia el nro de cta_debito sino Ceros
                    v_nro_cta_debito,
                     --cta bancaria
                    v.tip_cobro,
                     --cod_mod_pago,
                    'M',
                     --estado ==> Datos Generados
                    'M',
                     -- Modificaciones
                    v_fec_actual,
                     --fec_envio,
                    NULL,
                     --hor_envio,
                    v_nro_secuencia,
                     --sec_env_datos,
                    NULL,
                    --MB: Jira CRORB-166.-
                     --es_personalizado,
                    --NULL,
                     --pag_minimo,
                    --NULL,
                     --por_pag_minimo,
                    v_tip_cobro,
                     --tipo pago
                    decode(v.nro_documento, NULL, NULL, v_tipo_documento_titular), v.nro_documento,
                    decode(v.mot_nov_cuenta,'C','B',NULL), -- MP-2298-AUT_BAJA_TARJETAS
                     --situacion, en nulo para Bancard significa que es modificacion de datos,
                    v.usu_modificacion, v.cod_tip_cierre, v.cat_riesgo,
                    v_gas_no_aplicar,
                    v_aplica_impuesto,    --DYDMR-707 / RABP-08-08-2014
                    --MB: Jira CRORB-166.-
                    v_per_tas_interes,
                    decode(v.tas_int_corriente,null,null,1),
                    v.tas_int_corriente,
                    decode(v.tas_int_mora,null,null,2),
                    v.tas_int_mora,
                    decode(v.tas_int_compra,null,null,3),
                    v.tas_int_compra,
                    v_per_pag_minimo,
                    v.por_pag_minimo,
                    v.mto_min_pag_minimo,
                    v.mto_fij_pag_minimo, -- Jira 3286
                    NULL,
                    decode(v.mot_nov_cuenta,'P',6,NULL),-- MP-2298-AUT_BAJA_TARJETAS
                    v_nro_solicitud2, --RE 25/06/2015 JIRA DE-575
                    v_ret_extracto,
                    v_mot_ret_extracto);
            else
                     -- bcp_calif BBVASOP-1694
                --***************inserto lo modificado en tarjetas*************--
                If  v.tas_personalizada = 'S' then

               --Plan Contado
                   If nvl(v.pla_ope_mto_contado,0) <> 0 then
                      v_pla_contado     := '00';
                      v_ope_pla_contado := 'I';
                  End if;

                   If nvl(v.pla_ope_por_contado,0) <> 0 then
                      v_pla_contado    := '00';
                      v_ope_pla_contado := 'P';
                   End if;

                   --Plan Adelanto Efectivo
                   If nvl(v.pla_ope_mto_adelanto,0) <> 0 then
                      v_pla_ade_efectivo     := '20';
                      v_ope_pla_ade_efectivo := 'I';
                   End if;

                   If nvl(v.pla_ope_por_adelanto,0) <> 0 then
                      v_pla_ade_efectivo     := '20';
                      v_ope_pla_ade_efectivo := 'P';
                   End if;

                End if;
                --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
                lp_val_dir_correos;
                ---
                INSERT INTO ta_env_tarjetas (cod_procesadora         ,
                                             nro_cuenta              ,
                                             nro_tarjeta             ,
                                             tip_doc_nvo_titular     ,
                                             nro_doc_nvo_titular     ,
                                             situacion               ,
                                             cod_movimiento          ,
                                             sec_env_datos           ,
                                             usu_modificacion        ,
                                             adi_personalizado       ,
                                             -- 1
                                             pla_contado             ,
                                             ope_pla_contado         ,
                                             imp_per_pla_contado     ,
                                             por_per_pla_contado     ,
                                             -- 2
                                             pla_ade_efectivo        ,
                                             ope_pla_ade_efectivo    ,
                                             imp_per_pla_ade_efectivo,
                                             por_per_ade_efectivo    )
                                      VALUES(v_cod_procesadora       ,
                                             v_nro_cuenta            ,
                                             v.nro_tarjeta           ,
                                             decode(v.nro_documento, NULL, NULL, v_tipo_documento_titular),
                                             v.nro_documento         ,
                                             NULL                    ,-- Situacion, en nulo para bancard es modificacion
                                             'M'                     ,-- Modificaciones
                                             v_nro_secuencia         ,
                                             nvl(v.usu_modificacion,user),
                                             decode(v_pla_contado,null,'N','S'),
                                             -- 1
                                             v_pla_contado           ,
                                             v_ope_pla_contado       ,
                                             v.pla_ope_mto_contado   ,
                                             v.pla_ope_por_contado   ,
                                             -- 2
                                             v_pla_ade_efectivo      ,
                                             v_ope_pla_ade_efectivo  ,
                                             v.pla_ope_mto_adelanto  ,
                                             v.pla_ope_por_adelanto  );
            End If;

         EXCEPTION
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20133,
                                          'No se pudieron insertar los registros para las novedades ' ||
                                          --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
                                          ' - Cliente: ' || v_cod_persona || ' - ' ||
                                           SQLERRM);
               END IF;
         END;
      END LOOP;
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      PAT_VAL.PR_ACT_ACENTOS('TAR_ACT_ACENTOS');
      --****************FINALIZA BANCARD **********************************************************
      ----------------------------------------------------------------------------------------------
   ELSIF v_cod_procesadora = v_cod_pro_bepsa THEN
      -- bepsa
      --cursor principal cuentas--
      FOR r_cue IN c_cuentas_bep LOOP
         v_nro_doc_procesadora     := NULL;
         v_nro_doc_cod_procesadora := NULL;
         v_nro_secuencia           := nvl(v_nro_secuencia, 0) + 1;
         v_cod_persona             := r_cue.cod_persona;
         v_nro_solicitud           := r_cue.nro_solicitud;
         v_cod_modulo              := r_cue.cod_modulo;
         v_cod_modalidad           := r_cue.cod_modalidad;
         v_cod_usu_promotor        := r_cue.cod_usu_promotor;
         v_cod_campana             := r_cue.cod_campana;
         lp_dir_envio;
         lp_dat_codeudor;
         lp_car_pardinamicos;

         --valida nro documento del principal--
         IF fue_val_campo(r_cue.nro_documento, 'N', 9) = 'N' THEN
            -- verifica si es una cedula con letra al final
            IF fue_val_campo(r_cue.nro_documento, 'N', 8) = 'N' THEN
               SELECT s_nro_doc_procesadora.nextval INTO v_nro_doc_procesadora FROM dual;
            ELSE
               v_nro_doc_procesadora := substr(r_cue.nro_documento, 1, 8);
            END IF;
         ELSE
            v_nro_doc_procesadora := r_cue.nro_documento;
         END IF;

         IF v_nro_doc_codeudor IS NOT NULL THEN
            IF fue_val_campo(v_nro_doc_codeudor, 'N', 9) = 'N' THEN
               SELECT s_nro_doc_procesadora.nextval INTO v_nro_doc_cod_procesadora FROM dual;
            END IF;
         END IF;
         --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
         v_lugar := 'INS.ta_env_cuentas';
         IF r_cue.nro_solicitud is not null then
            v_lugar := v_lugar || ' Solic: ' || r_cue.nro_solicitud;
         END IF;
         IF r_cue.nro_cuenta is not null then
            v_lugar := v_lugar || ' Cta: ' || r_cue.nro_cuenta;
         END if;
         v_lugar := v_lugar || ' Cliente: ' || r_cue.cod_persona;
         ---
         BEGIN
            v_cod_sucursal  := 0; -- siempre casa matriz
            v_cod_encargado := 2; -- no hay encargados
            IF r_cue.cod_modalidad = 599 THEN
               -- rotativo
               v_cod_banco := 205;
            ELSE
               v_cod_banco := 302;
            END IF;
            INSERT INTO ta_env_cuentas
               (cod_procesadora, nro_cuenta, cod_banco, cod_sucursal, nom_usuario, cod_persona,
                nro_documento, nro_doc_procesadora, direccion, localidad, cod_ciudad,
                cod_departamento, cod_zona, telefono, cod_encargado, tip_lin_normal, lin_cre_normal,
                cod_for_pago, cta_bancaria, cod_mod_pago, tip_tasa, tip_comision, franqueo,
                cod_retencion, pri_nom_codeudor, seg_nom_codeudor, pri_ape_codeudor,
                seg_ape_codeudor, nro_doc_codeudor, nro_doc_cod_procesadora, tip_per_codeudor,
                tip_cuenta, cod_tip_cierre, fec_novedad, tip_tarjeta, cod_afinidad, cta_vip, fac_vip,
                cod_gas_financiero, sec_alta, tip_lin_cuota, lin_cre_cuota, cod_modalidad,
                cod_moneda, estado, nro_solicitud, cod_movimiento, fec_envio, hor_envio,
                sec_env_datos, es_personalizado, pag_minimo, por_pag_minimo, bcp_calificacion)
            VALUES
               (v_cod_procesadora, rpad('0', 9, '0'),
                 -- nro. de cuenta
                v_cod_banco, v_cod_sucursal, substr(r_cue.nom_completo, 1, 30), r_cue.cod_persona,
                r_cue.nro_documento, v_nro_doc_procesadora, v_dir_cliente, v_ciudad_direccion,
                 --localidad
                v_departamento_direccion,
                 --departamento,
                v_ciudad_direccion,
                 --envio 1 por asuncion v_ciudad_direccion,
                NULL,
                 -- zona
                v_tel_cliente, v_cod_encargado,
                CASE WHEN r_cue.mto_aprobado IS NULL THEN NULL ELSE 1 END,
                nvl(r_cue.mto_aprobado, 0),
                 -- Lim.credito
                '0',
                 -- rotativo es por debito automatico, el resto es por caja
                rpad('0', 11, '0'),
                 -- cuenta bancaria
                r_cue.tip_cob,
                 -- modo de pago
                r_cue.tip_tas_financiacion,
                 -- tipo de tasa
                r_cue.tip_com_emision, nvl(r_cue.franqueo, 1),
                 -- 0 si 1 no
                v_retencion, v_pri_nombre_codeudor,
                 --pri_nombre_codeudor,
                v_seg_nombre_codeudor,
                 --seg_nombre_codeudor,
                v_pri_apellido_codeudor,
                 --pri_apeliido_codeudor,
                v_seg_apellido_codeudor,
                 --seg_apellido_codeudor,
                v_nro_doc_codeudor, v_nro_doc_cod_procesadora,
                CASE nvl(v_pri_nombre_codeudor, 'N') WHEN 'N' THEN NULL ELSE 'F' END,
                 --tip_persona_codeudor,
                decode(c_tip_implementacion, 2, decode(r_cue.tipo_per, 'F', 1, 2), r_cue.tip_cuenta),
                 -- si es persona fisica 1 (personal), juridica 2 (empresa)
                r_cue.cod_tip_cierre, v_fec_actual,
                decode(c_tip_implementacion, 2, substr(r_cue.afinidad, 1, 2), r_cue.cod_tip_tarjeta),
                 --tipo de tarjeta
                decode(c_tip_implementacion, 2,
                        decode(v_cod_banco, 205, '01',
                                 -- rotativo
                                substr(r_cue.afinidad, 3, length(r_cue.afinidad))), r_cue.afinidad),
                 -- afinidad
                nvl(r_cue.cta_vip, 'N'), decode(nvl(r_cue.cta_vip, 'N'), 'N', '0000', '0000'),
                 --Cuando Cta Vip = S se debe definir
                r_cue.tip_gas_financiero, v_nro_secuencia, NULL,
                 --case when v_lin_cuotas is null then null else 2 end,--tip_linea2_cuota envio 2 si es cuota,
                0,
                 --v_lin_cuotas,--NULL,---lin_cre_cuota En caso de que sea de Cuotas
                r_cue.cod_modalidad, r_cue.cod_moneda, 'G' /*Datos Generados*/, r_cue.nro_solicitud,
                r_cue.tip_generacion, v_fec_actual, NULL, v_nro_secuencia,
                nvl(r_cue.cta_personalizada, 'N'), 0, 0,
                pap_cat.fu_obt_cat_crc(r_cue.cod_persona, NULL, 'N')); --calif_bcp,

         EXCEPTION
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20130,
                                          v_lugar || ': insert de TA_ENV_CUENTAS ' || SQLERRM);
               END IF;
         END;
         --cursor tarjetas--
         FOR r_tar IN c_tarjetas_principal_bep LOOP
            BEGIN
               INSERT INTO ta_env_tarjetas
                  (cod_procesadora, nro_tarjeta, nro_cuenta, nom_usuario, cod_persona,
                   nro_documento, nro_doc_procesadora, dur_tarjeta, tip_tarjeta, ven_tarjeta,
                   cod_encargado, cla_tarjeta, cod_banco, cod_sucursal, cod_afinidad, fec_movimiento,
                   sec_alta, cod_movimiento, nom_embozado, fec_envio, hor_envio, estado,
                   nro_solicitud, cod_modalidad, sec_env_datos)
               VALUES
                  (v_cod_procesadora, rpad('0', 16, '0'), rpad('0', 9, '0'),
                   substr(r_tar.nom_completo, 1, 26), r_tar.cod_persona, r_tar.nro_documento,
                   v_nro_doc_procesadora,
                    -- documento en la procesadora
                   r_tar.plz_dur_tarjeta, r_tar.tipo,
                    -- titular (cero)
                   to_char(add_months(v_fec_actual, r_tar.plz_dur_tarjeta), 'MMYY'),
                   rpad('0', 2, '0'), substr(r_tar.afinidad, 1, 2), v_cod_banco, v_cod_sucursal,
                   decode(c_tip_implementacion, 2,
                           decode(v_cod_banco, 205, '01',
                                    -- rotativo
                                   substr(r_cue.afinidad, 3, length(r_cue.afinidad))), r_cue.afinidad),
                    -- afinidad
                   v_fec_actual, v_nro_secuencia, r_tar.tip_generacion, r_tar.nom_embozado,
                   v_fec_actual, NULL, 'G', r_tar.nro_solicitud, v_cod_modalidad, v_nro_secuencia);
            EXCEPTION
               WHEN OTHERS THEN
                  IF SQLCODE <= -20000 THEN
                     raise_application_error(SQLCODE, SQLERRM);
                  ELSE
                     raise_application_error(-20131,
                                             v_lugar || ': insert de TA_ENV_TARJETAS ' || SQLERRM);
                  END IF;
            END;
         END LOOP;
         FOR r_tar IN c_tarjetas_adicional_bep LOOP
            v_nro_doc_adi_procesadora := NULL;
            IF fue_val_campo(r_tar.nro_documento, 'N', 9) = 'N' THEN
               SELECT s_nro_doc_procesadora.nextval INTO v_nro_doc_adi_procesadora FROM dual;
            END IF;
            BEGIN
               INSERT INTO ta_env_tarjetas
                  (cod_procesadora, nro_tarjeta, nro_cuenta, nom_usuario, cod_persona,
                   nro_documento, nro_doc_procesadora, dur_tarjeta, tip_tarjeta, ven_tarjeta,
                   cod_encargado, cla_tarjeta, cod_banco, cod_sucursal, cod_afinidad, fec_movimiento,
                   sec_alta, cod_movimiento, nom_embozado, fec_envio, hor_envio, estado,
                   nro_solicitud, cod_modalidad, sec_env_datos)
               VALUES
                  (v_cod_procesadora, rpad('0', 16, '0'), rpad('0', 9, '0'),
                   substr(r_tar.nom_completo, 1, 26), r_tar.cod_persona, r_tar.nro_documento,
                   v_nro_doc_adi_procesadora, r_tar.plz_dur_tarjeta, r_tar.tipo,
                   to_char(add_months(v_fec_actual, r_tar.plz_dur_tarjeta), 'MMYY'),
                   rpad('0', 2, '0'), substr(r_tar.afinidad, 1, 2), v_cod_banco, v_cod_sucursal,
                   substr(r_tar.afinidad, 3, length(r_tar.afinidad)), v_fec_actual, v_sec_env_datos,
                   r_tar.tip_generacion, r_tar.nom_embozado, v_fec_actual, NULL, 'G',
                   r_tar.nro_solicitud, v_cod_modalidad, v_nro_secuencia);
            EXCEPTION
               WHEN OTHERS THEN
                  IF SQLCODE <= -20000 THEN
                     RAISE;
                  ELSE
                     raise_application_error(-20132,
                                             v_lugar || ': insert de TA_ENV_TARJETAS ' || SQLERRM);
                  END IF;
            END;
         END LOOP;
         --fin de tarjetas--
      END LOOP;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20134,
                                 SQLERRM || ' / ' || v_lugar || ' Solic:' || v_nro_solicitud ||
                                 --- DYDMR-1451 Error al enviar ABM a Bancard SC 11859
                                 ' Cliente: ' || v_cod_persona || ' Mad:' ||
                                  v_cod_modalidad);
      END IF;

END;
/

