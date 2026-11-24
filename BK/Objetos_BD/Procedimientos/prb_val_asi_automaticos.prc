CREATE OR REPLACE PROCEDURE IT.prb_val_asi_automaticos IS
   /* Validacion de asientos automaticos */
   v_imputable     VARCHAR2(1);
   v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(2);

   ------- para cabecera de asientos ------
   r_cab cb_asi_automaticos%ROWTYPE;
   CURSOR cab IS
      SELECT *
        FROM cb_asi_automaticos
       WHERE nro_asi_real IS NULL
         AND fecha = v_fec_actual;

   ------ detalle de asientos -------
   r_det cb_asi_automaticos_det%ROWTYPE;
   CURSOR det IS
      SELECT *
        FROM cb_asi_automaticos_det
       WHERE cod_oficina = r_cab.cod_oficina
         AND nro_asiento = r_cab.nro_asiento;
   ----------------------------------
   CURSOR cta IS
      SELECT imputable
        FROM cb_rubros
       WHERE cod_rubro = r_det.cod_rubro;
   --
   v_nro_asiento   cb_validaciones.nro_asiento%TYPE;
   v_nro_linea     cb_validaciones.nro_linea%TYPE;
   v_msj_error     cb_validaciones.error%TYPE;
   v_cod_modulo    cb_validaciones.cod_modulo%TYPE;
   v_cod_modalidad cb_validaciones.cod_modalidad%TYPE;
   v_cod_oficina   cb_validaciones.cod_oficina%TYPE;
   v_error         cb_validaciones.error%TYPE;
   --
   PROCEDURE lp_gen_error IS
   BEGIN
      INSERT INTO cb_validaciones
         (fecha, nro_asiento, nro_linea, error, cod_modulo, cod_modalidad, cod_oficina)
      VALUES
         (v_fec_actual, v_nro_asiento, v_nro_linea, v_msj_error, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina);
   END;

BEGIN
   -- limpia archivo CB_VALIDACIONES
   DELETE cb_validaciones WHERE nro_asiento <> -1;
   ----- verifica si hay asientos para validar -----
   OPEN cab;
   LOOP
      FETCH cab
         INTO r_cab;
      EXIT WHEN cab%NOTFOUND;
      ------- INICIO VALIDA CABECERA -------
      v_cod_modulo    := r_cab.cod_modulo;
      v_cod_modalidad := r_cab.cod_modalidad;
      v_nro_asiento   := r_cab.nro_asiento;
      v_cod_oficina   := r_cab.cod_oficina;
      v_nro_linea     := 0;
      v_msj_error     := NULL;
      --------- FIN VALIDA CABECERA --------
      -- ve los detalles de los asientos que corresponden --
      ------------------------------------------------------
      IF det%ISOPEN THEN
         CLOSE det;
      END IF;
      OPEN det;
      LOOP
         FETCH det
            INTO r_det;
         EXIT WHEN det%NOTFOUND;
         v_nro_linea := r_det.nro_linea;
         IF cta%ISOPEN THEN
            CLOSE cta;
         END IF;
         OPEN cta;
         FETCH cta
            INTO v_imputable;
         IF cta%NOTFOUND THEN
            v_msj_error := 'No existe Rubro ' || r_det.cod_rubro || ' en CB_RUBROS';
            lp_gen_error;
         END IF;
      END LOOP;
      v_nro_linea := v_nro_linea + 1;
      IF det%ROWCOUNT = 0 THEN
         v_msj_error := 'No existen lineas de detalle ';
         lp_gen_error;
      END IF;

   END LOOP;
   IF cab%ROWCOUNT = 0 THEN
      raise_application_error(-20000, ' ERROR. No existen asientos para validar en esta fecha');
   END IF;
   CLOSE cab;
   CLOSE det;

   BEGIN
      SELECT nro_asiento, error
        INTO v_nro_asiento, v_error
        FROM cb_validaciones
       WHERE rownum = 1
         AND nro_asiento <> -1;
      IF length(v_error) > 0 THEN
         raise_application_error(-20000,
                                 ' Existe error en el Asiento Nro.: ' || v_nro_asiento ||
                                  ' Error: ' || v_error);
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
   END;

   ---------------------------------
EXCEPTION
   WHEN OTHERS THEN
      IF cab%ISOPEN THEN
         CLOSE cab;
      END IF;
      IF det%ISOPEN THEN
         CLOSE det;
      END IF;
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'Error en la validacion de Asientos Automaticos' || SQLERRM);
      END IF;
END;
/

