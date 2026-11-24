create or replace package body it.PAG_SIG is
  /*******************************************************************************************/
  -- NO SE UTILIZA
  /*******************************************************************************************/ 
  PROCEDURE lp_balance_consolidado_mensual IS
  BEGIN
    /*
		insert into x_balance_consolidado_mensual \* cb_sal_consolidados *\
    (ano, mes, cuenta_contable, total_debitos_mes_gs, total_creditos_mes_gs, 
    saldo_final_mes_gs, saldo_final_mes_me, saldo_total_mes_en_gs, saldo_equiv_mes_gs, 
    total_debitos_mes_me, total_creditos_mes_me, promedio_mes_gs, promedio_mes_me)
    select ano, mes, cod_rubro, sum(deb_mon_local) v_total_debitos_mes_gs, sum(cre_mon_local) v_total_creditos_mes_gs,
    sum(cre_mon_local)-sum(deb_mon_local) v_saldo_final_mes_gs, sum(cre_mon_rubro)-sum(deb_mon_rubro) v_saldo_final_mes_me,
    sum(cre_mon_local)-sum(deb_mon_local) v_saldo_total_mes_en_gs, sum(cre_mon_rubro)-sum(deb_mon_rubro) v_saldo_equiv_mes_gs,
    sum(deb_mon_rubro) v_total_debitos_mes_me, sum(cre_mon_rubro) v_total_creditos_mes_me, 
    avg( cre_mon_local-deb_mon_local) v_promedio_mes_gs, avg(cre_mon_rubro-deb_mon_rubro) v_promedio_mes_me
    from cb_sal_consolidados
    group by ano, mes, cod_rubro;
		*/
    null;
  EXCEPTION
    WHEN OTHERS THEN 
    raise_application_error(-20000, 'Error al actualizar la tabla x_balance_consolidado_mensual '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- CB_SAL_OFICINAS
  /*******************************************************************************************/   
	PROCEDURE lp_balance_x_sucursal_mensual IS
  BEGIN
    NULL;
    /*insert into x_balance_x_sucursal_mensual
    (ano, mes, cuenta_contable, sucursal, total_debitos_mes_gs, 
    total_creditos_mes_gs, saldo_final_mes_gs, saldo_final_mes_me, 
    saldo_total_mes_en_gs, saldo_equiv_mes_gs, total_debitos_mes_me, 
    total_creditos_mes_me, promedio_mes_gs, promedio_mes_me)
    select ano, mes, cod_rubro, cod_oficina, sum(deb_mon_local), 
    sum(cre_mon_local), sum(cre_mon_local-deb_mon_local) v_saldo_final_mes_gs,  sum(cre_mon_rubro-deb_mon_rubro) v_saldo_final_mes_me, 
    sum(cre_mon_local-deb_mon_local) v_saldo_total_mes_en_gs, sum(cre_mon_rubro-deb_mon_rubro) v_saldo_equiv_mes_gs, sum(deb_mon_rubro),
    sum(cre_mon_rubro) v_total_creditos_mes_me, 0 v_promedio_mes_gs, 0 v_promedio_mes_me
    from cb_sal_oficinas
    group by ano, mes, cod_rubro, cod_oficina;*/
  EXCEPTION
    WHEN OTHERS THEN 
    raise_application_error(-20000, 'Error al actualizar la tabla x_balance_x_sucursal_mensual '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- EXISTE COMPROMISO DE DESARROLLO, SE DEBE MANTENER CONECTADO AL APPX HASTA SU 
	-- IMPLEMENTACION EN ITGF
  /*******************************************************************************************/   
  PROCEDURE lp_bienes_adjudicados IS
  BEGIN
    NULL;
    /*insert into x_bienes_adjudicados
    (codigo, nro_de_cliente, descripcion, fecha_de_adjudicacion, forma_de_adjudicacion, 
    total_de_tasacion, total_de_la_deuda, total_de_gastos, total_de_deuda_en_usd, 
    cotizacion, adjudicado, transferido, nro_de_cuenta)
    values
    (null , null , null , null , null , 
    null , null , null , null, 
    null , null , null , null);*/
  EXCEPTION
    WHEN OTHERS THEN 
    raise_application_error(-20000, 'Error al actualizar la tabla x_bienes_adjudicados '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- ESTA FUNCIONALIDAD NO ESTA INCLUIDO EN ITGF, NO HAY COMPROMISO DE DESARROLLO
  /*******************************************************************************************/ 
 PROCEDURE lp_cajas_de_seguridad IS
  BEGIN
    /*    
    insert into x_cajas_de_seguridad
    (nro_de_caja, sucursal, nro_de_cliente, estado_actual, fecha_inicio, 
    fecha_de_vencimiento, valor_de_la_caja, nro_de_cuotas, dias_de_mora, 
    monto_en_mora, dias_maximo_de_mora)
    values
    (v_nro_de_caja, v_sucursal, v_nro_de_cliente, v_estado_actual, v_fecha_inicio, 
    v_fecha_de_vencimiento, v_valor_de_la_caja, v_nro_de_cuotas, v_dias_de_mora, 
    v_monto_en_mora, v_dias_maximo_de_mora);
		*/
		null;
  EXCEPTION
    WHEN OTHERS THEN 
    raise_application_error(-20000, 'Error al actualizar la tabla x_cajas_de_seguridad '||SQLERRM);
  END;
  
  PROCEDURE lp_ciudades IS
  BEGIN
    NULL;
    /*insert into x_ciudades
    (pais, depto, ciudad, nombre_ciudad)
    select cod_pais, cod_departamento, cod_ciudad, descripcion
    from ba_ciudades;*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar la tabla x_ciudades '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- CE_CTA_IMPORTACIONES, CE_CTA_EXPORTACIONES / CX_
  /*******************************************************************************************/ 
  PROCEDURE lp_comercio_exterior IS
  BEGIN
    NULL;
    /*insert into x_comercio_exterior
    (nro_de_cuenta, nro_de_referencia, banco_corresponsal, 
    dias_de_mora, saldo_en_mora, negociado)
    select nro_cuenta, nro_referencia, cod_bco_corresponsal,
    0 v_dias_de_mora, 0 v_saldo_en_mora,  'S' v_negociado
    from ce_cta_importaciones
    union all 
    select nro_cuenta, nro_referencia, cod_bco_corresponsal,
    0 v_dias_de_mora, 0 v_saldo_en_mora,  'S' v_negociado
    from ce_cta_exportaciones;*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_comercio_exterior '||SQLERRM);
  END;

  /*******************************************************************************************/
  -- GE_COTIZACIONES
  /*******************************************************************************************/   
  PROCEDURE lp_cotizaciones IS
  BEGIN
    NULL;
    /*insert into x_cotizaciones
    (moneda, fecha_cotiz, cotizacion)
    select cod_moneda, fecha, val_conversion
    from ge_cotizaciones
    where fecha = pag_cal.fu_obt_fec_actual(1);*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_cotizaciones '||SQLERRM);
  END;

  /*******************************************************************************************/
  -- GE_CUENTAS / GE_CTA_CLIENTES
  -- VER LAS CONDICIONES PARTICULARES DE REGIONAL
	-- TAMBIEN RELEVAR LOS MONTOS PASADOS CON VALOR CERO
  /*******************************************************************************************/
  PROCEDURE lp_cuentas IS
  BEGIN
    NULL;
    /*insert into x_cuentas (
    nro_de_cliente, nro_de_cuenta, producto, sub_producto, sucursal, promotor, 
    nombre_de_la_cuenta, moneda, estado_actual, fecha_de_apertura, fecha_de_vencimiento, 
    plazo_en_dias, ultimo_movimiento, capital_inicial, saldo_a_ayer, promedio_del_mes, 
    tasa_de_interes, prevision, categoria_de_riesgo, rentabilidad, devengado_no_cobrado, modalidad)
    select b.cod_persona, a.nro_cuenta, a.cod_modulo, a.cod_modalidad v_sub_producto, a.cod_oficina, c.cod_usu_oficial,
    a.denominacion, a.cod_moneda, a.estado, a.fec_apertura, a.fec_vencimiento, 
    a.fec_vencimiento-a.fec_apertura plazo, d.fec_ult_movimiento, d.mto_apertura, d.sal_tot_batch, e.sal_acu_diario/e.can_dia_acumulado,
    a.cod_tasa, 0 v_prevision, c.cat_riesgo, 0 v_rentabilidad, 0 v_devengado_no_cobrado, a.cod_modalidad
    from ge_cuentas a, ge_cta_clientes b, ge_clientes c, ah_cta_vistas d, ah_sal_mensuales e
    where a.nro_cuenta = b.nro_cuenta
    and b.relacion = 'P'
    and b.cod_persona = c.cod_persona
    and a.nro_cuenta = d.nro_cuenta
    and a.nro_cuenta = e.nro_cuenta
    and e.ano||e.mes = to_char(pag_cal.fu_obt_fec_actual(3),'yyyymm');*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_cuentas '||SQLERRM);
  END;

  /*******************************************************************************************/
  -- CC_CTA_CORRIENTES
  /*******************************************************************************************/  
  PROCEDURE lp_cuentas_corrientes IS
  BEGIN
    NULL;
    /*insert into x_cuentas_corrientes
    (nro_de_cuenta, tipo_de_documento, tipo_de_correspondencia, inactivo, bloqueo, 
    motivo_de_bloqueo, saldo_actual, saldo_bloqueado, saldo_retenido, firmas_requeridas, 
    firmas_registradas, linea_de_sobregiro, tasa_de_sobregiro, inicio_de_linea, vencimiento, 
    dias_de_sobregiro, promedio_en_sobregiro, dias_maximo_de_mora, exceso_de_linea)
    select a.nro_cuenta, c.cod_tip_documento,'D' v_tipo_de_correspondencia, decode(a.estado, 'I','S',null) v_inactivo, 
    d.cod_causa v_bloqueo, d.cod_causa v_motivo_de_bloqueo, a.sal_tot_batch, a.sal_blo_batch, a.sal_ret_batch, 
    a.can_fir_requeridas, a.can_fir_registradas, e.monto, 100 v_tasa_de_sobregiro, e.inicio, e.vcto, a.dia_atraso, 
    a.pro_atraso, a.max_atraso, case when a.sal_tot_batch < 0 then
                                    case when(e.monto-abs(a.sal_tot_batch)) < 0 then
                                        e.monto-abs(a.sal_tot_batch)
                                    else
                                        0
                                    end
                                else
                                    0
                                end v_exceso_de_linea
    from cc_cta_corrientes a, ge_cta_clientes b, ba_personas c, 
    ge_bloqueos d, (select nro_cuenta, sum(monto) monto, min(fec_inicio) inicio, max(fec_vencimiento) vcto
                    from  cc_lin_sobregiros
                    where pag_cal.fu_obt_fec_actual(3) between fec_inicio and fec_vencimiento
                    and estado = 'A'
                    group by nro_cuenta) e
    where a.nro_cuenta = b.nro_cuenta
    and b.relacion = 'P'
    and b.cod_persona = c.cod_persona
    and a.estado not in ('A','C','X')
    and a.nro_cuenta = d.nro_cuenta(+)
    and a.nro_cuenta = e.nro_cuenta(+);*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_cuentas_corrientes '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- ESTA FUNCIONALIDAD NO ESTA INCLUIDO EN ITGF, NO HAY COMPROMISO DE DESARROLLO
  /*******************************************************************************************/ 
  PROCEDURE lp_cuotas_de_cajas_seg IS
  BEGIN
    /*    
    insert into x_cuotas_de_cajas_seg
    (nro_de_caja, sucursal, nro_de_cuota, monto_de_la_cuota, saldo_de_la_cuota, 
    estado, fecha_de_vencimiento, fecha_de_pago)
    values
    (v_nro_de_caja, v_sucursal, v_nro_de_cuota, v_monto_de_la_cuota, v_saldo_de_la_cuota, 
    v_estado, v_fecha_de_vencimiento, v_fecha_de_pago);
		*/
		null;
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_cuotas_de_cajas_seg '||SQLERRM);
  END;

  /*******************************************************************************************/
  -- BA_DEPARTAMENTOS
  /*******************************************************************************************/   
  PROCEDURE lp_departamentos IS
  BEGIN
    NULL;
    /*insert into x_departamentos
    (pais, depto, nombre_depto)
    select 1, cod_departamento, descripcion
    from ba_departamentos;*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_departamentos '||SQLERRM);
  END;

  /*******************************************************************************************/
  -- GE_GRU_ECONOMICOS
  /*******************************************************************************************/   
  PROCEDURE lp_ge_gru_economicos IS
  BEGIN
    NULL;
    /*insert into x_ge_gru_economicos
    (cod_gru_economico, descripcion, cat_subjetiva, cat_ponderada, 
    usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
    select cod_gru_economico, descripcion, cat_subjetiva, cat_automatica,
    usu_insercion, fec_insercion, usu_modificacion, fec_modificacion 
    from ge_gru_economicos;*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_ge_gru_economicos '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- ESTA FUNCIONALIDAD NO ESTA INCLUIDO EN ITGF, NO HAY COMPROMISO DE DESARROLLO
  /*******************************************************************************************/ 
 PROCEDURE lp_logros_x_oficial IS
  BEGIN
    /*    
    insert into x_logros_x_oficial
    (ano, mes, oficial, monto_de_coloc_nuevas, monto_de_coloc_recurrentes, cant_de_coloc_nuevas, 
    cant_de_coloc_recurrentes, cant_de_tarj_nuevas, cant_de_tarj_recurrentes, cant_de_micro_nuevos, 
    cant_de_micro_recurrentes, cant_de_desc_nuevos, cant_de_desc_recurrentes, total_de_colocaciones, 
    promedio_de_colocaciones, monto_ah_vista_nue, monto_ah_vista_rec, total_ah_vista, promedio_ah_vista, 
    monto_ah_plazo_1_ano_nue, monto_ah_plazo_1_ano_rec, total_ah_plazo_1_ano, promedio_ah_plazo_1_ano, 
    monto_ah_plazo_mas_1_ano_nue, monto_ah_plazo_mas_1_ano_rec, total_ah_plazo_mas_de_1_ano, 
    promedio_ah_plazo_mas_de_1_ano, ingresos_neto, porcentaje_de_morosidad, porc_de_mora_menor_a_30, 
    porc_de_mora_menor_a_60, porc_de_mora_mayor_a_60, interoficina, contribucion_margen_financiero, 
    contribucion_margen_operativo, base_a_cobrar, neto_a_cobrar, aporte_a_la_caja, puntaje)
    values
    (v_ano, v_mes, v_oficial, v_monto_de_coloc_nuevas, v_monto_de_coloc_recurrentes, v_cant_de_coloc_nuevas, 
    v_cant_de_coloc_recurrentes, v_cant_de_tarj_nuevas, v_cant_de_tarj_recurrentes, v_cant_de_micro_nuevos, 
    v_cant_de_micro_recurrentes, v_cant_de_desc_nuevos, v_cant_de_desc_recurrentes, v_total_de_colocaciones, 
    v_promedio_de_colocaciones, v_monto_ah_vista_nue, v_monto_ah_vista_rec, v_total_ah_vista, v_promedio_ah_vista, 
    v_monto_ah_plazo_1_ano_nue, v_monto_ah_plazo_1_ano_rec, v_total_ah_plazo_1_ano, v_promedio_ah_plazo_1_ano, 
    v_monto_ah_plazo_mas_1_ano_nue, v_monto_ah_plazo_mas_1_ano_rec, v_total_ah_plazo_mas_de_1_ano, 
    v_promedio_ah_plazo_mas_de_1_ano, v_ingresos_neto, v_porcentaje_de_morosidad, v_porc_de_mora_menor_a_30, 
    v_porc_de_mora_menor_a_60, v_porc_de_mora_mayor_a_60, v_interoficina, v_contribucion_margen_financiero, 
    v_contribucion_margen_operativo, v_base_a_cobrar, v_neto_a_cobrar, v_aporte_a_la_caja, v_puntaje);
		*/
		null;
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_logros_x_oficial '||SQLERRM);
  END;
  
 
  /*******************************************************************************************/
  -- ESTA FUNCIONALIDAD NO ESTA INCLUIDO EN ITGF, NO HAY COMPROMISO DE DESARROLLO
  /*******************************************************************************************/ 
  PROCEDURE lp_logros_x_oficial_sgt IS
  BEGIN
    /*    
    insert into x_logros_x_oficial_sgt
    (ano, mes, oficial, concepto, sucursal, logro_en_monto, logro_en_porcentaje, 
    meta_en_monto, meta_en_porcentaje, porcentaje_superado, tipo_meta)
    values
    (v_ano, v_mes, v_oficial, v_concepto, v_sucursal, v_logro_en_monto, v_logro_en_porcentaje, 
    v_meta_en_monto, v_meta_en_porcentaje, v_porcentaje_superado, v_tipo_meta);
		*/
		null;
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_logros_x_oficial_sgt '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- ESTA FUNCIONALIDAD NO ESTA INCLUIDO EN ITGF, NO HAY COMPROMISO DE DESARROLLO
  /*******************************************************************************************/
  PROCEDURE lp_metas_x_oficial IS
  BEGIN
     /*   
     insert into x_metas_x_oficial
    (ano, mes, oficial, monto_de_coloc_nuevas, monto_de_coloc_recurrentes, cant_de_coloc_nuevas, 
    cant_de_coloc_recurrentes, cant_de_tarj_nuevas, cant_de_tarj_recurrentes, cant_de_micro_nuevos, 
    cant_de_micro_recurrentes, cant_de_desc_nuevos, cant_de_desc_recurrentes, monto_ah_vista_nue, 
    monto_ah_vista_rec, monto_ah_plazo_1_ano_nue, monto_ah_plazo_1_ano_rec, monto_ah_plazo_mas_1_ano_nue, 
    monto_ah_plazo_mas_1_ano_rec, porcentaje_de_morosidad, porc_de_mora_menor_a_30, porc_de_mora_menor_a_60, 
    porc_de_mora_mayor_a_60, pond_cant_de_tarj, pond_cant_de_micro, pond_cant_de_desc, pond_cant_de_coloc, 
    pond_monto_de_coloc, pond_monto_ah_vista, pond_monto_ah_plazo_1_ano, pond_monto_ah_plazo_mas_1_ano, 
    pond_morosidad, pond_de_mora_menor_a_30, pond_de_mora_menor_a_60, pond_de_mora_mayor_a_60)
    values
    (v_ano, v_mes, v_oficial, v_monto_de_coloc_nuevas, v_monto_de_coloc_recurrentes, v_cant_de_coloc_nuevas, 
    v_cant_de_coloc_recurrentes, v_cant_de_tarj_nuevas, v_cant_de_tarj_recurrentes, v_cant_de_micro_nuevos, 
    v_cant_de_micro_recurrentes, v_cant_de_desc_nuevos, v_cant_de_desc_recurrentes, v_monto_ah_vista_nue, 
    v_monto_ah_vista_rec, v_monto_ah_plazo_1_ano_nue, v_monto_ah_plazo_1_ano_rec, v_monto_ah_plazo_mas_1_ano_nue, 
    v_monto_ah_plazo_mas_1_ano_rec, v_porcentaje_de_morosidad, v_porc_de_mora_menor_a_30, v_porc_de_mora_menor_a_60, 
    v_porc_de_mora_mayor_a_60, v_pond_cant_de_tarj, v_pond_cant_de_micro, v_pond_cant_de_desc, v_pond_cant_de_coloc, 
    v_pond_monto_de_coloc, v_pond_monto_ah_vista, v_pond_monto_ah_plazo_1_ano, v_pond_monto_ah_plazo_mas_1_ano, 
    v_pond_morosidad, v_pond_de_mora_menor_a_30, v_pond_de_mora_menor_a_60, v_pond_de_mora_mayor_a_60);
		*/
		null;
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_metas_x_oficial '||SQLERRM);    
  END;
  
  /*******************************************************************************************/
  -- BA_MONEDAS
  /*******************************************************************************************/   
	PROCEDURE lp_monedas IS
  BEGIN
    NULL;
    /*insert into x_monedas 
    (moneda, descripcion_moneda, pais, codigo_numerico)
    select cod_moneda, descripcion, cod_pais, cod_numerico
    from ba_monedas;*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_monedas '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- GE_CAUSALES
  /*******************************************************************************************/   
  PROCEDURE lp_motivos_de_bloqueo IS
  BEGIN
    NULL;
    /*insert into x_motivos_de_bloqueo
    (producto, motivo_de_bloqueo, desc_motivo_bloqueo)
    select 'OSA', a.cod_causa, a.descripcion
    from ge_causales a
    where a.tipo = 'B'
    union all 
    select 'OST', a.cod_causa, a.descripcion
    from ge_causales a
    where a.tipo = 'B';*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_motivos_de_bloqueo '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- BA_USUARIOS, LOS QUE SEAN OFICIALES
  /*******************************************************************************************/   
  PROCEDURE lp_oficiales IS
  BEGIN
    NULL;
    /*insert into x_oficiales
    (oficial, nombre_del_oficial, sucursal, banca, categoria, 
    esta_activo, telefonos, nro_de_cliente, nivel_del_oficial)
    select cod_usuario, nombre, cod_oficina, cod_banca, categoria,
    estado, telefono, cod_persona, 'X' v_nivel_del_oficial
    from ba_usuarios
    where oficial = 'S';*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_oficiales '||SQLERRM);
  END;
  
  /*******************************************************************************************/
  -- NO TENEMOS AUN, PERO DEBEMOS (GE_OPE_VENCIDAS)
  /*******************************************************************************************/
  PROCEDURE lp_operaciones_morosas IS
  BEGIN
    NULL;
    /*insert into x_operaciones_morosas
    (nro_de_cliente, nro_de_cuenta, producto, sub_producto, sucursal, 
    nombre_de_la_cuenta, moneda, fecha_de_apertura, fecha_de_vencimiento, plazo_en_dias, 
    ultimo_movimiento, linea_de_credito, capital_inicial, estado_actual, saldo_a_ayer, 
    monto_en_mora, dias_de_mora, tasa_de_interes, ratio_de_morosidad, prevision, 
    categoria_de_riesgo, promedio_del_mes, interes_moratorio, dias_maximo_de_mora, 
    dia_promedio_de_mora, nro_de_cuotas, cuotas_vencidas, cuotas_pagadas)
    values
    (null, null, null, null, null, 
    null, null, null, null, null, 
    null, null, null, null, null, 
    null, null, null, null, null, 
    null, null, null, null, 
    null, null, null, 
    null);*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_operaciones_morosas '||SQLERRM);
  END;

  /*******************************************************************************************/
  -- NO TENEMOS AUN, PERO DEBEMOS (GE_OPE_VENCIDAS)
  /*******************************************************************************************/  
  PROCEDURE lp_operaciones_vencidas IS
  BEGIN
    NULL;
    /*insert into x_operaciones_vencidas
    (nro_de_cuenta, fecha_de_inicio, saldo_inicial, estado_actual, dias_de_mora, 
    interes_moratorio, interes_punitorio, tasa_de_interes, referencia, situacion_actual, 
    otros_cargos, total_impuestos, saldo_actual)
    values
    (null, null, null, null, null, 
    null, null, null, null, null, 
    null, null, null);*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar x_operaciones_vencidas '||SQLERRM);
  END;

  /*******************************************************************************************/
  -- CB_SAL_OFICINAS
  /*******************************************************************************************/    
  PROCEDURE lp_balance_contable IS
  BEGIN
    NULL;
    /*insert into xx_balance_contable
    (cuenta_contable, sucursal, fecha_del_balance, total_debitos_gs, 
    total_creditos_gs, saldo_final_gs, saldo_final_me, saldo_equiv_gs, 
    saldo_total_en_gs, total_debitos_me, total_creditos_me)
    select cod_rubro, cod_oficina, pag_cal.fu_obt_fec_actual(2), deb_mon_local, cre_mon_local,
    sal_ini_mes_mon_local+(cre_mon_local-deb_mon_local) v_saldo_final_gs,
    sal_ini_mes_mon_rubro+(cre_mon_rubro-deb_mon_rubro) v_saldo_final_me,
    sal_ini_mes_mon_local+(cre_mon_local-deb_mon_local) v_saldo_total_en_gs,
    sal_ini_mes_mon_rubro+(cre_mon_rubro-deb_mon_rubro) v_saldo_equiv_gs,
    deb_mon_local, cre_mon_local
    from cb_sal_oficinas;*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar xx_balance_contable '||SQLERRM);
  END;

  /*******************************************************************************************/
  -- CB_SAL_OFICINAS
  /*******************************************************************************************/      
  PROCEDURE lp_his_balance_contable IS
  BEGIN
    NULL;
    /*insert into xx_his_balance_contable
    (cuenta_contable, sucursal, fecha_del_balance, total_debitos_gs, 
    total_creditos_gs, saldo_final_gs, saldo_final_me, saldo_equiv_gs, saldo_total_en_gs, 
    total_debitos_me, total_creditos_me)
    select cod_rubro, cod_oficina, pag_cal.fu_obt_fec_actual(2), deb_mon_local, cre_mon_local,
    sal_ini_mes_mon_local+(cre_mon_local-deb_mon_local) v_saldo_final_gs,
    sal_ini_mes_mon_rubro+(cre_mon_rubro-deb_mon_rubro) v_saldo_final_me,
    sal_ini_mes_mon_local+(cre_mon_local-deb_mon_local) v_saldo_total_en_gs,
    sal_ini_mes_mon_rubro+(cre_mon_rubro-deb_mon_rubro) v_saldo_equiv_gs,
    deb_mon_local, cre_mon_local
    from cb_sal_oficinas;*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar xx_his_balance_contable '||SQLERRM);    
  END;
  
  /*******************************************************************************************/
  -- CB_SAL_OFICINAS, CB_RUBROS
  /*******************************************************************************************/    
  PROCEDURE lp_sal_contables IS
  BEGIN
    NULL;
    /*insert into xx_sal_contables
    (cuenta, nombre_de_cuenta, sucursal, moneda, sal_contable)
    select a.cod_rubro, b.descripcion, a.cod_oficina, b.cod_moneda, 
    a.sal_ini_mes_mon_local+(a.cre_mon_local-a.deb_mon_local) v_sal_contable
    from cb_sal_oficinas a, cb_rubros b
    where a.cod_rubro = b.cod_rubro;*/
  EXCEPTION
  WHEN OTHERS THEN 
  raise_application_error(-20000, 'Error al actualizar xx_sal_contables '||SQLERRM);    
  END;

begin
  -- Initialization
  lp_balance_consolidado_mensual;
  lp_balance_x_sucursal_mensual;
  lp_bienes_adjudicados;
  lp_cajas_de_seguridad;
  lp_ciudades;
  lp_comercio_exterior;
  lp_cotizaciones;
  lp_cuentas;
  lp_cuentas_corrientes;
  lp_cuotas_de_cajas_seg;
  lp_departamentos;
  lp_ge_gru_economicos;
  lp_logros_x_oficial;
  lp_logros_x_oficial_sgt;
  lp_metas_x_oficial;
  lp_monedas;
  lp_motivos_de_bloqueo;
  lp_oficiales;
  lp_operaciones_morosas;
  lp_operaciones_vencidas;
  lp_balance_contable;
  lp_his_balance_contable;
  lp_sal_contables;
end PAG_SIG;
/

