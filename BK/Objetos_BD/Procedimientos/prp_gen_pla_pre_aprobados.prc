CREATE OR REPLACE PROCEDURE IT.PRP_GEN_PLA_PRE_APROBADOS IS

  --Cursor del archivo tmp importado.
  CURSOR c_pre_apr_tmp IS
    select a.cod_pla_pre_aprobado,
           a.fec_ini_oferta,
           a.fec_fin_oferta,
           a.cod_oficina,
           a.mon_pre_aprobado,
           a.can_cuota,
           a.tip_amortizacion,
           a.cod_modalidad,
           a.cod_rub_economico,
           a.cod_moneda,
           a.cod_tip_documento,
           a.nro_documento
      from pr_pre_aprobados_tmp a;

  --Declaramos las variables
  v_cod_error     VARCHAR2(5) := 'OK';
  v_msj_error     VARCHAR2(1000) := 'PROCESADO CON EXITO.';
  v_correo        ba_personas.dir_correo%type;
  v_cod_persona   ba_personas.cod_persona%type;
  v_nro_documento ba_personas.nro_documento%type;
  v_apodo         tm_per_lis_blancas.Apodo%type;
  v_nombre        ba_personas.nom_completo%type;
  v_json          long;
  v_existe           VARCHAR2(1) := 'N';
  v_can_registro     NUMBER;
  v_pre_vigente      VARCHAR2(1) := 'N';
  v_can_lim_oferta   NUMBER;
  v_cod_pre_aprobado NUMBER;
  v_cod_usu_oficial  VARCHAR2(10);
  -----
  v_can_dia_vig_pre NUMBER := fug_obt_pardinamico('PRE_CAN_DIA_VIG_PRE_APR');
  v_can_max_oferta  NUMBER := fug_obt_pardinamico('PRE_CAN_MAX_LIM_OFERTA');

BEGIN
  --
  BEGIN
    pre_ini_aplicacion;
  END;
  --
  BEGIN
    SELECT max(cod_pre_aprobado)
      INTO v_cod_pre_aprobado
      FROM pr_pre_aprobados;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_pre_aprobado := 0;
    WHEN OTHERS THEN
      v_cod_pre_aprobado := 0;
  END;
  --
  v_cod_pre_aprobado := nvl(v_cod_pre_aprobado, 0) + 1;
  --
  FOR c IN c_pre_apr_tmp LOOP
    v_can_registro   := 0;
    v_existe         := 'N';
    v_pre_vigente    := 'N';
    v_can_lim_oferta := 0;
    --
    BEGIN
      SELECT count(1)
        INTO v_can_registro
        FROM pr_pre_aprobados_tmp t
       WHERE t.cod_pla_pre_aprobado = c.cod_pla_pre_aprobado
         AND t.cod_tip_documento = c.cod_tip_documento
         AND t.nro_documento     = c.nro_documento;
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_error := 'ERROR';
        v_msj_error := 'REGISTRO NO ENCONTRADO EN LA TABLA TMP.';
      WHEN OTHERS THEN
        v_cod_error := 'ERROR';
        v_msj_error := 'INCONVENIENTE EN EL CONTROL DE DATOS DUPLICADOS.';
    END;
    --
    IF v_can_registro > 1 THEN
      v_cod_error := 'ERROR';
      v_msj_error := 'OFERTA DUPLICADA';
    END IF;
    --Buscar el codigo persona
    BEGIN
      SELECT p.cod_persona
        INTO v_cod_persona
        FROM ba_personas p
       WHERE p.cod_tip_documento = c.cod_tip_documento
         and p.nro_documento     = c.nro_documento;
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_error := 'ERROR';
        v_msj_error := 'PERSONA NO ENCONTRADA.';
    END;
    --
    IF v_cod_error = 'OK' THEN
      BEGIN
        SELECT 'S'
          INTO v_existe
          FROM pr_pre_aprobados a
         WHERE a.cod_persona = v_cod_persona
           AND a.estado in ('G', 'C');
      EXCEPTION
        WHEN no_data_found THEN
          v_existe := 'N';
        WHEN too_many_rows THEN
          v_existe := 'S';
        WHEN OTHERS THEN
          v_existe := 'N';
      END;
      --
      IF v_existe = 'S' THEN
        v_cod_error := 'ERROR';
        v_msj_error := 'El Cliente ya posee otro préstamo pre aprobado vigente.';
      END IF;
      --
      IF v_cod_error = 'OK' THEN
        BEGIN
          SELECT cl.cod_usu_oficial
            INTO v_cod_usu_oficial
            FROM ge_clientes cl
           WHERE cl.cod_persona = v_cod_persona;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_error := 'ERROR';
            v_msj_error := 'CLIENTE SIN OFICIAL DEFINIDO.';
          WHEN OTHERS THEN
            v_cod_error := 'ERROR';
            v_msj_error := 'INCONVENIENTE EN LA BUSQUEDA DEL OFICIAL.';
        END;
        --
        IF v_cod_error = 'OK' THEN
          BEGIN
            SELECT 'S'
              INTO v_pre_vigente
              FROM pr_cta_prestamos p, pr_solicitudes s
             WHERE p.nro_solicitud = s.nro_solicitud
               AND p.cod_modulo = s.cod_modulo
               AND p.cod_modalidad = s.cod_modalidad
               AND p.cod_moneda = s.cod_moneda
               AND p.estado <> 'N'
               AND (pag_cal.FU_OBT_FEC_ACTUAL(p.cod_modulo) - p.fec_inicio) <=
                   v_can_dia_vig_pre
               AND s.cod_persona = v_cod_persona;
          EXCEPTION
            WHEN no_data_found THEN
              v_pre_vigente := 'N';
            WHEN too_many_rows THEN
              v_pre_vigente := 'S';
            WHEN OTHERS THEN
              v_pre_vigente := 'N';
          END;
          --
          IF v_pre_vigente = 'S' THEN
            v_cod_error := 'ERROR';
            v_msj_error := 'El cliente posee un préstamo en los últimos 60 días';
          END IF;
          --
          IF v_cod_error = 'OK' THEN
            BEGIN
              SELECT count(1)
                INTO v_can_lim_oferta
                FROM pr_cta_prestamos p, pr_solicitudes s
               WHERE p.nro_solicitud = s.nro_solicitud
                 AND p.cod_modulo = s.cod_modulo
                 AND p.cod_modalidad = s.cod_modalidad
                 AND p.cod_moneda = s.cod_moneda
                 AND p.estado <> 'N'
                 AND (pag_cal.FU_OBT_FEC_ACTUAL(p.cod_modulo) -
                     p.fec_inicio) > v_can_dia_vig_pre
                 AND s.cod_persona = v_cod_persona;
            EXCEPTION
              WHEN no_data_found THEN
                v_can_lim_oferta := 0;
              WHEN OTHERS THEN
                v_can_lim_oferta := 0;
            END;
            --
            IF v_can_lim_oferta >= v_can_max_oferta THEN
              v_cod_error := 'ERROR';
              v_msj_error := 'El cliente supera el límite de ofertas.';
            END IF;
          END IF;
        END IF;
      END IF;
    END IF;
    --
    IF v_cod_error != 'OK' THEN
      insert into PR_LOG_PRE_APROBADOS
        (COD_PRE_APROBADO, COD_PLA_PRE_APROBADO, COD_PERSONA, ERR_REGISTRO)
      values
        (v_cod_pre_aprobado,
         c.cod_pla_pre_aprobado,
         nvl(v_cod_persona,c.nro_documento),
         v_msj_error);
    ELSE
      insert into pr_pre_aprobados
        (cod_pre_aprobado,
         cod_pla_pre_aprobado,
         fec_ini_oferta,
         fec_fin_oferta,
         cod_oficina,
         cod_usu_oficial,
         cod_persona,
         mon_pre_aprobado,
         can_cuota,
         tip_amortizacion,
         cod_modalidad,
         cod_rub_economico,
         cod_moneda)
      values
        (v_cod_pre_aprobado,
         c.cod_pla_pre_aprobado,
         c.fec_ini_oferta,
         c.fec_fin_oferta,
         c.cod_oficina,
         v_cod_usu_oficial,
         v_cod_persona,
         c.mon_pre_aprobado,
         c.can_cuota,
         c.tip_amortizacion,
         c.cod_modalidad,
         c.cod_rub_economico,
         c.cod_moneda);
      -----------------------------------------------------------------------
      BEGIN
        Select t.dir_correo
          into v_correo
          from ba_personas t
         where t.cod_persona = v_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          prg_ins_log_programas('PRP_GEN_PLA_PRE_APROBADOS',
                                substr('1-Error: ' || sqlerrm, 1, 4000),
                                null,
                                v_cod_persona);
      END;
      BEGIN
        Select t.nro_documento, fug_obt_nombre(t.nom_completo, 1)
          into v_nro_documento, v_nombre
          from ba_personas t
         where t.cod_persona = v_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          prg_ins_log_programas('PRP_GEN_PLA_PRE_APROBADOS',
                                substr('2-Error: ' || sqlerrm, 1, 4000),
                                null,
                                v_cod_persona);
      END;
      BEGIN
        Select t.apodo
          into v_apodo
          from tm_per_lis_blancas t
         where t.nro_documento = v_nro_documento;
      EXCEPTION
        WHEN no_data_found THEN
          v_apodo := v_nombre;
      END;

      v_json := '{' || '"Apodo":' || '"' || v_apodo || '"' || ',' ||
                '"Monto Aprobado":' || '"' || ltrim(rtrim(to_char(c.mon_pre_aprobado,'999,999,999,999,999.99'))) || '"' || ',' ||
                '"Enlace Pantalla":' || '"' ||
                fug_obt_pardinamico('URL_ENLACE_PRE_APROB') || '"' || '}';

      IF v_correo is not null THEN
        insert into ba_env_correos
          (cod_persona, tip_producto, estado, parametros, mai_destinatario)
        values
          (v_cod_persona, 14, 'P', v_json, v_correo);
      ELSE
        prg_ins_log_programas('PRP_GEN_PLA_PRE_APROBADOS',
                              '3-Error: ' ||
                              'Correo no esta cargado en el cliente',
                              null,
                              v_cod_persona);
      END IF;
    END IF;
  END LOOP;
END;
/
