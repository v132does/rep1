CREATE OR REPLACE PROCEDURE IT.PRT_ACT_SOL_APROBADA(p_nro_solicitud ta_solicitudes.nro_solicitud%TYPE DEFAULT NULL) IS
  c_fecha DATE := pag_cal.fu_obt_fec_actual(5);
  CURSOR c_solicitudes IS
    SELECT a.*, a.rowid fila
      FROM ta_sol_aprobadas_tmp a
     WHERE p_nro_solicitud IS NULL
        OR a.nro_solicitud = p_nro_solicitud
     order by a.nro_orden asc;
  v_existe              NUMBER;
  v_ref_persona         ba_cod_referencias.val_minimo%TYPE;
  v_lin_min_tarjeta     ta_tipos.min_linea%TYPE;
  v_lin_max_tarjeta     ta_tipos.max_linea%TYPE;
  c_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
  v_error               ta_sol_aprobadas_tmp.det_error%TYPE;
  rg_ta_sol_apr         ta_sol_aprobadas_tmp%ROWTYPE;
  v_cta_valida          VARCHAR2(1);
  v_tip_plastico        VARCHAR2(1);
  v_dir_correo          ba_personas.dir_correo%TYPE;
  v_tip_persona         ba_personas.tipo%TYPE;
  v_cod_usu_promotor    ba_personas.cod_usu_promotor%TYPE;
  v_cod_usu_oficial     ge_clientes.cod_usu_oficial%TYPE;
  v_ofi_oficial         ba_oficinas.cod_oficina%TYPE;
  v_mail_oficial        ba_personas.dir_correo%TYPE;
  v_mail_promotor       ba_personas.dir_correo%TYPE;
  v_cod_per_promotor    ba_personas.cod_persona%TYPE;
  v_cod_per_oficial     ba_personas.cod_persona%TYPE;
  v_dir_cliente         VARCHAR2(90); --ba_direcciones.direccion%type;
  v_cod_campana         cr_campanas.cod_campana%type;
  v_cod_canal           ge_canales.cod_canal%type;
  v_cod_cam_preaprobado cr_campanas.descripcion%type;
  v_cod_can_preaprobado ge_canales.cod_tip_canal%type;
  v_cod_rub_economico   pr_solicitudes.cod_rub_economico%type := fug_obt_pardinamico('COD_RUB_ECO_PRE_APR_ATM',
                                                                                     5);
  v_mot_ret_extracto    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MOT_RET_SOL_CLIENTE');
  v_nro_sol_titular     ta_sol_adicionales.nro_solicitud%type;
  -- logueamos en la tabla para seguimiento de errores.
  procedure lp_ins_log_error is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    insert into GE_LOG_ERRORES
      (COD_PROGRAMA, CAMPO1, DATO1, DET_ERROR)
    values
      ('PRT_ACT_SOL_APROBADA',
       'NRO_SOLICITUD',
       p_nro_solicitud,
       substr(v_error, 1, 4000));
    commit;
  exception
    when others then
      rollback;
  end;
  -------------------------------------------------------------------------------------
BEGIN
  FOR i IN c_solicitudes LOOP
    rg_ta_sol_apr      := NULL;
    v_error            := NULL;
    v_cta_valida       := 'N';
    v_tip_plastico     := 'N';
    v_dir_correo       := NULL;
    v_tip_persona      := NULL;
    v_cod_usu_promotor := NULL;
    v_cod_usu_oficial  := NULL;
    v_ofi_oficial      := NULL;
    v_mail_oficial     := NULL;
    v_mail_promotor    := NULL;
    v_cod_per_promotor := null;
    v_cod_per_oficial  := null;
    v_dir_cliente      := null;
    ---
    BEGIN
      SELECT p.cod_persona, p.dir_correo, p.tipo, p.cod_usu_promotor
        INTO rg_ta_sol_apr.cod_persona,
             v_dir_correo,
             v_tip_persona,
             v_cod_usu_promotor
        FROM ba_personas p
       WHERE p.nro_documento = i.nro_documento;
    EXCEPTION
      WHEN no_data_found THEN
        v_error := nvl(v_error, '') || '#' ||
                   'No existe Persona con este documento';
        GOTO siguiente_registro;
      WHEN too_many_rows THEN
        v_error := nvl(v_error, '') || '#' ||
                   'Mas de una Persona con este documento';
        GOTO siguiente_registro;
      WHEN OTHERS THEN
        v_error := nvl(v_error, '') || '#' ||
                   'Error al traer codigo de Persona para el documento : ' ||
                   rg_ta_sol_apr.nro_documento || ' Error : ' || SQLERRM;
        GOTO siguiente_registro;
    END;
    --
    -- Verificar si es persona física
    IF v_tip_persona <> 'F' THEN
      v_error := nvl(v_error, '') || '#' || 'Persona no es Física';
      GOTO siguiente_registro;
    END IF;
    -- Validar el correo de la persona
    IF v_dir_correo IS NOT NULL THEN
      if nvl(pae_cnf.g_programa, 'x') <> 'TPSOLPRE' THEN
        --BSEVOCORE-919 Exluir el control del correo electrónico para el procesO SOLICITUD MASIVA DE TARJETAS PREEMBOZADAS.
        BEGIN
          v_dir_correo := pat_val.fu_val_correo(v_dir_correo,
                                                rg_ta_sol_apr.cod_persona);
        EXCEPTION
          WHEN OTHERS THEN
            --DYDMR-7282 - Incidencia SAU - ITGF - Error Importacion de Archivo
            v_error := nvl(v_error, '') || '#' || 'correo cliente:' ||
                       v_dir_correo || ' - ' || SQLERRM;
        END;
      else
        --BSEVOCORE-919 Si no cumple la validación, que sea nulo
        BEGIN
          v_dir_correo := pat_val.fu_val_correo(v_dir_correo,
                                                rg_ta_sol_apr.cod_persona);
        EXCEPTION
          WHEN OTHERS THEN
            v_dir_correo := null;
        END;
      end if;
    
    END IF;
    --
    IF p_nro_solicitud IS NULL THEN
      /*
      || Se ejecuta luego de la importación del archivo Excel SOLIC_APROB.xls
      || Se verifican y validan los datos importados
      */
      rg_ta_sol_apr.tip_envio := upper(nvl(i.tip_envio, 'D'));
      IF rg_ta_sol_apr.tip_envio NOT IN ('D', 'R') THEN
        rg_ta_sol_apr.tip_envio := 'D';
      END IF;
      rg_ta_sol_apr.retener := upper(nvl(i.retener, 'N'));
      IF rg_ta_sol_apr.retener NOT IN ('N', 'S') OR
         rg_ta_sol_apr.tip_envio = 'D' THEN
        rg_ta_sol_apr.retener := 'N';
      END IF;
      IF rg_ta_sol_apr.retener = 'S' THEN
        rg_ta_sol_apr.tip_envio := 'R';
      END IF;
      ---
      rg_ta_sol_apr.nom_embozado := upper(i.nom_embozado);
      ---
      rg_ta_sol_apr.adicionales := upper(nvl(i.adicionales, 'N'));
      IF rg_ta_sol_apr.adicionales NOT IN ('N', 'S') THEN
        rg_ta_sol_apr.adicionales := 'N';
      END IF;
      rg_ta_sol_apr.deb_automatico := upper(nvl(i.deb_automatico, 'N'));
      IF rg_ta_sol_apr.deb_automatico NOT IN ('N', 'S') THEN
        rg_ta_sol_apr.deb_automatico := 'N';
        rg_ta_sol_apr.nro_cta_debito := NULL;
      END IF;
      rg_ta_sol_apr.tip_cobro := upper(nvl(i.tip_cobro, 'M'));
      IF rg_ta_sol_apr.tip_cobro NOT IN ('M', 'T') THEN
        rg_ta_sol_apr.tip_cobro := 'M';
      END IF;
    ELSE
      /*
      || tiene n° de solicitud
      || se trata de un reproceso
      */
      rg_ta_sol_apr.tip_envio      := i.tip_envio;
      rg_ta_sol_apr.retener        := i.retener;
      rg_ta_sol_apr.nom_embozado   := i.nom_embozado;
      rg_ta_sol_apr.adicionales    := i.adicionales;
      rg_ta_sol_apr.deb_automatico := i.deb_automatico;
      rg_ta_sol_apr.nro_cta_debito := i.nro_cta_debito;
      rg_ta_sol_apr.tip_cobro      := i.tip_cobro;
    END IF;
    --- Recalcular variables por si se editaron desde el form
    rg_ta_sol_apr.afinidad          := i.val_minimo;
    rg_ta_sol_apr.sub_afinidad      := NULL;
    rg_ta_sol_apr.cod_modalidad     := NULL;
    rg_ta_sol_apr.referencia        := i.val_maximo;
    rg_ta_sol_apr.par_modalidad     := NULL;
    rg_ta_sol_apr.pre_embozada      := NULL;
    rg_ta_sol_apr.observacion       := NULL;
    rg_ta_sol_apr.per_tasa          := 'N';
    rg_ta_sol_apr.tas_int_corriente := i.tas_int_corriente;
    rg_ta_sol_apr.tas_int_mora      := i.tas_int_mora;
    rg_ta_sol_apr.tas_int_compra    := i.tas_int_compra;
    rg_ta_sol_apr.monto             := i.monto;
    --- Asigna la Oficina del Oficial
    --- Si desde el Excel se carga sin valor
    --IF i.cod_oficina is null THEN
    BEGIN
      i.cod_oficina := fug_obt_ofi_oficial(rg_ta_sol_apr.cod_persona);
    EXCEPTION
      WHEN OTHERS THEN
        --DYDMR-7282-Incidencia SAU - ITGF - Error Importacion de Archivo
        v_error := nvl(v_error, '') || '# Oficina Cliente: ' || SQLERRM;
    END;
    --END IF;
    --*
    --*  Traer secuencia para nro. de solicitud
    --*
    IF I.TAR_ADICIONAL = 'N' THEN
      -- SOLO SI ES UNA TARJETA PRINCIPAL
      IF i.nro_solicitud IS NULL THEN
        BEGIN
          SELECT s_nro_solicitud.nextval
            INTO rg_ta_sol_apr.nro_solicitud
            FROM sys.dual;
        EXCEPTION
          WHEN OTHERS THEN
            v_error := nvl(v_error, '') || '#' ||
                       'Error al traer secuencia de solicitudes : ' ||
                       SQLERRM;
        END;
      ELSE
        rg_ta_sol_apr.nro_solicitud := i.nro_solicitud;
      END IF;
    END IF;
    -- Recuperar Sub-Afinidad
    BEGIN
      SELECT t.sub_afinidad
        INTO rg_ta_sol_apr.sub_afinidad
        FROM ba_cod_referencias r, ta_tipos t
       WHERE r.dominio = 'AFINIDAD'
         AND r.val_minimo = t.afinidad
         AND substr(t.afinidad, 1, 2) = t.cod_tip_tarjeta
         AND r.val_minimo = i.val_minimo;         
    EXCEPTION
      WHEN no_data_found THEN
        v_error := nvl(v_error, '') || '#' ||
                   'Sub-Afinidad no definida, para Afinidad '||i.val_minimo||'. Verificar en dominio AFINIDAD';
      WHEN OTHERS THEN
        v_error := nvl(v_error, '') || '#' ||
                   'Error al buscar Sub-Afinidad : ' || SQLERRM;
    END;
    --- Recuperar la modalidad a partir de la afinidad -- ICL. 08/07/2009
    IF rg_ta_sol_apr.afinidad IS NOT NULL THEN
      BEGIN
        SELECT DISTINCT cod_modalidad
          INTO rg_ta_sol_apr.cod_modalidad
          FROM ta_tipos t
         WHERE t.afinidad = rg_ta_sol_apr.afinidad
           AND nvl(t.sub_afinidad, '00') =
               nvl(rg_ta_sol_apr.sub_afinidad, '00');
      EXCEPTION
        WHEN no_data_found THEN
          v_error := nvl(v_error, '') || '#' ||
                     'Modalidad no registrada para la afinidad ' ||
                     rg_ta_sol_apr.afinidad || ' sub-afinidad ' ||
                     rg_ta_sol_apr.sub_afinidad;
        WHEN OTHERS THEN
          v_error := nvl(v_error, '') || '#' ||
                     'Error al buscar Modalidad en ta_tipos : ' || SQLERRM;
      END;
    ELSE
      v_error := nvl(v_error, '') || '#' ||
                 'Afinidad no definida en dominio AFINIDAD';
    END IF;
    IF rg_ta_sol_apr.cod_modalidad IS NULL THEN
      v_error := nvl(v_error, '') || '#' ||
                 'Modalidad no definida para la afinidad' ||
                 rg_ta_sol_apr.afinidad || ' sub-afinidad ' ||
                 rg_ta_sol_apr.sub_afinidad;
    END IF;
    ---
    v_ref_persona               := nvl(fue_obt_des_refcodes('COD_PER_EXC_IMP',
                                                            rg_ta_sol_apr.cod_persona),
                                       'N');
    rg_ta_sol_apr.par_modalidad := nvl(fug_obt_pardinamico('COD_MAD_EXC_IMP',
                                                           '5',
                                                           rg_ta_sol_apr.cod_modalidad),
                                       'N');
    IF i.monto <> 0 OR (rg_ta_sol_apr.par_modalidad = 'S') THEN
      --- Recuperar embozado
      IF rg_ta_sol_apr.nom_embozado IS NULL THEN
        IF (v_ref_persona = 'S' AND rg_ta_sol_apr.par_modalidad = 'S') THEN
          -- Control para excluir de la validacion a personas juridicas y la nueva modalidad 501 BANCARDCHECK  -- GC 30/11/2012
          rg_ta_sol_apr.nom_embozado := '';
        ELSE
          BEGIN
            SELECT substr(TRIM(pri_nombre) || ' ' || TRIM(pri_apellido),
                          1,
                          20)
              INTO rg_ta_sol_apr.nom_embozado
              FROM ba_per_fisicas
             WHERE cod_persona = rg_ta_sol_apr.cod_persona;
          EXCEPTION
            WHEN no_data_found THEN
              v_error := nvl(v_error, '') || '#' || 'Persona ' ||
                         rg_ta_sol_apr.cod_persona ||
                         ' no registrada como física';
            WHEN OTHERS THEN
              v_error := nvl(v_error, '') || '#' ||
                         'Error al buscar persona : ' || SQLERRM;
          END;
        END IF;
      ELSE
        rg_ta_sol_apr.nom_embozado := pat_val.fu_eli_acentos(i.nom_embozado);
      END IF;
      --* Recuperar direccion de envio  --Icl 10/07/09  RI
      IF nvl(rg_ta_sol_apr.tip_envio, 'D') = 'D' THEN
        BEGIN
          SELECT cod_direccion
            INTO rg_ta_sol_apr.referencia
            FROM ba_direcciones
           WHERE cod_persona = rg_ta_sol_apr.cod_persona
             AND cod_direccion = i.referencia;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              SELECT cod_direccion
                INTO rg_ta_sol_apr.referencia
                FROM ba_direcciones
               WHERE cod_persona = rg_ta_sol_apr.cod_persona
                 AND rownum = 1;
            EXCEPTION
              WHEN OTHERS THEN
                rg_ta_sol_apr.tip_envio  := 'R';
                rg_ta_sol_apr.referencia := 1;
            END;
          WHEN OTHERS THEN
            rg_ta_sol_apr.tip_envio  := 'R';
            rg_ta_sol_apr.referencia := 1;
        END;
      ELSE
        rg_ta_sol_apr.tip_envio  := 'R';
        rg_ta_sol_apr.referencia := 1; --oficina principal
      END IF;
    END IF;
    --*
    --* RI : 03/03/2010 : Si viene del programa de Solicitudes Pre Embozadas, marcar que la
    --* Solicitud es Pre Embozada.
    --*
    IF nvl(pae_cnf.g_programa, 'x') = 'TPSOLPRE' THEN
      rg_ta_sol_apr.pre_embozada := 'S';
    END IF;
    IF rg_ta_sol_apr.pre_embozada = 'S' THEN
      rg_ta_sol_apr.observacion := 'Alta Masiva de Tarjetas PreEmbozadas.';
    ELSE
      rg_ta_sol_apr.observacion := 'Alta Masiva de Tarjetas.';
    END IF;
    /*
    || Mismo control que se realiza en el trigger TB_TA_SOLICITUDES
    || antes de insertar en TA_SOLICITUDES.
    */
    --IF nvl(pae_cnf.g_programa, 'x') IN ('GMPROARC', 'GMARCHIV', 'TPSOLPRE') THEN
    IF (v_ref_persona <> 'S' AND
       ((rg_ta_sol_apr.par_modalidad <> 'S')
       -- 06/02/2014 PN DI: Se agrega el OR porque en caso de personas físicas debe tambien controlar
       OR (rg_ta_sol_apr.par_modalidad = 'S') AND v_tip_persona = 'F')) THEN
      -- Control para excluir de la validacion a personas juridicas
      -- y la nueva modalidad 501 BANCARDCHECK  -- GC 30/11/2012
      -->
      v_existe := 0;
      SELECT COUNT(*)
        INTO v_existe
        FROM ta_solicitudes a, ta_cta_tarjetas b
       WHERE a.nro_solicitud = b.nro_solicitud
         and b.estado <> 'N'
         and a.cod_persona = rg_ta_sol_apr.cod_persona
         AND a.cod_modalidad = rg_ta_sol_apr.cod_modalidad
         AND a.afinidad = rg_ta_sol_apr.afinidad
         AND nvl(a.sub_afinidad, 'ZZ') =
             nvl(rg_ta_sol_apr.sub_afinidad, 'ZZ')
         AND a.cod_estado <> 'RCH';
      --<
      if v_existe = 0 then
        v_existe := 0;
        SELECT COUNT(*)
          INTO v_existe
          FROM ta_solicitudes
         WHERE cod_persona = rg_ta_sol_apr.cod_persona
           AND cod_modalidad = rg_ta_sol_apr.cod_modalidad
           AND afinidad = rg_ta_sol_apr.afinidad
           AND nvl(sub_afinidad, 'ZZ') =
               nvl(rg_ta_sol_apr.sub_afinidad, 'ZZ')
           AND cod_estado <> 'RCH';
      end if;
      IF v_existe <> 0 THEN
        v_error := nvl(v_error, '') || '#' || 'La persona : ' ||
                   rg_ta_sol_apr.cod_persona ||
                   ' ya posee solicitud activa para la modalidad ' ||
                   rg_ta_sol_apr.cod_modalidad || ', afinidad ' ||
                   rg_ta_sol_apr.afinidad || ' y sub-afinidad ' ||
                   rg_ta_sol_apr.sub_afinidad || '.';
      END IF;
      --
      v_existe := 0;
      SELECT COUNT(*)
        INTO v_existe
        FROM ta_cta_tarjetas c, ta_tarjetas t
       WHERE t.cod_persona = rg_ta_sol_apr.cod_persona
         AND t.cod_estado <> 10
         AND c.nro_cuenta = t.nro_cuenta
         AND c.cod_modalidad = rg_ta_sol_apr.cod_modalidad
         AND c.afinidad = rg_ta_sol_apr.afinidad
         AND nvl(c.sub_afinidad, 'ZZ') =
             nvl(rg_ta_sol_apr.sub_afinidad, 'ZZ');
      IF v_existe <> 0 THEN
        v_error := nvl(v_error, '') || '#' || 'La persona : ' ||
                   rg_ta_sol_apr.cod_persona ||
                   ' ya posee tarjeta para la modalidad ' ||
                   rg_ta_sol_apr.cod_modalidad || ', afinidad ' ||
                   rg_ta_sol_apr.afinidad || ' y sub-afinidad ' ||
                   rg_ta_sol_apr.sub_afinidad || '.';
      END IF;
    END IF;
    --END IF;
    --*
    --* RI:10/09/2010: Controlar que la persona no se encuentre inhibido para solicitar tarjeta
    --*
    if nvl(pae_cnf.g_programa, 'x') <> 'TPSOLPRE' then
      v_existe := 0;
      SELECT COUNT(*)
        INTO v_existe
        FROM ge_par_causales p, ge_causales c, ge_per_inhibidas i
       WHERE i.cod_persona = rg_ta_sol_apr.cod_persona
         AND c.cod_causa = i.cod_causa
         AND p.cod_causa = c.cod_causa
         AND p.parametro = 'AFE_TARJETAS'
         AND i.estado = 'I'
         AND p.val_parametro = 'S';
      IF v_existe <> 0 THEN
        v_error := nvl(v_error, '') || '#' || 'La persona : ' ||
                   rg_ta_sol_apr.cod_persona ||
                   ' se encuentra inhibida para este tipo de cuenta.';
      END IF;
    else
      --BSEVOCORE-919 Excluir el control de clientes inhibidos exceptuando a clientes fallecidos/ fallecido no confirmado.
      v_existe := 0;
      SELECT COUNT(*)
        INTO v_existe
        FROM ge_causales c, ge_per_inhibidas i
       WHERE i.cod_persona = rg_ta_sol_apr.cod_persona
         AND c.cod_causa = i.cod_causa
         AND c.tipo = 'I'
         AND c.cod_causa in (281, 346, 326);
      IF v_existe <> 0 THEN
        v_error := nvl(v_error, '') || '#' || 'La persona : ' ||
                   rg_ta_sol_apr.cod_persona ||
                   ' se encuentra inhibida para este tipo de cuenta.';
      END IF;
    end if;
  
    /*
    || Fin controles TB_TA_SOLICITUDES
    */
    -- Verifica si la cuenta de débito es válido
    IF nvl(rg_ta_sol_apr.deb_automatico, 'N') = 'S' THEN
      rg_ta_sol_apr.nro_cta_debito := i.nro_cta_debito;
      IF rg_ta_sol_apr.nro_cta_debito IS NULL THEN
        v_error := nvl(v_error, '') || '#' ||
                   'Debe ingresar un Nro. de Cuenta valido para débito automático.';
      ELSE
        -- Validar la cuenta de débito
        BEGIN
          v_cta_valida := fug_val_cta_debito(to_char(rg_ta_sol_apr.nro_cta_debito),
                                             c_cod_mon_local,
                                             16);
        EXCEPTION
          WHEN OTHERS THEN
            --DYDMR-7282-Incidencia SAU - ITGF - Error Importacion de Archivo
            v_error := nvl(v_error, '') || '#' || 'Validación Cta. Débito ' ||
                       SQLERRM;
        END;
      END IF;
    ELSE
      rg_ta_sol_apr.nro_cta_debito := NULL;
    END IF;
    -- Verifica si se puede personalizar la tasa
    IF nvl(rg_ta_sol_apr.tas_int_corriente, 0) > 0 OR
       nvl(rg_ta_sol_apr.tas_int_mora, 0) > 0 OR
       nvl(rg_ta_sol_apr.tas_int_compra, 0) > 0 THEN
      BEGIN
        SELECT DISTINCT (nvl(tas_personalizada, 'N'))
          INTO rg_ta_sol_apr.per_tasa
          FROM ta_tipos
         WHERE cod_modulo = 5
           AND cod_modalidad = rg_ta_sol_apr.cod_modalidad
           AND afinidad = rg_ta_sol_apr.afinidad
           AND nvl(sub_afinidad, 'ZZ') =
               nvl(rg_ta_sol_apr.sub_afinidad, 'ZZ');
      EXCEPTION
        WHEN no_data_found THEN
          v_error := nvl(v_error, '') || '#' ||
                     'No se encuentra configuracion de tasa personalizada.' ||
                     'Modalidad ' || rg_ta_sol_apr.cod_modalidad ||
                     ' afinidad ' || rg_ta_sol_apr.afinidad ||
                     ' sub-afinidad ' || rg_ta_sol_apr.sub_afinidad || '.';
        WHEN OTHERS THEN
          v_error := nvl(v_error, '') || '#' ||
                     'Al Obt.Tasa personalizada.Mad:' ||
                     rg_ta_sol_apr.cod_modalidad || ' afinidad ' ||
                     rg_ta_sol_apr.afinidad || '-' || ' sub-afinidad ' ||
                     rg_ta_sol_apr.sub_afinidad || SQLERRM;
      END;
      IF rg_ta_sol_apr.per_tasa = 'N' THEN
        v_error := nvl(v_error, '') || '#' ||
                   'No puede personalizar la tasa para este tipo de tarjeta.' ||
                   'Modalidad ' || rg_ta_sol_apr.cod_modalidad ||
                   ' afinidad ' || rg_ta_sol_apr.afinidad ||
                   ' sub-afinidad ' || rg_ta_sol_apr.sub_afinidad || '.';
      END IF;
    END IF;
    ---
    IF nvl(rg_ta_sol_apr.tas_int_corriente, 0) = 0 THEN
      rg_ta_sol_apr.tas_int_corriente := NULL;
    ELSE
      rg_ta_sol_apr.tas_int_corriente := rg_ta_sol_apr.tas_int_corriente;
    END IF;
    IF nvl(rg_ta_sol_apr.tas_int_mora, 0) = 0 THEN
      rg_ta_sol_apr.tas_int_mora := NULL;
    ELSE
      rg_ta_sol_apr.tas_int_mora := rg_ta_sol_apr.tas_int_mora;
    END IF;
    IF nvl(rg_ta_sol_apr.tas_int_compra, 0) = 0 THEN
      rg_ta_sol_apr.tas_int_compra := NULL;
    ELSE
      rg_ta_sol_apr.tas_int_compra := rg_ta_sol_apr.tas_int_compra;
    END IF;
    -- Verifica los límites del tipo de tarjeta
    IF rg_ta_sol_apr.cod_modalidad IS NOT NULL AND
       c_cod_mon_local IS NOT NULL AND rg_ta_sol_apr.afinidad IS NOT NULL THEN
      BEGIN
        SELECT min_linea, max_linea
          INTO v_lin_min_tarjeta, v_lin_max_tarjeta
          FROM ta_tipos
         WHERE cod_modulo = 5
           AND cod_modalidad = rg_ta_sol_apr.cod_modalidad
           AND afinidad = rg_ta_sol_apr.afinidad
           AND nvl(sub_afinidad, '00') =
               nvl(rg_ta_sol_apr.sub_afinidad, '00')
           AND rownum = 1;
      EXCEPTION
        WHEN OTHERS THEN
          v_lin_min_tarjeta := 0;
          v_lin_max_tarjeta := 0;
      END;
      IF nvl(v_lin_min_tarjeta, 0) = 0 AND nvl(v_lin_max_tarjeta, 0) = 0 THEN
        v_lin_max_tarjeta := fug_obt_pardinamico('LIN_MAX_TARJETA',
                                                 5,
                                                 rg_ta_sol_apr.cod_modalidad,
                                                 c_cod_mon_local,
                                                 i.cod_oficina);
        v_lin_min_tarjeta := fug_obt_pardinamico('LIN_MIN_TARJETA',
                                                 5,
                                                 rg_ta_sol_apr.cod_modalidad,
                                                 c_cod_mon_local,
                                                 i.cod_oficina);
      END IF;
    ELSE
      v_error := nvl(v_error, '') || '#' ||
                 'Al Obt. Minimo y Máximo para el Monto de Línea.';
    END IF;
    IF rg_ta_sol_apr.monto IS NOT NULL THEN
      IF nvl(rg_ta_sol_apr.monto, 0) < v_lin_min_tarjeta THEN
        v_error := nvl(v_error, '') || '#' ||
                   'El monto debe ser mayor o igual a ' ||
                   ltrim(to_char(v_lin_min_tarjeta, '999,999,999,999.99'));
      ELSIF nvl(rg_ta_sol_apr.monto, 0) > v_lin_max_tarjeta THEN
        v_error := nvl(v_error, '') || '#' ||
                   'El monto debe ser menor o igual a ' ||
                   ltrim(to_char(v_lin_max_tarjeta, '999,999,999,999.99'));
      END IF;
    END IF;
    /*
    || Eliminar los acentos y caracteres no válidos.
    */
    -- Datos del Promotor
    IF v_cod_usu_promotor IS NOT NULL THEN
      BEGIN
        SELECT cod_persona
          INTO v_cod_per_promotor
          FROM ba_usuarios
         WHERE cod_usuario = v_cod_usu_promotor;
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_per_promotor := null;
        WHEN OTHERS THEN
          --DYDMR-7282 - Incidencia SAU - ITGF - Error Importacion de Archivo
          v_error := nvl(v_error, '') || '#' || 'Datos Promotor ' ||
                     SQLERRM;
      END;
      IF v_cod_per_promotor IS NOT NULL THEN
        BEGIN
          pat_val.pr_act_acentos('ACT_SOL_ACENTOS', v_cod_per_promotor);
        EXCEPTION
          WHEN OTHERS THEN
            v_error := nvl(v_error, '') || '#' || SQLERRM;
        END;
      END IF;
      -- Validar el correo del Promotor
      BEGIN
        SELECT dir_correo
          INTO v_mail_promotor
          FROM ba_personas
         WHERE cod_persona = v_cod_per_promotor;
      EXCEPTION
        WHEN no_data_found THEN
          null; -- Si no tiene correo no es error
        WHEN OTHERS THEN
          v_error := nvl(v_error, '') || '#' || SQLERRM;
      END;
      IF v_mail_promotor IS NOT NULL THEN
        BEGIN
          v_mail_promotor := pat_val.fu_val_correo(v_mail_promotor,
                                                   v_cod_per_promotor);
        EXCEPTION
          WHEN OTHERS THEN
            --DYDMR-7282 - Incidencia SAU - ITGF - Error Importacion de Archivo
            v_error := nvl(v_error, '') || '#' || 'correo promotor: ' ||
                       v_dir_correo || ' - cod. persona: ' ||
                       v_mail_promotor || '-' || SQLERRM;
        END;
      END IF;
    END IF;
    -- Datos del Oficial
    BEGIN
      SELECT cod_usu_oficial
        INTO v_cod_usu_oficial
        FROM ge_clientes
       WHERE cod_persona = rg_ta_sol_apr.cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_usu_oficial := NULL;
      WHEN OTHERS THEN
        --DYDMR-7282 - Incidencia SAU - ITGF - Error Importacion de Archivo
        v_error := nvl(v_error, '') || '#' || ' Oficial del Cliente ' ||
                   SQLERRM;
    END;
    IF v_cod_usu_oficial IS NOT NULL AND
       nvl(v_cod_usu_oficial, 'A') <> nvl(v_cod_usu_promotor, 'A') THEN
      BEGIN
        SELECT cod_persona
          INTO v_cod_per_oficial
          FROM ba_usuarios
         WHERE cod_usuario = v_cod_usu_oficial;
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_per_oficial := null;
        WHEN OTHERS THEN
          --DYDMR-7282 - Incidencia SAU - ITGF - Error Importacion de Archivo
          v_error := nvl(v_error, '') || '#' || 'Cód. Persona Usu Oficial' ||
                     SQLERRM;
      END;
      IF v_cod_per_oficial IS NOT NULL THEN
        BEGIN
          pat_val.pr_act_acentos('ACT_SOL_ACENTOS', v_cod_per_oficial);
        EXCEPTION
          WHEN OTHERS THEN
            v_error := nvl(v_error, '') || '#' || SQLERRM;
        END;
      END IF;
      -- Validar el correo del Oficial
      -- no se usa el FUG_OBT_DIR_MAIL_PER porque es valido si no tiene correo
      BEGIN
        SELECT dir_correo
          INTO v_mail_oficial
          FROM ba_personas
         WHERE cod_persona = v_cod_per_oficial;
      EXCEPTION
        WHEN no_data_found THEN
          null; -- Si no tiene correo no es error
        WHEN OTHERS THEN
          --DYDMR-7282 - Incidencia SAU - ITGF - Error Importacion de Archivo
          v_error := nvl(v_error, '') || '#' || 'Obt Mail Oficial' ||
                     SQLERRM;
      END;
      IF v_mail_oficial IS NOT NULL THEN
        BEGIN
          v_mail_oficial := pat_val.fu_val_correo(v_mail_oficial,
                                                  v_cod_per_oficial);
        EXCEPTION
          WHEN OTHERS THEN
            --DYDMR-7282 - Incidencia SAU - ITGF - Error Importacion de Archivo
            v_error := nvl(v_error, '') || '#correo oficial: ' ||
                       v_mail_oficial || ' - cod. persona:' ||
                       v_cod_per_oficial || '-' || SQLERRM;
        END;
      END IF;
      --- Valida Oficina del Oficial y de la Solicitud
      BEGIN
        v_ofi_oficial := fug_obt_ofi_oficial(rg_ta_sol_apr.cod_persona);
      EXCEPTION
        WHEN OTHERS THEN
          v_error := nvl(v_error, '') || '#' || SQLERRM;
      END;
      IF v_ofi_oficial <> i.cod_oficina THEN
        v_error := nvl(v_error, '') || '#' ||
                   'La Oficina de la cuenta debe llevar la oficina del Oficial: ' ||
                   fue_obt_des_oficina(fug_obt_ofi_oficial(rg_ta_sol_apr.cod_persona)) || ' (' ||
                   fug_obt_ofi_oficial(rg_ta_sol_apr.cod_persona) || ')';
      END IF;
    ELSE
      --- DYDMR-800 Error al realizar Envio ABM TC a Bancard SC 5179
      --- En PRT_GEN_DAT_ALTAS valida que el promotor y el supervisor no sean el mismo.
      v_cod_usu_promotor := null;
    END IF;
    -- Datos de la Persona
    -- nom_usuario: se obtiene de nom_completo de ba_personas
    -- (se actualiza por trigger de ba_per_fisicas)
    BEGIN
      pat_val.pr_act_acentos('ACT_SOL_ACENTOS', rg_ta_sol_apr.cod_persona);
    EXCEPTION
      WHEN OTHERS THEN
        v_error := nvl(v_error, '') || '#' || SQLERRM;
    END;
    -- Datos de la solicitud
    BEGIN
      rg_ta_sol_apr.nom_embozado := pat_val.fu_eli_acentos(rg_ta_sol_apr.nom_embozado);
    EXCEPTION
      WHEN OTHERS THEN
        v_error := nvl(v_error, '') || '#' || SQLERRM;
    END;
    -- Fin control acentos
    /*
    || Se controla que el correo no esté duplicado
    || Si los emails NO son nulas (tienen algún valor),
    || entonces NO deben ser iguales entre si
    || ---------------------
    || Variables a comparar:
    || ---------------------
    || nvl(v_dir_correo,'a')
    || nvl(v_mail_oficial,'c')
    || nvl(v_mail_promotor,'d')
    */
    IF nvl(v_dir_correo, 'a') = nvl(v_mail_oficial, 'c') THEN
      v_error := nvl(v_error, '') || '#' ||
                 'Correo del Titular se encuentra duplicado con el del Oficial';
    END IF;
    IF nvl(v_dir_correo, 'a') = nvl(v_mail_promotor, 'd') THEN
      v_error := nvl(v_error, '') || '#' ||
                 'Correo del Titular se encuentra duplicado con el del Promotor';
    END IF;
    IF nvl(v_mail_oficial, 'c') = nvl(v_mail_promotor, 'd') THEN
      --- v_error := nvl(v_error, '') || '#'
      ---        || 'Correo del Oficial se encuentra duplicado con el del Promotor';
      --- DYDMR-800 Error al realizar Envio ABM TC a Bancard SC 5179
      --- En PRT_GEN_DAT_ALTAS valida que el promotor y el supervisor no sean el mismo.
      v_mail_promotor := null;
    END IF;
    -- Fin control correos
    --
    /*
    || Verificar que tenga direccion sea correcta para envio de extracto
    || AAP 28-08-2007
    */
    BEGIN
      SELECT substr(decode(e.tip_envio,
                           'D',
                           d.direccion ||
                           decode(numero, NULL, '', ' ' || numero),
                           -- Direccion
                           'R',
                           o.descripcion,
                           NULL),
                    1,
                    50) dir_envio
        INTO v_dir_cliente
        FROM ba_barrios         b,
             ba_ciudades        c,
             ba_paises          p,
             ba_direcciones     d,
             ge_dir_retenciones o,
             ge_dir_envios      e
       WHERE p.cod_pais(+) = d.cod_pais
         AND c.cod_pais(+) = d.cod_pais
         AND c.cod_ciudad(+) = d.cod_ciudad
         AND b.cod_pais(+) = d.cod_pais
         AND b.cod_ciudad(+) = d.cod_ciudad
         AND b.cod_barrio(+) = d.cod_barrio
         AND d.cod_persona(+) = e.cod_persona
         AND d.cod_direccion(+) = e.referencia
         AND o.cod_dir_retencion(+) = e.referencia
         AND e.cod_persona = rg_ta_sol_apr.cod_persona
         AND e.nro_cuenta IS NULL;
      IF v_dir_cliente IS NULL THEN
        RAISE no_data_found;
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        /* BSEVOCORE-919 Si no tiene dirección de envío definida*/
        if nvl(pae_cnf.g_programa, 'x') = 'TPSOLPRE' then
          BEGIN
            if rg_ta_sol_apr.tip_envio = 'D' then
              --Sí el tipo de envio es Dirección, obtiene la direccion principal
              select substr(d.direccion ||
                            decode(numero, NULL, '', ' ' || numero),
                            1,
                            50)
                into v_dir_cliente
                from ba_direcciones d
               where d.cod_persona = rg_ta_sol_apr.cod_persona
                 and d.principal = 'S';
            elsif rg_ta_sol_apr.tip_envio = 'R' then
              --Sí el tipo de envio es Retener, obtener la oficina del cliente
              select fue_obt_des_oficina(i.cod_oficina)
                into v_dir_cliente
                from dual;
            end if;
          EXCEPTION
            WHEN no_data_found THEN
              v_error := nvl(v_error, '') || '#' ||
                         'Cliente no tiene definida una dirección principal' ||
                         'Verifique en la carpeta de la persona';
          END;
        else
          v_error := nvl(v_error, '') || '#' ||
                     'Cliente no tiene definida una dirección ' ||
                     'Válida para el envío del Extracto. ' ||
                     'Verifique en la carpeta de la persona';
        end if;
      
      WHEN OTHERS THEN
        v_error := nvl(v_error, '') || '#' ||
                   'Cliente tiene definida una dirección ' ||
                   'NO Válida para el envío del Extracto. ' ||
                   'Verifique en la carpeta de la persona';
    END;
    IF i.monto = 0 AND i.par_modalidad = 'S' THEN
      v_error := nvl(v_error, '') || '#' ||
                 'Monto no puede ser 0 para esta modalidad.';
    END IF;
  
    /*
    || Verificar que la campaña y canal sean de Tarjetas Preembozadas
    || MDPCLACLI-3
    */
    BEGIN
      select distinct (a.cod_campana), a.descripcion
        into v_cod_campana, v_cod_cam_preaprobado
        from cr_campanas a, cr_cam_productos b
       where /*upper (a.detalle) like '%PRE%APROBADO%'
                             and*/
       a.cod_campana = b.cod_campana
       and b.cod_modulo = 5
       and a.cod_campana = i.cod_campana;
    EXCEPTION
      when no_data_found then
        v_cod_campana         := null;
        v_cod_cam_preaprobado := null;
    END;
  
    BEGIN
      select a.cod_canal, a.cod_tip_canal
        into v_cod_canal, v_cod_can_preaprobado
        from GE_CANALES a
       where /*a.cod_tip_canal = 11 --PRE-APROBADOS
                             and*/
       a.cod_canal = i.cod_canal;
    EXCEPTION
      when no_data_found then
        v_cod_canal           := null;
        v_cod_can_preaprobado := null;
    END;
  
    --IF v_cod_campana is not null and v_cod_canal is not null then
    IF v_cod_cam_preaprobado like '%PRE%APROBADO%' and
       v_cod_can_preaprobado = 11 and i.tar_adicional = 'N' then
      BEGIN
        INSERT INTO BA_TAB_DAT_ADICIONALES
          (tab_relacion, referencia, parametro, val_parametro)
        VALUES
          ('TA_SOLICITUDES',
           nvl(p_nro_solicitud, rg_ta_sol_apr.nro_solicitud),
           'COSTO',
           'N');
      EXCEPTION
        WHEN dup_val_on_index THEN
          update BA_TAB_DAT_ADICIONALES
             set val_parametro = 'N'
           where TAB_RELACION = 'TA_SOLICITUDES'
             and PARAMETRO = 'COSTO'
             and REFERENCIA =
                 nvl(p_nro_solicitud, rg_ta_sol_apr.nro_solicitud);
        WHEN OTHERS THEN
          v_error := 'No se pudo insertar en ba_tab_dat_adicionales. ' ||
                     SQLERRM;
      END;
    END IF;
    --fin control campaña canal
  
    --- Actualiza los datos importados por los válidos
    UPDATE ta_sol_aprobadas_tmp a
       SET tip_envio         = nvl(rg_ta_sol_apr.tip_envio, 'D'),
           retener           = rg_ta_sol_apr.retener,
           nom_embozado      = rg_ta_sol_apr.nom_embozado,
           adicionales       = rg_ta_sol_apr.adicionales,
           deb_automatico    = rg_ta_sol_apr.deb_automatico,
           tip_cobro         = rg_ta_sol_apr.tip_cobro,
           cod_persona       = rg_ta_sol_apr.cod_persona,
           afinidad          = rg_ta_sol_apr.afinidad,
           sub_afinidad      = rg_ta_sol_apr.sub_afinidad,
           cod_modalidad     = rg_ta_sol_apr.cod_modalidad,
           par_modalidad     = rg_ta_sol_apr.par_modalidad,
           referencia        = rg_ta_sol_apr.referencia,
           pre_embozada      = rg_ta_sol_apr.pre_embozada,
           observacion       = rg_ta_sol_apr.observacion,
           nro_cta_debito    = rg_ta_sol_apr.nro_cta_debito,
           per_tasa          = rg_ta_sol_apr.per_tasa,
           tas_int_corriente = rg_ta_sol_apr.tas_int_corriente,
           tas_int_mora      = rg_ta_sol_apr.tas_int_mora,
           tas_int_compra    = rg_ta_sol_apr.tas_int_compra,
           nro_solicitud     = rg_ta_sol_apr.nro_solicitud
     WHERE a.rowid = i.fila;
    COMMIT;
    -- DYDMR-11446 Implementa Plastico Contactless
    IF nvl(fug_val_dat_parametros('TRC_TIP_PLA_CLESS',
                                  5,
                                  rg_ta_sol_apr.cod_modalidad,
                                  null,
                                  rg_ta_sol_apr.afinidad,
                                  'N'),
           0) > 0 then
      v_tip_plastico := 'L';
    ELSE
      -- 01.10.2013 RABP-PCC: Verificamos si el modulo y la afinidad corresponde a Chip
      IF instr(fug_obt_pardinamico('TRC_TIP_PLA_CHIP',
                                   5,
                                   rg_ta_sol_apr.cod_modalidad),
               rg_ta_sol_apr.afinidad) > 0 THEN
        v_tip_plastico := 'C';
      ELSE
        v_tip_plastico := 'N';
      END IF;
    END IF;
    /*
    || Ejecuta el alta de la tarjeta
    */
    IF v_error IS NULL THEN
      IF I.TAR_ADICIONAL = 'N' THEN
        IF nvl(pae_cnf.g_programa, 'x') = 'TPSOLPRE' and
           v_tip_persona = 'F' then
          BEGIN
            insert into ba_tab_dat_adicionales
              (tab_relacion, referencia, parametro, val_parametro)
            values
              ('TA_SOLICITUDES',
               rg_ta_sol_apr.nro_solicitud,
               'RET_EXTRACTO',
               'S');
          EXCEPTION
            WHEN OTHERS THEN
              v_error := 'No se puede insertar el Tipo de Extracto. ' ||
                         SQLERRM;
          END;
        
          BEGIN
            insert into ba_tab_dat_adicionales
              (tab_relacion, referencia, parametro, val_parametro)
            values
              ('TA_SOLICITUDES',
               rg_ta_sol_apr.nro_solicitud,
               'MOT_RET_EXTRACTO',
               nvl(v_mot_ret_extracto, '5'));
          EXCEPTION
            WHEN OTHERS THEN
              v_error := 'No se puede insertar el Motivo de Retención de Extracto. ' ||
                         SQLERRM;
          END;
        END IF;
      
        BEGIN
          INSERT INTO ta_solicitudes
            (nro_solicitud,
             cod_persona,
             cod_oficina,
             cod_modulo,
             cod_modalidad,
             cod_usu_promotor,
             fec_solicitud,
             cod_usu_oficial,
             fec_aprobacion,
             cod_causa,
             deb_automatico,
             nro_cta_debito,
             tip_cobro,
             nom_embozado,
             lin_sugerida,
             monto,
             puntaje,
             cod_estado,
             cod_est_sugerido,
             tas_int_adelanto,
             tas_financiacion,
             tas_mora,
             mto_min_pago,
             por_pag_minimo,
             tip_envio,
             referencia,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             nro_linea,
             observacion,
             cod_moneda,
             cod_campana,
             cod_canal,
             mto_aprobado,
             niv_aprobacion,
             nro_acta,
             nro_cuenta,
             afinidad,
             sub_afinidad,
             pre_embozada,
             cod_tip_cierre,
             tas_int_corriente,
             tas_int_mora,
             tas_int_compra,
             mto_fij_pag_minimo,
             mto_min_pag_minimo,
             tip_plastico,
             cod_rub_economico)
          VALUES
            (rg_ta_sol_apr.nro_solicitud,
             rg_ta_sol_apr.cod_persona,
             i.cod_oficina,
             5,
             rg_ta_sol_apr.cod_modalidad,
             v_cod_usu_promotor,
             c_fecha,
             v_cod_usu_oficial,
             c_fecha,
             NULL,
             rg_ta_sol_apr.deb_automatico,
             rg_ta_sol_apr.nro_cta_debito,
             rg_ta_sol_apr.tip_cobro,
             rg_ta_sol_apr.nom_embozado,
             NULL,
             i.monto,
             NULL,
             'APR',
             NULL,
             NULL,
             NULL,
             NULL,
             NULL,
             rg_ta_sol_apr.por_pag_minimo,
             nvl(rg_ta_sol_apr.tip_envio, 'D'),
             rg_ta_sol_apr.referencia,
             USER,
             SYSDATE,
             USER,
             SYSDATE,
             NULL,
             rg_ta_sol_apr.observacion,
             'GS',
             v_cod_campana,
             v_cod_canal,
             i.monto,
             NULL,
             NULL,
             NULL,
             rg_ta_sol_apr.afinidad,
             rg_ta_sol_apr.sub_afinidad,
             rg_ta_sol_apr.pre_embozada,
             i.cod_tip_cierre,
             rg_ta_sol_apr.tas_int_corriente,
             rg_ta_sol_apr.tas_int_mora,
             rg_ta_sol_apr.tas_int_compra,
             rg_ta_sol_apr.mto_fij_pag_minimo,
             rg_ta_sol_apr.mto_min_pag_minimo,
             v_tip_plastico,
             nvl(i.cod_rub_economico, v_cod_rub_economico));
        EXCEPTION
          WHEN OTHERS THEN
            v_error := 'No se pudo crear la solicitud ' || SQLERRM;
        END;
      ELSE
        -- INSERTAR ADICIONALES
        IF I.NRO_DOC_TITULAR IS NOT NULL THEN
          Begin
            Select ts.nro_solicitud
              into v_nro_sol_titular
              from ta_sol_aprobadas_tmp ts
             where ts.nro_documento = i.nro_doc_titular
               and ts.adicionales = 'S'
               and ts.nro_solicitud is not null;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_error           := 'No Existe Nro. Solicitud del Titular. No se pudo crear la solicitud del Adicional' ||
                                   SQLERRM;
              v_nro_sol_titular := null;
            WHEN OTHERS THEN
              v_error           := 'No se pudo crear la solicitud del Adicional' ||
                                   SQLERRM;
              v_nro_sol_titular := null;
          End;
          if v_nro_sol_titular is not null then
            BEGIN
              insert into ta_sol_adicionales
                (nro_solicitud,
                 cod_persona,
                 cod_estado,
                 fec_ingreso,
                 nom_embozado,
                 cod_usu_autoriza,
                 cod_usu_promotor,
                 cod_usu_oficial,
                 cod_canal,
                 observacion)
              values
                (v_nro_sol_titular,
                 rg_ta_sol_apr.cod_persona,
                 'APR',
                 sysdate,
                 rg_ta_sol_apr.nom_embozado,
                 null,
                 v_cod_usu_promotor,
                 v_cod_usu_oficial,
                 v_cod_canal,
                 'Alta Masiva de Tarjetas PreEmbozadas Adicional.');
            EXCEPTION
              WHEN OTHERS THEN
                v_error := 'No se pudo crear la solicitud del Adicional' ||
                           SQLERRM;
            END;
          end if;
        ELSE
          v_error := 'Nro. Documento Titular Vacion. No se pudo crear la solicitud del Adicional' ||
                     SQLERRM;
        END IF;
      END IF;
    END IF;
    ---
    lp_ins_log_error;
  
    <<siguiente_registro>>
    NULL;
    -- Si no hubo error debe actualizar a nulo si es reproceso
    UPDATE ta_sol_aprobadas_tmp a
       SET det_error = substr(v_error, 1, 4000) --DYDMR-7282-Incidencia SAU - ITGF - Error Importacion de Archivo
     WHERE a.rowid = i.fila;
  END LOOP;
  --- Borrar las solicitudes creadas
  DELETE ta_sol_aprobadas_tmp WHERE det_error IS NULL;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'Al actualizar solicitudes pre-aprobadas:' ||
                            SQLERRM);
END prt_act_sol_aprobada;
/

