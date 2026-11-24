CREATE OR REPLACE PROCEDURE IT.prg_val_cta_eli_onboarding
(
   p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
   p_cod_modulo    IN ge_cuentas.cod_modulo%TYPE,
   p_cod_modalidad IN ge_cuentas.cod_modalidad%TYPE,
   p_msj_error     OUT varchar2,
   p_cod_error     OUT number
) IS

   /* Verifica si el estado de la cuenta es X o A. */
   FUNCTION lf_ver_est_cuenta(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN BOOLEAN;
   /* Verificar si la cuenta es debito de alguna otra. */
   FUNCTION lf_ver_cta_debito(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN VARCHAR2;
   --Solo modulos 3 (31 y 33) y 4 cda y cta_cte
   --validar que la cuenta se encuentre en estado X o A.
   --que no exista como cta de debito de otra cuenta.

   /* Verifica si el usuario puede eliminar cta de funionarios*/
   FUNCTION lf_eli_cta_empleado(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN BOOLEAN;

   v_msj VARCHAR2(500) := 'Cuenta no permite eliminacion.';

   /* Verifica si el estado de la cuenta es X o A. */
   FUNCTION lf_ver_est_cuenta(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN BOOLEAN IS
      vaux VARCHAR2(1);
   BEGIN
      v_msj := 'Estado de la Cuenta no permite eliminacion';
      SELECT 'x'
        INTO vaux
        FROM ge_cuentas a
       WHERE ((estado IN ('X', 'A') AND cod_modulo IN (3, 4, 7)) OR
             (estado IN ('S', 'C') AND cod_modulo = 8) OR (estado = 'S' AND cod_modulo = 10))
         AND nro_cuenta = p_nro_cuenta;
      IF p_cod_modulo = 8 THEN
         IF p_cod_modalidad = 81 THEN
            BEGIN
               SELECT 'x'
                 INTO vaux
                 FROM cx_cta_importaciones
                WHERE nro_cuenta = p_nro_cuenta
                  AND (estado = 'S' OR (estado = 'C' AND fec_solicitud = fec_cancelacion));
            EXCEPTION
               WHEN OTHERS THEN
                  RETURN FALSE;
            END;
            RETURN TRUE;
         ELSE
            RETURN TRUE;
         END IF;
      ELSIF p_cod_modulo = 10 THEN
         SELECT 'x'
           INTO vaux
           FROM md_cta_documentos t
          WHERE t.nro_cuenta = p_nro_cuenta
            AND t.estado = 'S';
         RETURN TRUE;
      ELSE
         v_msj := 'La cuenta posee algun saldo pendiente. Verifique';
      END IF;
      IF p_cod_modalidad in (31, 38, 39,334) THEN
         SELECT 'x'
           INTO vaux
           FROM ah_cta_vistas t
          WHERE nro_cuenta = p_nro_cuenta
            AND nvl(sal_total, 0) = 0
            AND nvl(sal_bloqueado, 0) = 0
            AND nvl(sal_retenido, 0) = 0
            AND nvl(mto_deb_pendientes, 0) = 0
            AND nvl(mto_cre_pendientes, 0) = 0
            AND nvl(mto_cre_a_confirmar, 0) = 0;
      ELSIF p_cod_modalidad = 32 THEN
         SELECT 'x'
           INTO vaux
           FROM ah_cta_plazos t
          WHERE nro_cuenta = p_nro_cuenta
            AND nvl(sal_total, 0) = 0
            AND nvl(sal_bloqueado, 0) = 0
            AND nvl(sal_retenido, 0) = 0;
      ELSIF p_cod_modalidad IN (33, 34) THEN
         SELECT 'x'
           INTO vaux
           FROM ah_cta_certificados t
          WHERE nro_cuenta = p_nro_cuenta
            AND nvl(sal_total, 0) = 0
            AND nvl(sal_bloqueado, 0) = 0
            AND nvl(sal_retenido, 0) = 0;
         v_msj := 'Cuenta tiene asignado ya tiene asignado Numero de CDA';
         SELECT 'x'
           INTO vaux
           FROM ah_cta_certificados t
          WHERE nro_cuenta = p_nro_cuenta
            AND nro_certificado IS NULL;
      ELSIF p_cod_modalidad = 41 THEN
         SELECT 'x'
           INTO vaux
           FROM cc_cta_corrientes t
          WHERE nro_cuenta = p_nro_cuenta
            AND nvl(sal_total, 0) = 0
            AND nvl(sal_bloqueado, 0) = 0
            AND nvl(sal_retenido, 0) = 0
            AND nvl(mto_deb_pendientes, 0) = 0
            AND nvl(mto_cre_pendientes, 0) = 0
            AND nvl(mto_cre_a_confirmar, 0) = 0;
      ELSIF p_cod_modalidad = 70 THEN
         SELECT 'x' INTO vaux FROM lc_cta_cambios t WHERE nro_cuenta = p_nro_cuenta;
      ELSE
         RETURN FALSE;
      END IF;
      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN FALSE;
   END;
   /* Verificar si la cuenta es debito de alguna otra. */
   FUNCTION lf_ver_cta_debito(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN VARCHAR2 IS
      --ver si existe en alguna emitir msj q existe y de que cuenta es
      CURSOR pres IS
         SELECT nro_cuenta FROM pr_cta_prestamos WHERE nro_cta_debito = p_nro_cuenta;
      CURSOR sol IS
         SELECT nro_solicitud FROM pr_solicitudes WHERE nro_cta_debito = p_nro_cuenta;
      CURSOR cob IS
         SELECT nro_cuenta FROM ta_cobros WHERE nro_cta_debito = p_nro_cuenta;
      CURSOR tarj IS
         SELECT nro_cuenta FROM ta_cta_tarjetas WHERE nro_cta_debito = p_nro_cuenta;

      v_cta ge_cuentas.nro_cuenta%TYPE;
      v_msj VARCHAR2(500) := 'Cta. utilizada como Cta. de Debito ';
   BEGIN
      FOR reg IN pres LOOP
         v_cta := reg.nro_cuenta;
         v_msj := v_msj || ' del prest. ' || v_cta;
         EXIT;
      END LOOP;
      --si no encontro prestamo, seguir buscando
      IF v_cta IS NULL THEN
         FOR reg IN sol LOOP
            v_cta := to_char(reg.nro_solicitud);
            v_msj := v_msj || 'de la Solicitud de Prest. ' || v_cta;
            EXIT;
         END LOOP;
      END IF;
      --si no encontro titular tarj, seguir buscando
      IF v_cta IS NULL THEN
         FOR reg IN tarj LOOP
            v_cta := reg.nro_cuenta;
            v_msj := v_msj || 'de la Tarj. ' || v_cta;
            EXIT;
         END LOOP;
      END IF;
      --si no encontro tarj, seguir buscando
      IF v_cta IS NULL THEN
         FOR reg IN cob LOOP
            v_cta := reg.nro_cuenta;
            v_msj := v_msj || 'en cobro de Tarj. ' || v_cta;
            EXIT;
         END LOOP;
      END IF;
      --si no encontro cobro tarj, puede borrar
      IF v_cta IS NULL THEN
         RETURN 'OK';
      ELSE
         RETURN v_msj;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_msj_error:= 'Verif.Cta Debito -' || SQLERRM;
         p_cod_error:=9;
   END;

   /* Verificar si la cuenta tiene movimientos. */
   FUNCTION lf_ver_mov_cuenta(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN BOOLEAN IS
      v_existe NUMBER;
   BEGIN
      SELECT 1
        INTO v_existe
        FROM gv_movimientos
       WHERE nvl(monto, 0) <> 0
         AND nro_cuenta = p_nro_cuenta
         AND reversado = 'N';
      RETURN FALSE;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN TRUE;
      WHEN too_many_rows THEN
         RETURN FALSE;
      WHEN OTHERS THEN
         RETURN FALSE;
   END;
   /* Verificar si la cuenta tiene debitos pendientes. */
   FUNCTION lf_ver_deb_pendiente(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN VARCHAR2 IS
      CURSOR ver IS
         SELECT 'GE_DEB_PENDIENTES' tabla, 'La Cta. posee Debitos Pendientes' descri
           FROM ge_deb_pendientes
          WHERE nro_cuenta = p_nro_cuenta
            AND rownum = 1
         UNION
         SELECT 'AH_TAR_DEBITOS' tabla, 'Cta. utilizada en Tarjetas de Debito' descri
           FROM ah_tar_debitos g
          WHERE nro_cuenta = p_nro_cuenta
           AND  EXISTS (SELECT *
                   FROM ah_cta_vistas v
                  WHERE nro_cuenta = g.nro_cuenta
                    AND estado not in ('A','X'))
            AND rownum = 1
         UNION
         SELECT 'CC_CHEQUERAS' tabla, 'La Cta. posee Chequeras' descri
           FROM cc_chequeras
          WHERE nro_cuenta = p_nro_cuenta
            AND rownum = 1
         UNION
         SELECT 'CC_LIN_SOBREGIROS' tabla, 'La Cta. posee Lineas de Sobregiro' descri
           FROM cc_lin_sobregiros
          WHERE nro_cuenta = p_nro_cuenta
            AND rownum = 1
         UNION
         SELECT 'CC_SOL_CHEQUERAS' tabla, 'La Cta. posee Solicitudes de Chequeras' descri
           FROM cc_sol_chequeras
          WHERE nro_cuenta = p_nro_cuenta
            AND rownum = 1;

      v_msj VARCHAR2(1000);
   BEGIN
      FOR reg IN ver LOOP
         v_msj := reg.descri || '<' || reg.tabla || '>';
         EXIT;
      END LOOP;
      IF v_msj IS NULL THEN
         RETURN 'OK';
      ELSE
         RETURN v_msj;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_msj_error:= 'Verif.Cta -' || SQLERRM;
         p_cod_error:=10;
   END;

   /* Verificar si la cuenta esta en ctas combinadas. */
   FUNCTION lf_ver_cta_combinada(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN BOOLEAN IS
      --ver si existe en alguna emitir msj q existe y de que cuenta es
      v_existe NUMBER;
   BEGIN
      SELECT 1
        INTO v_existe
        FROM cc_cta_combinadas
       WHERE nro_cta_ahorro = p_nro_cuenta
      UNION
      SELECT 1
        FROM cc_cta_combinadas
       WHERE nro_cta_cte = p_nro_cuenta;
      RETURN FALSE;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN TRUE;
      WHEN too_many_rows THEN
         RETURN FALSE;
      WHEN OTHERS THEN
         RETURN FALSE;
   END;

   /* Verifica si el usuario puede eliminar cta de funionarios*/
   FUNCTION lf_eli_cta_empleado(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN BOOLEAN IS

      v_cod_persona ba_personas.cod_persona%TYPE;

   BEGIN
      SELECT cod_persona
        INTO v_cod_persona
        FROM ge_cta_clientes
       WHERE nro_cuenta = p_nro_cuenta
         AND relacion = 'P';

      IF fue_obt_ve_cta_cli(USER, v_cod_persona) = 'N' THEN
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN FALSE;
   END;

BEGIN
   --solo ahorros vistas, cdas y ctas ctes, comex, limite de cambio
   p_cod_error:=0;
   p_msj_error:=null;
   IF p_cod_modulo NOT IN (3, 4, 7, 8, 10) THEN
     p_msj_error:='Solo pueden eliminarse Ctas de Ahorro, Corrientes, L?mite de Cambio, CCI o CCE';
     p_cod_error:=1;
   ELSIF p_cod_modulo = 3 THEN
      IF p_cod_modalidad NOT IN (31, 33, 34, 38, 39,334) THEN
        p_msj_error:= 'Solo pueden eliminarse Ahorros Vista o CDA/Titulos';
        p_cod_error:=2;
      END IF;
   END IF;
   IF lf_ver_est_cuenta(p_nro_cuenta) THEN
      -- Verifica si el usuario puede eliminar cta de funionarios
      IF NOT lf_eli_cta_empleado(p_nro_cuenta) THEN
         p_msj_error:= 'Cta. de Funcionario ';
         p_cod_error:=3;
      END IF;
      --puede continuar el estado es X o A
      v_msj := lf_ver_cta_debito(p_nro_cuenta);
      IF v_msj <> 'OK' THEN
         p_msj_error:= v_msj;
         p_cod_error:=4;
      END IF;
      --verifica que no exista en cuentas combinadas
      IF NOT lf_ver_cta_combinada(p_nro_cuenta) THEN
         p_msj_error:= 'Cta. utilizada en Ctas. Combinadas ';
         p_cod_error:=5;
      END IF;
      --verificar que no existan movimientos de dinero de la cuenta para eliminar
      IF NOT lf_ver_mov_cuenta(p_nro_cuenta) THEN
         p_msj_error:= 'La Cta. ya posee Movimientos ';
         p_cod_error:=6;
      END IF;
      --verifica que no exista en las tablas
      v_msj := lf_ver_deb_pendiente(p_nro_cuenta);
      IF v_msj <> 'OK' THEN
         p_msj_error:= v_msj;
         p_cod_error:=7;
      END IF;
   ELSE
      p_msj_error:= v_msj;
      p_cod_error:=8;
   END IF;
END;
/

