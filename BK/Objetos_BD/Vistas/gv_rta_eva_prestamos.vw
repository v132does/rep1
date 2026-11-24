CREATE OR REPLACE FORCE VIEW IT.GV_RTA_EVA_PRESTAMOS AS
SELECT fue_obt_nom_persona(a.cod_persona) nombre_cliente,
       a.cod_persona cod_persona,
       btd.abreviatura tipo_documento,
       bp.nro_documento nro_documento,
       fue_obt_des_refcodes('TIP_REL_PERSONA', a.tip_rel_persona) tipo_persona,
       fue_obt_des_pais(bp.cod_pais) nacionalidad,
       a.fec_nacimiento fecha_nacimiento,
       fue_obt_des_refcodes('COD_EST_CIVIL', a.est_civil) estado_civil,
       bd.direccion direccion,
       a.cli_especial cliente_preferente,
       btv.descripcion tipo_vivienda,
       fug_obt_des_actividad(bp.cod_actividad) actividad_bcp,
       fue_obt_des_refcodes('COD_ACTIVIDAD', bpf.cod_actividad) actividad_cliente,
       bpro.descripcion profesion,
       fue_obt_des_refcodes('TIP_EMPLEO', a.tip_empleo) situacion_laboral,
       cil.lug_trabajo lugar_trabajo,
       a.fec_lab_ingreso fecha_ingreso,
       a.sue_fij_solicitante sueldo_fijo,
       a.sue_var_solicitante sueldo_variable,
       a.ing_ind_solicitante ingresos_independientes,
       a.alq_cob_solicitante alquileres_cobrados,
       a.int_aho_solicitante intereses_ahorro,
       a.ren_acc_solicitante rentas_acciones,
       a.jub_pen_solicitante jubilacion_pension,
       fug_obt_mto_concepto(a.cod_persona, 1) ingresos_anuales,
       fug_obt_mto_concepto(a.cod_persona, 8) otros_ingresos,
       a.cuo_con_solicitante cuotas_consumo,
       a.cuo_hip_solicitante cuotas_hipoteca,
       a.cuo_tar_solicitante cuotas_tarjetas,
       a.otr_cuo_solicitante otras_cuotas,
       a.gto_familiar gastos_familiares,
       a.gto_alquiler gastos_alquiler,
       fug_obt_mto_concepto(a.cod_persona, 2) egresos_anuales,
       fug_obt_mto_concepto(a.cod_persona, 17) otros_egresos,
       b.nro_solicitud nro_solicitud,
       b.nro_intento nro_intento,
       b.fec_inicio fecha_solicitud,
       fue_obt_des_oficina(b.cod_oficina) oficina,
       fug_obt_des_modal(ps.cod_modulo, b.cod_modalidad) modalidad,
       fue_obt_des_moneda(b.cod_moneda) moneda,
       b.mto_solicitado monto_solicitado,
       fue_obt_des_refcodes('COD_DESTINO', b.cod_destino) destino,
       ps.dia_plazo plazo,
       (SELECT val_tasa FROM pr_sol_tasas t WHERE t.nro_solicitud = ps.nro_solicitud) tasa_interes,
       b.deb_automatico,
       ps.estado,
       trunc(gdre.fec_insercion) fecha_evaluacion,
       fue_obt_des_refcodes('COD_EVA_DICTAMENES', gdre.dic_final) dictamen_final,
       gca.faj_buro faja_informconf,
       fue_obt_des_refcodes('SIT_INFOCHECK', gca.sit_infocheck) situacion_infocheck,
       gca.pro_categoria categoria_bcp,
       gdred.bal_caja balance_caja,
       gdre.mto_reconducido monto_reconducido,
       gdre.plazo plazo_monto,
       gdre.tas_mto_reconducido tasa_monto,
       gdre.usu_insercion evaluador
  FROM gv_dat_eva_personas         a,
       gv_dat_eva_operaciones      b,
       ba_personas                 bp,
       ba_tip_documentos           btd,
       ba_per_fisicas              bpf,
       ba_tip_viviendas            btv,
       ba_profesiones              bpro,
       cr_inf_laborales            cil,
       ba_direcciones              bd,
       pr_solicitudes              ps,
       ge_dat_rie_evaluaciones     gdre,
       ge_cli_antecedentes         gca,
       ge_dat_rie_evaluaciones_det gdred
 WHERE a.cod_persona = bp.cod_persona
   AND bp.cod_tip_documento = btd.cod_tip_documento
   AND a.cod_persona = bpf.cod_persona
   AND a.cod_tip_vivienda = btv.cod_tip_vivienda
   AND a.cod_profesion = bpro.cod_profesion
   AND a.cod_persona = cil.cod_persona
   AND a.cod_persona = bd.cod_persona
   AND bd.principal = 'S'
   AND a.nro_intento =
       (SELECT MAX(nro_intento) FROM gv_dat_eva_personas x WHERE x.nro_solicitud = a.nro_solicitud)
   AND a.nro_solicitud = b.nro_solicitud
   AND a.nro_intento = b.nro_intento
   AND b.nro_solicitud = ps.nro_solicitud
   AND a.nro_solicitud = gdre.nro_solicitud
   AND a.nro_intento = gdre.nro_intento
   AND a.cod_persona = gdred.cod_persona
   AND gdred.cod_persona = gca.cod_persona
   AND gdre.nro_solicitud = gdred.nro_solicitud
   AND gdre.nro_intento = gdred.nro_intento;

