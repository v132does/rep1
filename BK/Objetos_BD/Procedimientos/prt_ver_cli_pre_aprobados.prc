create or replace procedure it.prt_ver_cli_pre_aprobados

  /*(p_cod_persona ba_personas.cod_persona%type)*/ is
  --variables
  v_afinidad        ta_cta_tarjetas.afinidad%type;
  v_sub_afinidad    ta_cta_tarjetas.sub_afinidad%type;
  v_cod_modalidad   ta_cta_tarjetas.cod_modalidad%type;
  v_cod_persona     ba_personas.cod_persona%type;
  v_tip_persona     ba_personas.tipo%type;
  v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
  v_lin_min_tarjeta ta_tipos.min_linea%TYPE;
  v_lin_max_tarjeta ta_tipos.max_linea%TYPE;
  v_error           ge_cli_aprobados_atm_tmp.det_error%type;
  v_errores         varchar2(1) := 'N';
  v_existe          number(3);
  v_lote            ge_cli_aprobados_atm_tmp.nro_lote%type;
  --cursor
  cursor c_datos(v_lote ge_cli_aprobados_atm_tmp.nro_lote%type) is
    select * from ge_cli_aprobados_atm_tmp a where a.nro_lote = v_lote; 
    
begin
  ---Elimino los errores que quedaron pendientes de la ultima inserción (se deberían corregir la siguiente vez)
  delete ge_cli_aprobados_atm_tmp a
   where a.det_error is not null
     and a.nro_lote is not null;
     
  --borro las tc pre aprobadas ya vencidas
  delete ge_cli_aprobados_atm_tmp a
   where a.fec_baja < pag_cal.FU_OBT_FEC_ACTUAL(5);     
   
   --Genero la nueva secuencia de lote
  select s_nro_lote_tar_atm.nextval
    into v_lote
    from dual;
    
  ---Actualizo los lotes null con el nuevo nro de lote    
  update ge_cli_aprobados_atm_tmp a
     set a.nro_lote = v_lote,
         a.acepta = 'N'
   where a.nro_lote is null;
   commit;
  
  for i in c_datos(v_lote) loop
    v_error := null;
    BEGIN
      SELECT p.cod_persona, p.tipo
        INTO v_cod_persona, v_tip_persona
        FROM ba_personas p
       WHERE p.nro_documento = i.nro_documento
         AND p.cod_persona = i.cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        v_error := nvl(v_error, '') || '#' || 'No existe Persona con este documento';
     WHEN too_many_rows THEN
        v_error := nvl(v_error, '') || '#' || 'Mas de una Persona con este documento';
     WHEN OTHERS THEN
        v_error := nvl(v_error, '') || '#' ||
                   'Error al traer codigo de Persona para el documento : ' ||
                   i.nro_documento || ' Error : ' || SQLERRM;
    END;
    -- Verificar si es persona física 
    IF v_tip_persona <> 'F' THEN
       v_error := nvl(v_error, '') || '#' || 'Persona no es Física';
    END IF;
    
    BEGIN
      SELECT substr(val_minimo, 1, 6), substr(val_minimo, 7, 2)
        INTO v_afinidad, v_sub_afinidad
        FROM ba_cod_referencias
       WHERE dominio = 'EQU_AFINIDAD'
         AND val_maximo = i.clase
         AND abreviatura = i.afinidad;
    EXCEPTION
      WHEN no_data_found THEN
        v_error := nvl(v_error, '') || '#' ||
                   'Afinidad SIGRIM no definida. Verificar en dominio EQU_AFINIDAD';
      WHEN OTHERS THEN
        v_error := nvl(v_error, '') || '#' || 'Error al buscar Afinidad SIGRIM : ' || SQLERRM;
    END;
    
    BEGIN
      SELECT DISTINCT cod_modalidad
        INTO v_cod_modalidad
        FROM ta_tipos t
       WHERE t.afinidad = v_afinidad
         AND nvl(t.sub_afinidad, '00') = nvl(v_sub_afinidad, '00');
    EXCEPTION
      WHEN no_data_found THEN
        v_error := nvl(v_error, '') || '#' || 'Modalidad no registrada para la afinidad ' ||
                   v_afinidad || ' sub-afinidad ' || v_sub_afinidad;
      WHEN OTHERS THEN
        v_error := nvl(v_error, '') || '#' || 'Error al buscar Modalidad en ta_tipos : ' || SQLERRM;
    END;
    
    v_existe := 0;
    SELECT COUNT(*)
      INTO v_existe
      FROM ta_solicitudes a
     WHERE a.cod_persona = i.cod_persona
       AND a.cod_modalidad = v_cod_modalidad
       AND a.afinidad = v_afinidad
       AND nvl(a.sub_afinidad, 'ZZ') = nvl(v_sub_afinidad, 'ZZ')
       and  to_char(a.fec_solicitud,'mmyyyy')= to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'mmyyyy')
       AND a.cod_estado <> 'RCH' --distinto a rechazado
       and not exists (select *
                         from ta_cta_tarjetas b
                            where b.nro_solicitud = a.nro_solicitud);
        
    IF v_existe <> 0 THEN
       v_error := nvl(v_error, '') || '#' || 'La persona : ' || i.cod_persona ||
                  ' ya posee solicitud activa para la modalidad ' ||
                  v_cod_modalidad || ', afinidad ' || v_afinidad ||
                  ' y sub-afinidad ' || v_sub_afinidad || '.';
    END IF;
    
    v_existe := 0;
    SELECT COUNT(*)
      INTO v_existe
      FROM ta_cta_tarjetas c, ta_tarjetas t
     WHERE t.cod_persona = i.cod_persona
       AND t.cod_estado <> 10
       AND c.nro_cuenta = t.nro_cuenta
       AND c.cod_modalidad = v_cod_modalidad
       AND c.afinidad = v_afinidad
       AND nvl(c.sub_afinidad, 'ZZ') = nvl(v_sub_afinidad, 'ZZ');
    IF v_existe <> 0 THEN
       v_error := nvl(v_error, '') || '#' || 'La persona : ' || i.cod_persona ||
                  ' ya posee tarjeta para la modalidad ' || v_cod_modalidad ||
                  ', afinidad ' || v_afinidad || ' y sub-afinidad ' ||
                  v_sub_afinidad || '.';
    END IF;
    
    --Controlar que la persona no se encuentre inhibida para solicitar tarjeta
    v_existe := 0;
    SELECT COUNT(*)
      INTO v_existe
      FROM ge_par_causales p, ge_causales c, ge_per_inhibidas ih
     WHERE ih.cod_persona = i.cod_persona
       AND c.cod_causa = ih.cod_causa
       AND p.cod_causa = c.cod_causa
       AND p.parametro = 'AFE_TARJETAS'
       AND ih.estado = 'I'
       AND p.val_parametro = 'S';
    IF v_existe <> 0 THEN
       v_error := nvl(v_error, '') || '#' || 'La persona : ' || i.cod_persona ||
                  ' se encuentra inhibida para este tipo de cuenta.';
    END IF;
    
    --LA 20/07/2015 
    --Controlar que existe el canal
    v_existe := 0;
    SELECT COUNT(*)
      INTO v_existe
      FROM ge_canales 
     WHERE cod_canal = i.cod_canal;
    IF v_existe = 0 THEN
       v_error := nvl(v_error, '') || '#' || 'El canal : ' || i.cod_canal ||
                  ' no existe.';
    END IF;
    --LA 20/07/2015 
    --Controlar que existe la campaña
    v_existe := 0;
    SELECT COUNT(*)
      INTO v_existe
      FROM cr_campanas 
     WHERE cod_campana = i.cod_campana;
    IF v_existe = 0 THEN
       v_error := nvl(v_error, '') || '#' || 'La campaña : ' || i.cod_campana ||
                  ' no existe.';
    END IF;
    
   --Controlar que el cliente no tenga una tc pre aprobada activa
    v_existe := 0;
    SELECT COUNT(*)
      INTO v_existe
      FROM ge_cli_aprobados_atm_tmp a
     WHERE a.cod_persona  = i.cod_persona
       and a.nro_lote <> v_lote
       and a.acepta <> 'S';
    IF v_existe <> 0 THEN
       v_error := nvl(v_error, '') || '#' || 'El cliente ya cuenta con una TC pre aprobada, favor verificar';
    END IF;
    
    -- Verifica los límites del tipo de tarjeta
    IF v_cod_modalidad IS NOT NULL AND
       v_cod_mon_local IS NOT NULL AND
       v_afinidad IS NOT NULL THEN
       BEGIN
          SELECT min_linea, max_linea
            INTO v_lin_min_tarjeta, v_lin_max_tarjeta
            FROM ta_tipos
           WHERE cod_modulo = 5
             AND cod_modalidad = v_cod_modalidad
             AND afinidad = v_afinidad
             AND nvl(sub_afinidad, '00') = nvl(v_sub_afinidad, '00')
             AND rownum = 1;
       EXCEPTION
          WHEN OTHERS THEN
             v_lin_min_tarjeta := 0;
             v_lin_max_tarjeta := 0;
       END;
       IF nvl(v_lin_min_tarjeta, 0) = 0 AND
          nvl(v_lin_max_tarjeta, 0) = 0 THEN
          v_lin_max_tarjeta := fug_obt_pardinamico('LIN_MAX_TARJETA', 5,
                                                   v_cod_modalidad, v_cod_mon_local,
                                                   i.cod_oficina);
          v_lin_min_tarjeta := fug_obt_pardinamico('LIN_MIN_TARJETA', 5,
                                                   v_cod_modalidad, v_cod_mon_local,
                                                   i.cod_oficina);
       END IF;
    ELSE
       v_error := nvl(v_error, '') || '#' || 'Al Obt. Minimo y Máximo para el Monto de Línea.';
    END IF;
    IF  i.lin_aprobada IS NOT NULL THEN  
       IF nvl(i.lin_aprobada, 0) < v_lin_min_tarjeta THEN
          v_error := nvl(v_error, '') || '#' || 'El monto debe ser mayor o igual a ' ||
                     ltrim(to_char(v_lin_min_tarjeta, '999,999,999,999.99'));
       ELSIF nvl(i.lin_aprobada, 0) > v_lin_max_tarjeta THEN
          v_error := nvl(v_error, '') || '#' || 'El monto debe ser menor o igual a ' ||
                     ltrim(to_char(v_lin_max_tarjeta, '999,999,999,999.99'));
       END IF;
    END IF;
    
    IF v_error is not null THEN
       update ge_cli_aprobados_atm_tmp a
          set a.det_error = v_error
        where a.cod_persona = i.cod_persona;
        v_errores := 'S';
        commit;
    END IF;
    
  end loop;
  
  if v_errores = 'S' then
    RAISE_APPLICATION_ERROR(-20000,'Archivo contiene errores. Verifique. ');
  end if;
  
end prt_ver_cli_pre_aprobados;
/

