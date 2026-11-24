CREATE OR REPLACE FUNCTION IT.fuw_obt_mov_pen_encolado(p_cod_per_principal IN ba_personas.cod_persona%TYPE,
                                                    p_cod_tip_mensaje   IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                                    p_nro_cta_debito    IN ge_cuentas.nro_cuenta%TYPE,
                                                    p_mto_debito        IN ge_movimientos.monto%TYPE,
                                                    p_nro_cta_credito   IN ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
                                                    p_referencia        IN NUMBER DEFAULT NULL) RETURN VARCHAR2 IS
   v_existe VARCHAR2(1) := 'N';
BEGIN
   SELECT 'S'
     INTO v_existe
     FROM bw_mov_pendientes p
    WHERE p.cod_per_principal = p_cod_per_principal
      AND p.cod_tip_mensaje = p_cod_tip_mensaje
      AND p.estado = 'E'
      AND p.nro_cuenta = p_nro_cta_debito
      AND p.monto = p_mto_debito
      AND p.nro_cta_contra = nvl(p_nro_cta_credito, p.nro_cta_contra)
      AND p.referencia = nvl(p_referencia, p.referencia)
      AND trunc(p.fec_insercion) >= trunc(sysdate)
      AND rownum = 1;
   RETURN v_existe;
EXCEPTION 
  WHEN OTHERS THEN
     RETURN 'N';
END;
/

