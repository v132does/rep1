CREATE OR REPLACE PROCEDURE IT.prt_gen_lin_pre_aprobados IS

  --Cursor del archivo tmp importado.
  CURSOR c_pre_apr_tmp IS
    select a.cod_pla_pre_aprobado,
           a.fec_ini_oferta,
           a.fec_fin_oferta,
           a.cod_oficina,
           a.mon_pre_aprobado,
           a.cod_modalidad,
           a.cod_rub_economico,
           a.cod_moneda,
           a.cod_tip_documento,
           a.nro_documento
      from ta_lin_pre_aprobado_tmp a;

  --Declaramos las variables
  v_cod_error     VARCHAR2(5) := 'Ok';
  v_msj_error     VARCHAR2(1000) := 'Procesado con exito.';
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
BEGIN
  BEGIN
    pre_ini_aplicacion;
  END;
  BEGIN
    SELECT max(cod_pre_aprobado)
      INTO v_cod_pre_aprobado
      FROM ta_lin_pre_aprobado;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_pre_aprobado := 0;
    WHEN OTHERS THEN
      v_cod_pre_aprobado := 0;
  END;
  v_cod_pre_aprobado := nvl(v_cod_pre_aprobado, 0) + 1;
  FOR c IN c_pre_apr_tmp LOOP
    v_can_registro   := 0;
    v_existe         := 'N';
    v_pre_vigente    := 'N';
    v_can_lim_oferta := 0;
    BEGIN
      SELECT count(1)
        INTO v_can_registro
        FROM ta_lin_pre_aprobado_tmp t
       WHERE t.cod_pla_pre_aprobado = c.cod_pla_pre_aprobado
         AND t.cod_tip_documento = c.cod_tip_documento
         AND t.nro_documento     = c.nro_documento;
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_error := 'Error';
        v_msj_error := 'Registro no encontrado en la tabla tmp.';
      WHEN OTHERS THEN
        v_cod_error := 'Error';
        v_msj_error := 'Inconveniente en el control de datos duplicados.';
    END;
    IF v_can_registro > 1 THEN
      v_cod_error := 'Error';
      v_msj_error := 'Oferta Duplicada';
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
    IF v_cod_error = 'Ok' THEN
      BEGIN
        SELECT 'S'
          INTO v_existe
          FROM ta_lin_pre_aprobado a
         WHERE a.cod_persona   = v_cod_persona
           AND a.estado in ('G', 'C');
      EXCEPTION
        WHEN no_data_found THEN
          v_existe := 'N';
        WHEN too_many_rows THEN
          v_existe := 'S';
        WHEN OTHERS THEN
          v_existe := 'N';
      END;
      IF v_existe = 'S' THEN
        v_cod_error := 'Error';
        v_msj_error := 'El Cliente ya posee otra oferta pre aprobada vigente.';
      END IF;
    END IF;
      IF v_cod_error = 'Ok' THEN
        BEGIN
          SELECT cl.cod_usu_oficial
            INTO v_cod_usu_oficial
            FROM ge_clientes cl
           WHERE cl.cod_persona = v_cod_persona;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_error := 'Error';
            v_msj_error := 'Cliente sin oficial definido.';
          WHEN OTHERS THEN
            v_cod_error := 'Error';
            v_msj_error := 'Inconveniente en la busqueda del oficial.';
        END;
      END IF;
        IF v_cod_error = 'Ok' THEN
              BEGIN
               SELECT 'S'
                  INTO v_pre_vigente
                  FROM ta_cta_tarjetas p, ta_solicitudes s
                 WHERE p.nro_solicitud = s.nro_solicitud
                   AND p.cod_modulo    = s.cod_modulo
                   AND p.cod_modalidad = s.cod_modalidad
                   AND p.cod_moneda    = s.cod_moneda
                   AND s.cod_persona   = v_cod_persona
                   AND p.estado = 'N'
                   AND p.cod_modalidad = c.cod_modalidad
                   AND exists (select 1 from ta_tarjetas ta
                               where ta.nro_cuenta = p.nro_cuenta);
              EXCEPTION
                WHEN no_data_found THEN
                  v_pre_vigente := 'N';
                WHEN too_many_rows THEN
                  v_pre_vigente := 'S';
                WHEN OTHERS THEN
                  v_pre_vigente := 'N';
              END;
              IF v_pre_vigente = 'S' THEN
                v_cod_error := 'Error';
                v_msj_error := 'El cliente ya posse un tarjeta activa';
              END IF;
        END IF;
 IF v_cod_error = 'Ok' then
   IF instr(fug_obt_pardinamico('TA_COD_MOD_PREAPROBADO'),c.cod_modalidad)= 0 THEN
     v_cod_error := 'Error';
     v_msj_error := 'No esta permitida la modalidad'||c.cod_modalidad||'para preaprobados';
   end if;
 end if;

    IF v_cod_error != 'Ok' THEN
      insert into TA_LOG_PRE_APROBADOS
        (COD_PRE_APROBADO, COD_PLA_PRE_APROBADO, COD_PERSONA, ERR_REGISTRO)
      values
        (v_cod_pre_aprobado,
         c.cod_pla_pre_aprobado,
         nvl(v_cod_persona,c.nro_documento),
         v_msj_error);
    ELSE
      insert into ta_lin_pre_aprobado
        (cod_pre_aprobado,
         cod_pla_pre_aprobado,
         fec_ini_oferta,
         fec_fin_oferta,
         cod_oficina,
         cod_usu_oficial,
         cod_persona,
         mon_lin_pre_aprobado,
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
         c.cod_modalidad,
         c.cod_rub_economico,
         c.cod_moneda);
      BEGIN
        Select t.dir_correo
          into v_correo
          from ba_personas t
         where t.cod_persona = v_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          prg_ins_log_programas('PRT_GEN_LIN_PRE_APROBADOS',
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
          prg_ins_log_programas('PRT_GEN_LIN_PRE_APROBADOS',
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
      /*  insert into ba_env_correos
          (cod_persona, tip_producto, estado, parametros, mai_destinatario)
        values
          (c.cod_persona, 14, 'P', v_json, v_correo); */
          null;
      ELSE
        prg_ins_log_programas('PRT_GEN_LIN_PRE_APROBADOS',
                              '3-Error: ' ||
                              'Correo no esta cargado en el cliente',
                              null,
                              v_cod_persona);
      END IF;
    END IF;
  END LOOP;
END;
/
