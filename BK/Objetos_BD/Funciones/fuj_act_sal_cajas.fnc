CREATE OR REPLACE FUNCTION IT.fuj_act_sal_cajas
(
   p_nro_documento   IN cj_sobrantes.nro_sobrante%TYPE,
   p_monto           IN cj_sobrantes.saldo%TYPE,
   p_nro_cuenta      IN ge_cuentas.nro_cuenta%TYPE,
   p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
   p_cod_oficina     IN ba_oficinas.cod_oficina%TYPE,
   p_estado          IN cj_sobrantes.estado%TYPE default null
)
/* OMM - Actualiza el saldo de los registros de Faltantes de Caja */
 RETURN VARCHAR2 IS
   v_error          VARCHAR2(1) := 'N'; -- NO(N), SI(S), Error de Saldo Negativo(E)
   v_saldo          cj_sobrantes.saldo%TYPE := 0;
   --v_cta_faltante   ge_cuentas.nro_cuenta%TYPE := null ;
   v_cta_sobrante   ge_cuentas.nro_cuenta%TYPE := null ;
BEGIN
   --v_cta_faltante := fug_obt_pardinamico('NRO_CTA_FAL_CAJA', NULL, NULL, p_cod_moneda, p_cod_oficina);
   v_cta_sobrante := fug_obt_pardinamico('NRO_CTA_SOB_CAJA', NULL, NULL, p_cod_moneda, p_cod_oficina);
   if nvl(v_cta_sobrante,0) = 0 then
      v_error := 'S'; -- no hay cuenta definida para sobrante
   end if;
   IF p_nro_cuenta =  nvl(v_cta_sobrante, '0') THEN
         SELECT (c.saldo - p_monto)
           INTO v_saldo
           FROM cj_sobrantes c
          WHERE c.nro_sobrante = p_nro_documento;
       IF v_saldo < 0 THEN
            v_error := 'E';  -- monto superior al saldo del sobrante
       ELSIF v_saldo = 0 THEN
           IF p_estado IS NOT NULL THEN
               BEGIN
                 UPDATE cj_sobrantes
                    SET saldo  = saldo - p_monto,
                        estado = 'T'
                  WHERE nro_sobrante = p_nro_documento;
              EXCEPTION
                 WHEN OTHERS THEN
                    v_error := 'S'; -- error al actualizar
              END;
           ELSE
              BEGIN
                 UPDATE cj_sobrantes
                    SET saldo  = saldo - p_monto,
                        estado = 'C'
                  WHERE nro_sobrante = p_nro_documento;
              EXCEPTION
                 WHEN OTHERS THEN
                    v_error := 'S'; -- error al actualizar
              END;
          END IF ;
       ELSE
            BEGIN
               UPDATE cj_sobrantes
                  SET saldo = saldo - p_monto
                WHERE nro_sobrante = p_nro_documento;
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := 'S'; -- error al actualizar
            END;
       END IF;
   END IF;
/*  OMM 16/08/2011 Se comenta mientras se desarrolla la parte de Faltante.
   IF p_nro_cuenta = nvl(v_cta_faltante, '0') THEN
         SELECT (c.saldo - p_monto)
           INTO v_saldo
           FROM cj_faltantes c
          WHERE c.nro_faltante = p_nro_documento;
       IF v_saldo < 0 THEN
            v_error := 'E';
       ELSIF v_saldo = 0 THEN
            BEGIN
               UPDATE cj_faltantes
                  SET saldo  = saldo - p_monto,
                      estado = 'C'
                WHERE nro_faltante = p_nro_documento;
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := 'S';
            END;
       ELSE
            BEGIN
               UPDATE cj_faltantes
                  SET saldo = saldo - p_monto
                WHERE nro_faltante = p_nro_documento;
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := 'S';
            END;
       END IF;
   END IF;
*/
 /*  IF v_error = 'E' THEN
    raise_application_error(-20000, 'Error: Monto ingresado mayor al Saldo' );
   ELSIF v_error = 'S' THEN
    raise_application_error(-20000, 'Error al tratar de actualizar el registro.' || SQLERRM);
   END IF;
*/
     RETURN(v_error);

EXCEPTION
   WHEN OTHERS THEN
      v_error := 'S';
      RETURN(v_error);
END;
/

