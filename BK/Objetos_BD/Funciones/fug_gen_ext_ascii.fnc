CREATE OR REPLACE FUNCTION IT.fug_gen_ext_ascii
(
   p_cod_persona  IN VARCHAR2,
   p_nro_cuenta   IN VARCHAR2,
   p_formato_gral IN VARCHAR2,
   conn           IN OUT NOCOPY utl_smtp.connection
) RETURN VARCHAR2 IS
   ------------------------
   v_file VARCHAR2(4000);
   ------------------------
   v_separador VARCHAR2(10) := chr(9);
   v_error     VARCHAR2(4000);
   v_nom_largo         varchar2(100):= fug_obt_nom('L');

   CURSOR c_gen_ext IS
      SELECT a.cod_persona, a.nro_cuenta
        FROM ge_cta_clientes a
       WHERE a.cod_persona = p_cod_persona
         AND a.nro_cuenta = p_nro_cuenta;
   ---
   PROCEDURE pp_gen_mov_ascii
   (
      p_cod_persona VARCHAR2,
      p_nro_cta     VARCHAR2
   ) IS
      -- solo para eminco
      CURSOR cab_clie IS
         SELECT cod_oficina,
                nro_cuenta,
                cod_persona,
                fec_extracto,
                cod_moneda,
                fre_extracto,
                cod_extracto,
                nvl(a.sal_anterior, 0) sal_anterior,
                nvl(a.sal_actual, 0) sal_actual,
                sal_a_confirmar,
                sigla,
                b.cod_modalidad
           FROM ge_ext_cli_cuentas_tmp a, ge_modalidades b
          WHERE a.cod_modalidad = b.cod_modalidad
            AND cod_persona = p_cod_persona
            AND nro_cuenta = p_nro_cta
          ORDER BY cod_persona, nro_cuenta, fec_extracto;
      --
      CURSOR det_clie(p_cta VARCHAR2, p_fec_extracto DATE, p_cod_extracto NUMBER) IS
         SELECT fec_movimiento,
                fec_valor,
                hor_movimiento,
                lpad(substr(nvl(nro_documento, 0), 1, 7), 7, 0) nro_documento,
                a.mto_credito,
                a.mto_debito,
                decode(a.mto_debito, 0,
                       TRIM(REPLACE(to_char(nvl(a.mto_credito, 0), 'S000000000000D00'), '.', ',')),
                       TRIM(REPLACE(to_char(nvl(a.mto_debito, 0), 'S000000000000D00'), '.', ','))) valor,
                descripcion,
                decode(a.mto_debito, 0, 'C', 'D') tipo,
                lpad(to_char(cod_tra_padre), 3, 0) cod_tra_padre
           FROM ge_ext_cli_movimientos_tmp a, ge_transacciones b
          WHERE a.cod_tra_padre = b.cod_transaccion
            AND a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND cod_persona = p_cod_persona
            AND fec_extracto = p_fec_extracto
            AND cod_extracto = p_cod_extracto
            AND nro_cuenta = p_cta
          ORDER BY a.fec_movimiento, a.fec_valor, a.hor_movimiento;
      --
      v_cabecera        VARCHAR2(1000);
      v_detalle         VARCHAR2(4000);
      v_sucursal        VARCHAR2(3);
      v_cont            NUMBER := 0;
      v_existe          VARCHAR2(1) := NULL;
      v_sum_mto_debito  NUMBER;
      v_sum_mto_credito NUMBER;
      v_count           NUMBER;
      v_tipo_cuenta     VARCHAR2(1);
      v_sub_cuenta      VARCHAR2(6);
      v_dia_habil       VARCHAR2(12);
   BEGIN
      --determinar el tipo
      FOR reg IN cab_clie LOOP
         BEGIN
            SELECT to_char(lpad(nvl(a.cod_oficina, 0), 2, 0))
              INTO v_sucursal
              FROM ge_ext_clientes_tmp a
             WHERE a.cod_persona = reg.cod_persona
               AND a.cod_extracto = reg.cod_extracto
               AND a.fec_extracto = reg.fec_extracto
               AND a.fre_extracto = reg.fre_extracto;
         EXCEPTION
            WHEN no_data_found THEN
               v_error := 'No existe registro en ge_ext_clientes_tmp, fug_gen_ext_ascii.pp_gen_mov_ascii.';
            WHEN OTHERS THEN
               v_error := 'Error 1 en fug_gen_ext_ascii.pp_gen_mov_ascii. ' || SQLERRM;
         END;
         BEGIN
            SELECT to_char(a.pri_dia_mes_habil, 'dd/mm/yyyy')
              INTO v_dia_habil
              FROM ge_calendarios a
             WHERE a.cod_modulo = 1;
         EXCEPTION
            WHEN no_data_found THEN
               v_error := 'No existe registro en ge_calendarios para cod_modulo= 1, fug_gen_ext_ascii.pp_gen_mov_ascii.';
            WHEN OTHERS THEN
               v_error := 'Error 2 en fug_gen_ext_ascii.pp_gen_mov_ascii. ' || SQLERRM;
         END;
         BEGIN
            SELECT nvl(SUM(a.mto_debito), 0) v_sum_mto_debito,
                   nvl(SUM(a.mto_credito), 0) v_sum_mto_credito,
                   COUNT(*)
              INTO v_sum_mto_debito, v_sum_mto_credito, v_count
              FROM ge_ext_cli_movimientos_tmp a, ge_transacciones b
             WHERE a.cod_tra_padre = b.cod_transaccion
               AND a.cod_modulo = b.cod_modulo
               AND a.cod_modalidad = b.cod_modalidad
               AND cod_persona = reg.cod_persona
               AND nro_cuenta = reg.nro_cuenta
               AND fec_extracto = reg.fec_extracto
               AND fre_extracto = reg.fre_extracto
               AND cod_extracto = reg.cod_extracto
             GROUP BY a.cod_persona, a.nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               v_error := 'Consulta no devuelve registros fug_gen_ext_ascii.pp_gen_mov_ascii.';
            WHEN OTHERS THEN
               v_error := 'Error 3 en fug_gen_ext_ascii.pp_gen_mov_ascii. ' || SQLERRM;
         END;
         IF reg.cod_modalidad = 41 AND reg.cod_moneda = 'GS' THEN
            v_tipo_cuenta := '1';
            v_sub_cuenta  := '210100';
         ELSIF reg.cod_modalidad = 31 AND reg.cod_moneda = 'GS' THEN
            v_tipo_cuenta := '2';
            v_sub_cuenta  := '210500';
         ELSIF reg.cod_modalidad = 41 AND reg.cod_moneda <> 'GS' THEN
            v_tipo_cuenta := '3';
            v_sub_cuenta  := '215000';
         ELSIF reg.cod_modalidad = 31 AND reg.cod_moneda <> 'GS' THEN
            v_tipo_cuenta := '4';
            v_sub_cuenta  := '215500';
         END IF;
         --
         v_cabecera := v_sucursal || v_sub_cuenta || substr(reg.nro_cuenta, -6) || ' ' ||
                       rpad(reg.cod_moneda, 3, ' ') || v_dia_habil ||
                       to_char(reg.fec_extracto, 'dd/mm/yyyy') ||
                       REPLACE(to_char(reg.sal_anterior, 'S00000000000000D00'), '.', ',') ||
                       REPLACE(to_char(v_sum_mto_credito, 'S00000000000000D00'), '.', ',') ||
                       REPLACE(to_char(v_sum_mto_debito, 'S00000000000000D00'), '.', ',') ||
                       REPLACE(to_char(reg.sal_actual, 'S00000000000000D00'), '.', ',') ||
                       lpad(v_count, 5, '0') || chr(13) || chr(10);
         --** Arma el Archivo Anexo.
         it_mail.write_text(conn, v_cabecera);
         --**
         v_existe  := 'S';
         v_detalle := '';
         v_cont    := 0;
         FOR reg1 IN det_clie(reg.nro_cuenta, reg.fec_extracto, reg.cod_extracto) LOOP
            v_cont    := v_cont + 1;
            v_detalle := v_detalle || to_char(reg1.fec_movimiento, 'dd/mm/yyyy') ||
                         reg1.nro_documento || to_char(reg1.cod_tra_padre) || reg1.tipo ||
                         reg1.valor || '0000000000' || chr(13) || chr(10);
            --**
            it_mail.write_text(conn, v_detalle);
            v_detalle := '';
            --**
         END LOOP;
         ---
      END LOOP;
   
       --MENSAJE AL PIE CNFFGEXR-1 -- RE 15-01-2016
       v_detalle := v_separador || fug_obt_pardinamico('MEN_EXT_INDIVIDUAL');--MENSAJE EXTRACTO INDIVIDUAL
       it_mail.write_text(conn, v_detalle);
       
   EXCEPTION
      WHEN OTHERS THEN
         IF abs(SQLCODE) = 302000 THEN
            raise_application_error(-20000, 'Directorio Inválido.');
         ELSE
            raise_application_error(-20000, 'Error ' || v_error || SQLERRM);
         END IF;
   END;
   ---------------------------------
   PROCEDURE pp_gen_mov_ascii_gral
   (
      p_cod_persona VARCHAR2,
      p_nro_cta     VARCHAR2
   ) IS
      v_fec_extracto ge_ext_cli_cuentas.fec_extracto%TYPE;
      v_sal_anterior NUMBER;
      v_saldo        NUMBER;
      CURSOR cab_clie IS
         SELECT cod_oficina,
                nro_cuenta,
                cod_persona,
                fec_extracto,
                cod_moneda,
                fre_extracto,
                cod_extracto,
                (decode(sign(a.sal_anterior), -1, '-', '') || nvl(abs(a.sal_anterior), 0)) sal_anterior,
                (decode(sign(a.sal_actual), -1, '-', '') || nvl(abs(a.sal_actual), 0)) sal_actual,
                sal_a_confirmar,
                sigla
           FROM ge_ext_cli_cuentas_tmp a, ge_modalidades b
          WHERE a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND nro_cuenta = p_nro_cta
            AND cod_persona = p_cod_persona
          ORDER BY cod_persona, nro_cuenta, fec_extracto;
   
      CURSOR det_clie(p_cta VARCHAR2, p_fec_extracto DATE, p_cod_extracto NUMBER) IS
         SELECT fec_movimiento,
                fec_valor,
                hor_movimiento,
                nvl(nro_documento, 0) nro_documento,
                nvl(a.mto_debito, 0) mto_debito,
                nvl(a.mto_credito, 0) mto_credito,
                substr(descripcion, 1, 41) descripcion
           FROM ge_ext_cli_movimientos_tmp a, ge_transacciones b
          WHERE a.cod_tra_padre = b.cod_transaccion
            AND a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND cod_persona = p_cod_persona
            AND fec_extracto = p_fec_extracto
            AND cod_extracto = p_cod_extracto
            AND nro_cuenta = p_cta
          ORDER BY fec_movimiento, fec_valor, hor_movimiento;
   
      v_nombre_pers VARCHAR2(220);
      v_nombre      VARCHAR2(356);
      v_linea       VARCHAR2(4000);
      v_oficina     VARCHAR2(100);
      v_cont        NUMBER := 0;
      v_existe      VARCHAR2(1) := NULL;
      v_seq         NUMBER DEFAULT 0;
      v_lugar       VARCHAR2(100);
   BEGIN
      FOR reg IN cab_clie LOOP
         v_lugar        := 'Inicio';
         v_fec_extracto := reg.fec_extracto;
      
         v_sal_anterior := reg.sal_anterior;
         v_lugar        := 'Nombre';
      
         BEGIN
            SELECT a.nom_completo
              INTO v_nombre_pers
              FROM ba_personas a
             WHERE a.cod_persona = reg.cod_persona;
         EXCEPTION
            WHEN no_data_found THEN
               v_error := 'No existe la persona: "' || reg.cod_persona || '".';
            WHEN OTHERS THEN
               v_error := 'Error al buscar la persona: "' || reg.cod_persona || '".';
         END;
         v_lugar := 'oficina';
         BEGIN
            SELECT b.cod_oficina || ' ' || b.descripcion
              INTO v_oficina
              FROM ba_oficinas b
             WHERE b.cod_oficina = reg.cod_oficina;
         EXCEPTION
            WHEN no_data_found THEN
               v_error := 'No existe la Oficina: "' || reg.cod_oficina || '".';
            WHEN OTHERS THEN
               v_error := 'Error al buscar la Oficina: "' || reg.cod_oficina || '".';
         END;
         --
         v_lugar  := 'nombre extracto';
         v_seq    := v_seq + 1;
         v_nombre := 'ex_' || lpad(p_cod_persona, 7, '0') || '_' || reg.nro_cuenta || '_' ||
                     reg.fre_extracto || '_' || '_' || v_seq || '.txt';
         v_lugar  := 'cabecera';
      
         --v_linea := 'Banco Bilbao Vizcaya Argentaria Paraguay S.A.' || v_separador || v_separador ||
        v_linea :=  v_nom_largo || v_separador || v_separador ||
                    v_separador || v_separador || v_separador ||
                    to_char(reg.fec_extracto, 'dd/mm/yyyy') || chr(13);
         v_file  := v_linea;
         v_linea := 'Extracto Mensual' || chr(13);
         v_file  := v_file || v_linea;
      
         v_linea := 'Sucursal: ' || v_oficina || '    Cuenta: ' || rpad(reg.nro_cuenta, 20, ' ') ||
                    chr(13);
         v_file  := v_file || v_linea;
         v_linea := 'Titular(es): ' || v_nombre_pers || chr(13);
         v_file  := v_file || v_linea;
      
         v_existe := 'S';
      
         v_linea := 'Dia' || v_separador || 'Concepto' || v_separador || 'Num.Doc.' || v_separador ||
                    'Debe' || v_separador || 'Haber' || v_separador || 'Saldo' || chr(13) ||
                    chr(10);
         v_file  := v_file || v_linea;
         --**
         it_mail.write_text(conn, v_file);
         v_linea := '';
         --**
         v_lugar := 'detalle';
         FOR reg1 IN det_clie(reg.nro_cuenta, reg.fec_extracto, reg.cod_extracto) LOOP
            v_cont := v_cont + 1;
            IF v_cont = 1 THEN
               --calcula el saldo
               v_saldo := nvl(v_sal_anterior, 0) - nvl(reg1.mto_debito, 0) +
                          nvl(reg1.mto_credito, 0);
               --
               v_linea := v_separador || 'Saldo Anterior' || v_separador || v_separador ||
                          v_separador || v_separador ||
                          REPLACE(TRIM(to_char(nvl(reg.sal_anterior, 0), '9999999999999999D99')),
                                  ',', '.') || chr(13) || chr(10);
               --**
               it_mail.write_text(conn, v_linea);
               v_linea := '';
               --**
            ELSE
               v_saldo := v_saldo - nvl(reg1.mto_debito, 0) + nvl(reg1.mto_credito, 0);
            END IF;
         
            v_lugar := 'detalle ' || v_cont;
            v_linea := v_linea || to_char(reg1.fec_movimiento, 'dd') || v_separador ||
                       REPLACE(reg1.descripcion, ',', '.') || v_separador ||
                       to_char(reg1.nro_documento) || v_separador ||
                       REPLACE(TRIM(to_char(reg1.mto_debito, '9999999999999D99')), ',', '.') ||
                       v_separador ||
                       REPLACE(TRIM(to_char(reg1.mto_credito, '9999999999999D99')), ',', '.') ||
                       v_separador ||
                       REPLACE(TRIM(to_char(nvl(v_saldo, 0), '9999999999999D99')), ',', '.') ||
                       chr(13) || chr(10);
            --**
            it_mail.write_text(conn, v_linea);
            v_linea := '';
            --**
         END LOOP;
         v_lugar := 'Pie de pagina';
         v_linea := v_separador || 'Saldo Actual' || v_separador || v_separador || v_separador ||
                    v_separador ||
                    REPLACE(TRIM(to_char(reg.sal_actual, '9999999999999999D99')), ',', '.') ||
                    chr(13);
         --**
         it_mail.write_text(conn, v_linea);
         --**
      END LOOP;
      
      --MENSAJE AL PIE CNFFGEXR-1 -- RE 15-01-2016
      v_linea := v_separador || fug_obt_pardinamico('MEN_EXT_INDIVIDUAL');--MENSAJE EXTRACTO INDIVIDUAL
      it_mail.write_text(conn, v_linea);
      
   EXCEPTION
      WHEN OTHERS THEN
         IF abs(SQLCODE) = 302000 THEN
            raise_application_error(-20000, 'Directorio Inválido.');
         ELSE
            raise_application_error(-20000, 'Error  en ' || v_lugar || ' - ' || SQLERRM);
         END IF;
   END;
   --
BEGIN
   IF ((p_cod_persona IS NULL AND p_nro_cuenta IS NULL) OR
      (p_cod_persona IS NULL AND p_nro_cuenta IS NOT NULL) OR
      (p_cod_persona IS NOT NULL AND p_nro_cuenta IS NULL)) THEN
      FOR k IN c_gen_ext LOOP
         IF nvl(p_formato_gral, 'N') = 'S' THEN
            pp_gen_mov_ascii_gral(k.cod_persona, k.nro_cuenta);
         ELSE
            pp_gen_mov_ascii(k.cod_persona, k.nro_cuenta); -- formato eminco
         END IF;
      END LOOP;
   ELSE
      --
      IF nvl(p_formato_gral, 'N') = 'S' THEN
         pp_gen_mov_ascii_gral(p_cod_persona, p_nro_cuenta);
      ELSE
         pp_gen_mov_ascii(p_cod_persona, p_nro_cuenta);
      END IF;
   END IF;
   RETURN '';
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al generar archivo ' || v_error || SQLERRM);
END;
/

