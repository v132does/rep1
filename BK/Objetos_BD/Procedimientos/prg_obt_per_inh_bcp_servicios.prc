create or replace procedure it.prg_obt_per_inh_bcp_servicios(p_cod_persona in ba_personas.cod_persona%type,
                                                             p_mensaje     out varchar2) is
  v_nro_doc_cli     ba_personas.nro_documento%type := null;
  v_tip_doc_cli_abr ba_tip_documentos.abreviatura%type := null;

  v_guion           NUMBER(2);
  v_dig_verificador NUMBER(2);
  v_parametros      VARCHAR2(3000);
  v_url             VARCHAR2(100) := fug_obt_pardinamico('WS_URL_INH_BCP');
  v_resPost         TYP_POSTRESPUESTA;
  v_mensaje         VARCHAR2(500) := null;
  g_cod_error       number(3);
  g_lugar           varchar2(50);
  g_error           varchar2(2000);

  v_cod_resultado VARCHAR2(10);
  v_categoria     VARCHAR2(100);
  v_des_resultado VARCHAR2(100);

  --registrar log de errores preguntar

  PROCEDURE LP_INS_LOG_ERROR(p_parametros IN VARCHAR2 DEFAULT NULL) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO ge_bcp_dat_log
      (cod_error, error, lugar, parametro)
    VALUES
      (g_cod_error, g_error, g_lugar, p_parametros);
  
    COMMIT;
  EXCEPTION
    WHEN others THEN
      RAISE_APPLICATION_ERROR(-20000, SQLERRM);
  END;

BEGIN
  BEGIN
    SELECT nro_documento,
           decode(fue_obt_tip_doc_abreviatura(cod_tip_documento),
                  'DNI',
                  'CRC',
                  'PAS',
                  'CRC',
                  'SW',
                  'CRC',
                  'OTR',
                  'CRC',
                  'PJ',
                  'CRC',
                  fue_obt_tip_doc_abreviatura(cod_tip_documento))
      INTO v_nro_doc_cli, v_tip_doc_cli_abr
      FROM ba_personas
     WHERE cod_persona = p_cod_persona;
  EXCEPTION
    WHEN others THEN
      v_nro_doc_cli     := null;
      v_tip_doc_cli_abr := null;
  END;
  IF v_tip_doc_cli_abr not in ('RUC', 'CI', 'CRC', 'CRP') THEN
    v_tip_doc_cli_abr := null;
  END IF;
  IF v_tip_doc_cli_abr = 'RUC' THEN
    v_guion := instr(v_nro_doc_cli, '-');
    IF v_guion = 0 THEN
      v_dig_verificador := fue_obt_dig_verificador(v_nro_doc_cli);
      v_nro_doc_cli     := v_nro_doc_cli || '-' || v_dig_verificador;
    END IF;
  END IF;

  IF v_tip_doc_cli_abr is not null AND v_nro_doc_cli is not null THEN
    v_parametros := utl_lms.format_message('{"codTipoDocumento":"%s", "numeroDocumento":"%s"}',
                                           utl_url.escape(v_tip_doc_cli_abr),
                                           utl_url.escape(v_nro_doc_cli));
    --Llama al servicio
    v_resPost := fue_env_bcp_post(p_parametros => v_parametros,
                                  p_url        => v_url);
    --Manejo de respuesta
    IF v_resPost.error != 'N' THEN
      g_cod_error := v_resPost.codigoError;
      g_error     := 'Error: ' || substr(v_resPost.respuesta, 1, 2000);
      g_lugar     := 'Error en el servicio. ';
      lp_ins_log_error(v_parametros);
      v_mensaje := 'Error al consultar servicio de BCP';
    ELSE
    
      SELECT json_value(v_resPost.respuesta,
                        '$.resultado[0].codigoResultado'),
             json_value(v_resPost.respuesta, '$.resultado[0].categoria'),
             json_value(v_resPost.respuesta, '$.resultado[0].descripcionResultado')
        into v_cod_resultado, v_categoria, v_des_resultado
        FROM dual;
    END IF;
    -- Lógica de negocio aquí
    IF v_cod_resultado = '01' AND v_categoria = 'INHABILITADO' THEN
      v_mensaje := 'Cliente inhabilitado en BPC para Cta. Cte';
    ELSIF (v_cod_resultado = '01' AND v_categoria in ('HABILITADO', 'REHABILITADO')) 
      OR v_cod_resultado = '02' THEN
      v_mensaje := null;
    ELSIF v_cod_resultado != '01' THEN 
      v_mensaje := 'Error en validacion de BCP:'|| v_des_resultado;
    END IF;
  END IF;
  IF v_mensaje is not null THEN
    p_mensaje := v_mensaje;
  END IF;
END prg_obt_per_inh_bcp_servicios;
/
