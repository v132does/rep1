CREATE OR REPLACE PROCEDURE IT."PRB_ASI_MASIVOS" IS

   v_no_coincide_moneda NUMBER(04);
   v_no_tiene_rubro     NUMBER(04);
   v_no_tiene_ofi       NUMBER(04);
   v_multiplicacion     NUMBER(18);

   v_fec_actual DATE;

   v_cod_oficina         NUMBER(03);
   v_cod_ofi_operacion   NUMBER(03);
   v_nro_referencia      NUMBER(15);
   v_cod_rubro           VARCHAR2(15);
   v_cod_rubro_c         cb_rubros.cod_rubro%TYPE;
   v_cod_rubro_d         cb_rubros.cod_rubro%TYPE;
   v_mto_debito_equi_gs  NUMBER;
   v_mto_credito_equi_gs NUMBER;
   v_cod_moneda          ba_monedas.cod_moneda%TYPE;
   v_imputable           cb_rubros.imputable%TYPE;

   --variables para asiento
   v_nro_asiento     cb_asientos.nro_asiento%TYPE;
   v_nro_linea       cb_asientos_det.nro_linea%TYPE := 0;
   v_nro_asi_inter   cb_asientos.nro_asiento%TYPE;
   v_asiento_row     cb_apu_masivos_tmp%ROWTYPE;
   v_tot_control     cb_asientos.tot_control%TYPE := 0;
   v_mov_asiento     cb_asientos_det.tip_movimiento%TYPE;
   v_cod_per_entidad cb_dat_asientos_det.cod_persona%TYPE := fug_obt_per_entidad;
   v_cod_rub_inter   VARCHAR2(15);
   v_referencia      NUMBER;
   v_existe          NUMBER(1) := 0;

   CURSOR asientos_det IS

      SELECT tam.cod_ofi_operacion,
             tam.cod_ofi_destino,
             tam.cod_rubro,
             tam.descripcion,
             tam.tip_mov_rubro,
             tam.cotizacion,
             tam.monto,
             tam.cod_moneda,
             tam.nro_referencia,
             tam.mto_mon_extranjera,
             tam.mto_mon_local,
             tam.nro_cuenta,
             tam.cod_persona,
             tam.cod_area,
             tam.cod_ori_movimientos,
             tam.cod_cnc_movimientos,
             tam.cod_are_solicitante
        FROM cb_asi_masivos_tmp tam
       ORDER BY tam.cod_ofi_operacion, tam.nro_referencia;

   CURSOR asientos IS

      SELECT DISTINCT tam.cod_ofi_operacion, tam.nro_referencia
        FROM cb_asi_masivos_tmp tam
       ORDER BY tam.cod_ofi_operacion, tam.nro_referencia;

   --Cursor de Debito
   CURSOR rubro_deb
   (
      p_cod_ofi_operacion IN cb_asi_masivos_tmp.cod_ofi_operacion%TYPE,
      p_nro_referencia    IN cb_asi_masivos_tmp.nro_referencia%TYPE
   ) IS

      SELECT a.cod_rubro, a.nro_referencia
        FROM cb_asi_masivos_tmp a
       WHERE a.tip_mov_rubro = 'D'
         AND a.cod_ofi_operacion = p_cod_ofi_operacion
         AND a.nro_referencia = p_nro_referencia;
   --Cursor de Credito
   CURSOR rubro_cred
   (
      p_cod_ofi_operacion IN cb_asi_masivos_tmp.cod_ofi_operacion%TYPE,
      p_nro_referencia    IN cb_asi_masivos_tmp.nro_referencia%TYPE
   ) IS

      SELECT a.cod_rubro, a.nro_referencia
        FROM cb_asi_masivos_tmp a
       WHERE a.tip_mov_rubro = 'C'
         AND a.cod_ofi_operacion = p_cod_ofi_operacion
         AND a.nro_referencia = p_nro_referencia;

   --procedimiento para el rubro
   PROCEDURE lp_val_rubros
   (
      p_cod_ofi_operacion IN cb_asi_masivos_tmp.cod_ofi_operacion%TYPE,
      p_nro_referencia    IN cb_asi_masivos_tmp.nro_referencia%TYPE
   ) IS

   BEGIN
      --Se valida los rubros no seas de Orden vs Patrimoniales
      FOR deb IN rubro_deb(p_cod_ofi_operacion, p_nro_referencia) LOOP
         v_cod_rubro_d := substr(deb.cod_rubro, 1, 1);
         IF v_cod_rubro_d = 4 OR v_cod_rubro_d = 5 THEN
            FOR cred IN rubro_cred(p_cod_ofi_operacion, p_nro_referencia) LOOP
               v_cod_rubro_c := substr(cred.cod_rubro, 1, 1);
               IF v_cod_rubro_d <> v_cod_rubro_c THEN
                  raise_application_error(-20000,
                                          'ERROR: No se puede procesar. Las cuentas de orden no pueden combinarse. En referencia ' ||
                                           deb.nro_referencia || ' Favor verificar ');
               END IF;

               IF v_cod_rubro_d <> v_cod_rubro_c THEN
                  raise_application_error(-20000,
                                          'ERROR: No se puede procesar. Las cuentas de contingentes no pueden combinarse. En referencia ' ||
                                           deb.nro_referencia || ' Favor verificar ');
               END IF;
            END LOOP;
         END IF;
      END LOOP;
   END;

BEGIN

   -- Controlar si el módulo se encuentra habilitado
   pae_cnf.pr_ctr_modulo(2);

   -- Actualizo los campos importados de la tabla adicional.
   UPDATE cb_asi_masivos_tmp ca
      SET ca.nro_cuenta  = NULL,
          ca.cod_persona = NULL,
          ca.cod_area    = NULL
    WHERE substr(ca.cod_rubro, 1, 1) NOT IN ('6', '7');

   UPDATE cb_asi_masivos_tmp ca SET ca.nro_cuenta = NULL WHERE ca.cod_persona = v_cod_per_entidad;

   UPDATE cb_asi_masivos_tmp ca SET ca.cod_area = NULL WHERE substr(ca.cod_rubro, 1, 1) = '6';

   UPDATE cb_asi_masivos_tmp ca
      SET ca.nro_cuenta = NULL
    WHERE substr(ca.cod_rubro, 1, 1) IN ('6', '7')
      AND NOT EXISTS (SELECT 1 FROM ge_cuentas gc WHERE gc.nro_cuenta = ca.nro_cuenta);

   FOR reg IN asientos_det LOOP

      --Verifica que tenga nro de referencia cargado y sea numerico.
      IF reg.nro_referencia IS NULL OR
         length(TRIM(translate(reg.nro_referencia, '0123456789', ' '))) IS NOT NULL THEN
         raise_application_error(-20000,
                                 'El nro de referencia debe ser un numerico ' || ' en ref. ' ||
                                  reg.nro_referencia || ' descripcion: ' || reg.descripcion);
      END IF;

      --Verifica que el monto de moneda local este cargado.
      IF nvl(reg.mto_mon_local, 0) = 0 THEN
         raise_application_error(-20000,
                                 'Es necesario el Monto Moneda Local ' || ' en ref. ' ||
                                  reg.nro_referencia);
      END IF;
      --Verifica que la multiplicacion de cotizacion * monto moneda extranjera  sea igual a Monto Moneda Local
      IF reg.cod_moneda <> 'GS' THEN
         v_multiplicacion := round(reg.mto_mon_extranjera * reg.cotizacion);
         IF nvl(v_multiplicacion, 0) <> nvl(reg.mto_mon_local, 0) THEN
            raise_application_error(-20000,
                                    'EL Monto Moneda Local es incorrecto.Favor verificar el resultado de la multiplicacion de Monto Moneda Extrajera con Cotizacion ' ||
                                     ' en ref. ' || reg.nro_referencia);
         END IF;
      END IF;
      --Verifica que el monto de moneda extrangera este cargado si es diferente a GS.
      IF reg.mto_mon_extranjera IS NULL AND reg.cod_moneda <> 'GS' THEN
         raise_application_error(-20000,
                                 'Es necesario el Monto Moneda Extrangera ' || ' en ref. ' ||
                                  reg.nro_referencia);
      END IF;

      --Verifica la cotizacion si esta vacia y es ME se pide ingresar cotizacion
      IF (reg.cotizacion IS NULL OR reg.cotizacion = 0) AND reg.cod_moneda <> 'GS' THEN
         raise_application_error(-20000,
                                 'Es necesario ingresar cotizacion  ' || reg.cod_moneda ||
                                  ' en ref. ' || reg.nro_referencia);
      END IF;

      --verifica que el tipo de mov del rubro sea la correcta D o C
      IF reg.tip_mov_rubro NOT IN ('D', 'C') OR reg.tip_mov_rubro IS NULL THEN
         raise_application_error(-20000,
                                 'No se puede procesar el asiento, el tipo de movimiento debe ser D o C ' ||
                                  reg.tip_mov_rubro || ' en ref. ' || reg.nro_referencia);
      END IF;
      --
      SELECT SUM(a.mto_mon_local) monto --, a.cod_rubro
        INTO v_mto_debito_equi_gs --, v_cod_rubro_D
        FROM cb_asi_masivos_tmp a
       WHERE a.tip_mov_rubro = 'D'
         AND a.cod_ofi_operacion = reg.cod_ofi_operacion
         AND a.nro_referencia = reg.nro_referencia;
      --            group by monto, a.cod_rubro;
      --
      SELECT SUM(a.mto_mon_local) monto --, a.cod_rubro
        INTO v_mto_credito_equi_gs --, v_cod_rubro_C
        FROM cb_asi_masivos_tmp a
       WHERE a.tip_mov_rubro = 'C'
         AND a.cod_ofi_operacion = reg.cod_ofi_operacion
         AND a.nro_referencia = reg.nro_referencia;
      --            group by monto, a.cod_rubro;

      --Se llama al procedimiento para ir a validar los rubros
      lp_val_rubros(reg.cod_ofi_operacion, reg.nro_referencia);

      ----
      IF nvl(v_mto_credito_equi_gs, 0) <> nvl(v_mto_debito_equi_gs, 0) THEN
         raise_application_error(-20000,
                                 'No se puede procesar el asiento, los montos debito y credito no cuadran en la oficina ' ||
                                  ' en ref. ' || reg.nro_referencia);
      END IF;
      IF nvl(v_mto_credito_equi_gs, 0) <= 0 OR nvl(v_mto_debito_equi_gs, 0) <= 0 THEN
         raise_application_error(-20000,
                                 'No se puede procesar el asiento, el monto debito o credito no pueden ser menor o igual cero. ' ||
                                  ' en ref. ' || reg.nro_referencia);
      END IF;
      -- verifica que tenga cargados oficina origen y destino
      IF reg.cod_ofi_operacion IS NULL OR reg.cod_ofi_destino IS NULL THEN
         raise_application_error(-20000,
                                 'Oficina operacion y oficina destino no pueden ser vacio ' ||
                                  ' en ref. ' || reg.nro_referencia);
      END IF;

      --Verifica que tenga descripcion
      IF reg.descripcion IS NULL THEN
         raise_application_error(-20000,
                                 'la descripcion no puede ser vacia ' || ' en ref. ' ||
                                  reg.nro_referencia || ' descripcion: ' || reg.descripcion);
      END IF;

      -- Valida que los campos no sean nulos.
/*      IF reg.nro_cuenta IS NULL AND reg.cod_persona IS NULL AND
         substr(reg.cod_rubro, 1, 1) IN ('6', '7') THEN
         raise_application_error(-20000,
                                 'El Número de Cuenta/Código de Persona no puede ser vacío en ref. ' ||
                                  reg.nro_referencia || ' descripción: ' || reg.descripcion);
      ELSIF (reg.nro_cuenta IS NOT NULL OR reg.cod_persona IS NOT NULL) AND
            substr(reg.cod_rubro, 1, 1) IN ('6', '7') THEN
         -- Verifica que el número de cuenta/código de persona sean validos.
         IF reg.cod_persona IS NOT NULL THEN
            BEGIN
               SELECT 1 INTO v_existe FROM ge_clientes gc WHERE gc.cod_persona = reg.cod_persona;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000,
                                          'El Código de Persona no existe en ref. ' ||
                                           reg.nro_referencia || ' descripción: ' || reg.descripcion);
            END;
         END IF;
         --
         IF reg.cod_persona <> v_cod_per_entidad THEN
            IF reg.nro_cuenta IS NOT NULL THEN
               BEGIN
                  SELECT 1 INTO v_existe FROM ge_cuentas gc WHERE gc.nro_cuenta = reg.nro_cuenta;
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20000,
                                             'El Número de Cuenta no existe en ref. ' ||
                                              reg.nro_referencia || ' descripción: ' ||
                                              reg.descripcion);
               END;
               -- Verifica que el código de persona corresponda a la cuenta.
               IF reg.cod_persona <> fug_obt_cli_principal(reg.nro_cuenta) THEN
                  raise_application_error(-20000,
                                          'El Código de Persona no corresponde al cliente principal de la cuenta: ' ||
                                           reg.nro_cuenta || ' descripción: ' || reg.descripcion);
               END IF;
            END IF;
         END IF;
      ELSIF (reg.nro_cuenta IS NOT NULL OR reg.cod_persona IS NOT NULL) AND
            substr(reg.cod_rubro, 1, 1) NOT IN ('6', '7') THEN
         raise_application_error(-20000,
                                 'El campo Número de Cuenta/Código de Persona debe estar vacío para los rubros que no son Cuentas de Resultado en ref. ' ||
                                  reg.nro_referencia || ' descripción: ' || reg.descripcion);
      END IF;*/
      -- Verifica el Código de Centro de Costos.
   /*  IF reg.cod_area IS NULL AND substr(reg.cod_rubro, 1, 1) = '7' THEN
               raise_application_error(-20000,
                                       'El código de centro de costo no puede ser vacío en ref. ' ||
                                        reg.nro_referencia || ' descripción: ' || reg.descripcion);
            ELSIF reg.cod_area IS NOT NULL AND substr(reg.cod_rubro, 1, 1) = '7' THEN
               BEGIN
                  SELECT 1
                    INTO v_existe
                    FROM ba_areas ba
                   WHERE ba.cod_area = reg.cod_area
                     AND ba.cod_oficina = reg.cod_ofi_destino;
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20000,
                                             'El Código de Centro de Costo no existe para la oficina: ' ||
                                              reg.cod_ofi_destino || ' en ref. ' || reg.nro_referencia ||
                                              ' descripción: ' || reg.descripcion);
               END;
            ELSIF reg.cod_area IS NOT NULL AND substr(reg.cod_rubro, 1, 1) <> '7' THEN
               raise_application_error(-20000,
                                       'El campo código de área debe estar vacío para los rubros que no son Cuentas de Resultado(Pérdida) en ref. ' ||
                                        reg.nro_referencia || ' descripción: ' || reg.descripcion);
            END IF;*/
   /*      -- Verifica el código de Origen del Movimiento.
            IF reg.cod_ori_movimientos IS NULL THEN
               raise_application_error(-20000,
                                       'El código de origen del movimiento no puede ser vacío en ref. ' ||
                                        reg.nro_referencia || ' descripción: ' || reg.descripcion);
            ELSE
               BEGIN
                  SELECT 1
                    INTO v_existe
                    FROM ba_cod_referencias bc
                   WHERE bc.dominio = 'ASI_ORI_MOVIMIENTOS'
                     AND bc.val_minimo = reg.cod_ori_movimientos;
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20000,
                                             'El código de origen del movimiento no existe en ref. ' ||
                                              reg.nro_referencia || ' descripción: ' || reg.descripcion);
               END;
            END IF;*/
   -- Verifica el Código del Concepto del Movimiento.
   /* IF reg.cod_cnc_movimientos IS NULL THEN
               raise_application_error(-20000,
                                       'El código del concepto del movimiento no puede ser vacío en ref. ' ||
                                        reg.nro_referencia || ' descripción: ' || reg.descripcion);
            ELSE
               BEGIN
                  SELECT 1
                    INTO v_existe
                    FROM ba_cod_referencias bc
                   WHERE bc.dominio = 'ASI_CNC_MOVIMIENTOS'
                     AND bc.val_minimo = reg.cod_cnc_movimientos;
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20000,
                                             'El código del concepto del movimiento no existe en ref. ' ||
                                              reg.nro_referencia || ' descripción: ' || reg.descripcion);
               END;
            END IF;*/
   -- Verifica el Código de Área Solicitante.
   /* IF reg.cod_are_solicitante IS NULL THEN
               raise_application_error(-20000,
                                       'El código del área solicitante no puede ser vacío en ref. ' ||
                                        reg.nro_referencia || ' descripción: ' || reg.descripcion);
            ELSE
               BEGIN
                  SELECT 1
                    INTO v_existe
                    FROM ba_cod_referencias bc
                   WHERE bc.dominio = 'ASI_ARE_SOLICITANTE'
                     AND bc.val_minimo = reg.cod_are_solicitante;
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20000,
                                             'El código del área solicitante no existe en ref. ' ||
                                              reg.nro_referencia || ' descripción: ' || reg.descripcion);
               END;
            END IF;*/

   END LOOP;

   --Verificar que el rubro no sea imputable
   BEGIN
      SELECT COUNT(*), a.cod_rubro
        INTO v_imputable, v_cod_rubro
        FROM cb_asi_masivos_tmp a
        JOIN cb_rubros b
          ON a.cod_rubro = b.cod_rubro
         AND b.imputable = 'N'
         AND rownum = 1
       GROUP BY a.cod_rubro;
   EXCEPTION
      WHEN OTHERS THEN
         v_imputable := 0;
   END;
   --
   IF v_imputable > 0 THEN
      raise_application_error(-20000,
                              'No se puede procesar el asiento, el rubro ' || v_cod_rubro ||
                               ' no es imputable en ref. ' || v_referencia);
   END IF;

   --verificar que coincidan monedas con rubro
   BEGIN
      SELECT COUNT(*), a.cod_rubro, a.cod_moneda, a.nro_referencia
        INTO v_no_coincide_moneda, v_cod_rubro, v_cod_moneda, v_referencia
        FROM cb_asi_masivos_tmp a
        JOIN cb_rubros b
          ON a.cod_rubro = b.cod_rubro
         AND a.cod_moneda <> b.cod_moneda
         AND rownum = 1
       GROUP BY a.cod_rubro, a.cod_moneda, a.nro_referencia;
   EXCEPTION
      WHEN OTHERS THEN
         v_no_coincide_moneda := 0;
   END;
   --
   IF v_no_coincide_moneda > 0 THEN
      raise_application_error(-20000,
                              'No se puede procesar el asiento, la moneda ' || v_cod_moneda ||
                               ' no coincide con el rubro ' || v_cod_rubro || ' en ref. ' ||
                               v_referencia);
   END IF;

   --verificar que posea codigo rubro valido
   BEGIN
      SELECT COUNT(*), a.cod_rubro, a.nro_referencia
        INTO v_no_tiene_rubro, v_cod_rubro, v_referencia
        FROM cb_asi_masivos_tmp a
        LEFT JOIN cb_rubros b
          ON a.cod_rubro = b.cod_rubro
       WHERE b.cod_rubro IS NULL
         AND rownum = 1
       GROUP BY a.cod_rubro, a.nro_referencia;
   EXCEPTION
      WHEN OTHERS THEN
         v_no_tiene_rubro := 0;
   END;
   --
   IF v_no_tiene_rubro > 0 THEN
      raise_application_error(-20000,
                              'No se puede procesar el asiento, el rubro no existe ' || v_cod_rubro ||
                               ' en ref. ' || v_referencia);
   END IF;

   --verificar que las oficinas existan
   BEGIN
      SELECT cant, x.cod_oficina, x.nro_referencia
        INTO v_no_tiene_ofi, v_cod_oficina, v_referencia
        FROM (SELECT COUNT(*) cant, a.cod_ofi_operacion cod_oficina, a.nro_referencia

                FROM cb_asi_masivos_tmp a
                LEFT JOIN ba_oficinas b
                  ON a.cod_ofi_operacion = b.cod_oficina
               WHERE b.cod_oficina IS NULL
               GROUP BY a.cod_ofi_operacion, a.nro_referencia
              UNION ALL
              SELECT COUNT(*) cant, a.cod_ofi_destino cod_oficina, a.nro_referencia
                FROM cb_asi_masivos_tmp a
                LEFT JOIN ba_oficinas b
                  ON a.cod_ofi_destino = b.cod_oficina
               WHERE b.cod_oficina IS NULL
               GROUP BY a.cod_ofi_destino, a.nro_referencia) x
       WHERE rownum = 1;
   EXCEPTION
      WHEN OTHERS THEN
         v_no_tiene_ofi := 0;
   END;
   --
   IF v_no_tiene_ofi > 0 THEN
      raise_application_error(-20000,
                              'No se puede procesar el asiento, la oficina no existe ' ||
                               v_cod_oficina || ' en ref. ' || v_referencia);
   END IF;

   v_fec_actual  := pag_cal.fu_obt_fec_actual(2);
   v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
   v_nro_asiento := v_nro_asiento - 1;

   IF asientos%ISOPEN THEN
      CLOSE asientos;
   END IF;
   --se recorre  el cursor ASIENTOS COMO CABECERA Y ASIENTOS DET COMO DETALLE
   OPEN asientos_det;
   OPEN asientos;
   LOOP
      FETCH asientos
         INTO v_cod_ofi_operacion, v_nro_referencia;
      EXIT WHEN asientos%NOTFOUND;
      BEGIN

         v_nro_asiento   := v_nro_asiento + 1;
         v_nro_asi_inter := v_nro_asiento;
         v_tot_control   := 0;
         v_nro_linea     := 0;

         FOR v_asiento_row IN (SELECT *
                                 FROM cb_asi_masivos_tmp tam
                                WHERE tam.cod_ofi_operacion = v_cod_ofi_operacion
                                  AND tam.nro_referencia = v_nro_referencia
                                ORDER BY tam.cod_ofi_operacion) LOOP
            BEGIN

               --- Insertar asiento
               v_nro_linea   := v_nro_linea + 1;
               v_tot_control := v_tot_control + round(nvl(v_asiento_row.mto_mon_local, 0));

               ---detalle
               -- manejo de interoficina
               IF v_asiento_row.cod_ofi_operacion <> v_asiento_row.cod_ofi_destino THEN

                  -- inserta asiento rubro original en oficina destino
                  v_nro_asi_inter := v_nro_asi_inter + 1;
                  INSERT INTO cb_asientos_det
                     (cod_oficina, fecha, nro_asiento, nro_linea, cod_rubro, mto_mon_local,
                      mto_mon_rubro, tip_movimiento, descripcion, actualizado, referencia,
                      val_cotizacion, fec_valor)
                  VALUES
                     (v_asiento_row.cod_ofi_destino, v_fec_actual, v_nro_asi_inter, 1,
                      v_asiento_row.cod_rubro, round(v_asiento_row.mto_mon_local),
                      decode(v_asiento_row.cod_moneda, 'GS', 0, v_asiento_row.mto_mon_extranjera),
                      v_asiento_row.tip_mov_rubro, v_asiento_row.descripcion, 'N',
                      v_asiento_row.nro_referencia,
                      decode(v_asiento_row.cod_moneda, 'GS', 0, nvl(v_asiento_row.cotizacion, 0)),
                      v_fec_actual);

                  -- Inserto datos adicionales del rubro original en oficina destino.
                  INSERT INTO cb_dat_asientos_det
                     (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento,
                      nro_cuenta, cod_persona, cod_area, cod_ori_movimientos, cod_cnc_movimientos,
                      cod_are_solicitante)
                  VALUES
                     (v_fec_actual, v_asiento_row.cod_ofi_destino, v_nro_asi_inter, 1,
                      v_asiento_row.cod_rubro, v_asiento_row.tip_mov_rubro, v_asiento_row.nro_cuenta,
                      v_asiento_row.cod_persona, v_asiento_row.cod_area,
                      v_asiento_row.cod_ori_movimientos, v_asiento_row.cod_cnc_movimientos,
                      v_asiento_row.cod_are_solicitante);

                  -- inserta asiento interoficina en oficina destino
                  v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                                         v_asiento_row.cod_moneda,
                                                         v_asiento_row.cod_ofi_operacion);
                  /*v_cod_rub_inter := substr(v_cod_rub_inter, 1, 10) ||
                                     ltrim(to_char(v_asiento_row.cod_ofi_operacion, '000')) ||
                                     substr(v_cod_rub_inter, 14, 2);*/

                  INSERT INTO cb_asientos_det
                     (cod_oficina, fecha, nro_asiento, nro_linea, cod_rubro, mto_mon_local,
                      mto_mon_rubro, tip_movimiento, descripcion, actualizado, referencia,
                      val_cotizacion, fec_valor)
                  VALUES
                     (v_asiento_row.cod_ofi_destino, v_fec_actual, v_nro_asi_inter, 2,
                      v_cod_rub_inter, round(v_asiento_row.mto_mon_local),
                      decode(v_asiento_row.cod_moneda, 'GS', 0, v_asiento_row.mto_mon_extranjera),
                      decode(v_asiento_row.tip_mov_rubro, 'C', 'D', 'C'), v_asiento_row.descripcion,
                      'N', v_asiento_row.nro_referencia,
                      decode(v_asiento_row.cod_moneda, 'GS', 0, nvl(v_asiento_row.cotizacion, 0)),
                      v_fec_actual);

                  -- Inserto datos adicionales del rubro original en oficina destino.
                  INSERT INTO cb_dat_asientos_det
                     (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento,
                      nro_cuenta, cod_persona, cod_area, cod_ori_movimientos, cod_cnc_movimientos,
                      cod_are_solicitante)
                  VALUES
                     (v_fec_actual, v_asiento_row.cod_ofi_destino, v_nro_asi_inter, 2,
                      v_cod_rub_inter, decode(v_asiento_row.tip_mov_rubro, 'C', 'D', 'C'),
                      v_asiento_row.nro_cuenta, v_asiento_row.cod_persona, v_asiento_row.cod_area,
                      v_asiento_row.cod_ori_movimientos, v_asiento_row.cod_cnc_movimientos,
                      v_asiento_row.cod_are_solicitante);

                  --cabecera oficina destino
                  INSERT INTO cb_asientos
                     (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad,
                      tot_control, actualizado, reversado, cod_ofi_origen, confirmado, ofi_integrada,
                      fec_valor)
                  VALUES
                     (v_asiento_row.cod_ofi_destino, v_nro_asi_inter, USER, v_fec_actual, 2, 21,
                      round(v_asiento_row.mto_mon_local) * 2, 'N', 'N', v_cod_ofi_operacion, 'S',
                      'N', v_fec_actual);

                  ---detalle inter oficina en oficina origen
                  -- inserta asiento interoficina en oficina destino
                  v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                                         v_asiento_row.cod_moneda,
                                                         v_asiento_row.cod_ofi_destino);
                  /*v_cod_rub_inter := substr(v_cod_rub_inter, 1, 10) ||
                                     ltrim(to_char(v_asiento_row.cod_ofi_destino, '000')) ||
                                     substr(v_cod_rub_inter, 14, 2);*/

                  INSERT INTO cb_asientos_det
                     (cod_oficina, fecha, nro_asiento, nro_linea, cod_rubro, mto_mon_local,
                      mto_mon_rubro, tip_movimiento, descripcion, actualizado, referencia,
                      val_cotizacion, fec_valor)
                  VALUES
                     (v_cod_ofi_operacion, v_fec_actual, v_nro_asiento, v_nro_linea,
                      v_cod_rub_inter, round(v_asiento_row.mto_mon_local),
                      decode(v_asiento_row.cod_moneda, 'GS', 0, v_asiento_row.mto_mon_extranjera),
                      v_asiento_row.tip_mov_rubro, v_asiento_row.descripcion, 'N',
                      v_asiento_row.nro_referencia,
                      decode(v_asiento_row.cod_moneda, 'GS', 0, nvl(v_asiento_row.cotizacion, 0)),
                      v_fec_actual);

                  -- Inserto datos adicionales del rubro original en oficina destino.
                  INSERT INTO cb_dat_asientos_det
                     (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento,
                      nro_cuenta, cod_persona, cod_area, cod_ori_movimientos, cod_cnc_movimientos,
                      cod_are_solicitante)
                  VALUES
                     (v_fec_actual, v_cod_ofi_operacion, v_nro_asiento, v_nro_linea,
                      v_cod_rub_inter, v_asiento_row.tip_mov_rubro, v_asiento_row.nro_cuenta,
                      v_asiento_row.cod_persona, v_asiento_row.cod_area,
                      v_asiento_row.cod_ori_movimientos, v_asiento_row.cod_cnc_movimientos,
                      v_asiento_row.cod_are_solicitante);

               ELSE
                  --si no es inter oficina carga detalle asiento normal
                  v_mov_asiento := v_asiento_row.tip_mov_rubro;
                  ---detalle
                  INSERT INTO cb_asientos_det
                     (cod_oficina, fecha, nro_asiento, nro_linea, cod_rubro, mto_mon_local,
                      mto_mon_rubro, tip_movimiento, descripcion, actualizado, referencia,
                      val_cotizacion, fec_valor)
                  VALUES
                     (v_cod_ofi_operacion, v_fec_actual, v_nro_asiento, v_nro_linea,
                      v_asiento_row.cod_rubro, round(v_asiento_row.mto_mon_local),
                      decode(v_asiento_row.cod_moneda, 'GS', 0, v_asiento_row.mto_mon_extranjera),
                      v_mov_asiento, v_asiento_row.descripcion, 'N', v_asiento_row.nro_referencia,
                      decode(v_asiento_row.cod_moneda, 'GS', 0, nvl(v_asiento_row.cotizacion, 0)),
                      v_fec_actual);

                  -- Inserto datos adicionales del rubro original en oficina destino.
                  INSERT INTO cb_dat_asientos_det
                     (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento,
                      nro_cuenta, cod_persona, cod_area, cod_ori_movimientos, cod_cnc_movimientos,
                      cod_are_solicitante)
                  VALUES
                     (v_fec_actual, v_cod_ofi_operacion, v_nro_asiento, v_nro_linea,
                      v_asiento_row.cod_rubro, v_mov_asiento, v_asiento_row.nro_cuenta,
                      v_asiento_row.cod_persona, v_asiento_row.cod_area,
                      v_asiento_row.cod_ori_movimientos, v_asiento_row.cod_cnc_movimientos,
                      v_asiento_row.cod_are_solicitante);
               END IF;

            END;
         END LOOP; --fir detalle por oficina

         --cabecera
         INSERT INTO cb_asientos
            (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad, tot_control,
             actualizado, reversado, cod_ofi_origen, confirmado, ofi_integrada, fec_valor)
         VALUES
            (v_cod_ofi_operacion, v_nro_asiento, USER, v_fec_actual, 2, 21, v_tot_control, 'N', 'N',
             v_cod_ofi_operacion, 'S', 'N', v_fec_actual);

         --actualiza nro asiento, si fue incrementado por interoficina
         IF v_nro_asi_inter > v_nro_asiento THEN
            v_nro_asiento := v_nro_asi_inter;
         END IF;
      END;

   END LOOP; --CIERRA ASIENTOS
   CLOSE asientos;
   -- Actualiza par dinamico con el nro de asiento final
   prg_act_par_dinamico('SIG_NRO_ASIENTO', NULL, NULL, NULL, NULL, v_nro_asiento + 1);
END;
/

