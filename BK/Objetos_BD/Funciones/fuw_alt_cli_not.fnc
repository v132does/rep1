CREATE OR REPLACE FUNCTION IT.fuw_alt_cli_not(p_cod_persona IN BA_PERSONAS.COD_PERSONA%TYPE,
                                                   p_cod_destino IN BW_NOT_CLI_DESTINO.COD_DESTINO%TYPE,
                                                   p_direccion IN BW_NOT_CLI_DESTINO.DIRECCION%TYPE, 
                                                   p_cod_origen IN BW_NOT_CLI_DESTINO.COD_ORIGEN%TYPE,
                                                    p_cod_evento IN BW_NOT_EVENTOS.COD_EVENTO%TYPE DEFAULT 0, 
                                                    p_nro_cuenta IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL,
                                                    p_nro_tarjeta IN ta_tarjetas.nro_tarjeta%type) RETURN NUMBER IS
                                                    
    v_template       bw_not_tip_eventos.template%TYPE;
    v_mensaje        bw_not_mensajes.mensaje%TYPE;
    v_ret            NUMBER(3) := 0;
    v_tip_evento     VARCHAR2(15) := 'TAACTTAR';
    v_fec_programada DATE;
     p_fecha       ge_calendarios.fec_actual%TYPE;
--    p_nro_tarjeta bw_not_act_tarjetas_tmp.nro_tarjeta%TYPE ;
 BEGIN
    BEGIN
       INSERT INTO bw_not_cli_suscriptos
          (cod_persona, fec_suscripcion, activo, cod_origen)
       VALUES
          (p_cod_persona, SYSDATE, 'S', p_cod_origen);
    EXCEPTION
       WHEN OTHERS THEN
          RETURN 1;
    END;
    BEGIN
       INSERT INTO bw_not_cli_destino
          (cod_persona, cod_destino, direccion, activo, cod_origen)
       VALUES
          (p_cod_persona, p_cod_destino, p_direccion, 'S', p_cod_origen);
    EXCEPTION
       WHEN OTHERS THEN
          RETURN 2;
    END;
    v_fec_programada := trunc(SYSDATE)+(9/24);

    IF paw_not.fu_obt_not_template(v_tip_evento, v_template, '00') <> 0 THEN
       RETURN 20;
    END IF;
      v_mensaje := utl_lms.format_message(v_template, paw_not.lf_obt_ult_tarjeta(p_nro_tarjeta), to_char(p_fecha, 'dd/mm/yyyy'));
      
    RETURN paw_not.fu_ins_mensaje( 68, p_cod_origen, v_mensaje, p_cod_persona, p_nro_cuenta/* mg p_cod_origen*/, NULL/*v_fec_programada*/, 'S');

 END;
/

