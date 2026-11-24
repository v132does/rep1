CREATE OR REPLACE FUNCTION IT.fut_val_can_tarjetas(p_nro_cuenta ta_cta_tarjetas.nro_cuenta%TYPE)
/*
|| Valida que se pueda cancelar la cuenta de una tarjeta
|| Retorna S-Si la cuenta esta activa
|| Retorna N-Si la cuenta No está activa
|| Para cancelar debe retornar N
*/ 
   RETURN VARCHAR2 IS
   CURSOR c_tarjetas IS
      SELECT nro_tarjeta
        FROM ta_tarjetas
       WHERE cod_estado = 6
         AND nro_cuenta = p_nro_cuenta;
   v_activo     VARCHAR2(1) := 'N';
   v_estado     ge_est_cuentas.estado%TYPE;
   v_solicitado VARCHAR2(1) := 'N';
BEGIN
   BEGIN
      SELECT estado
        INTO v_estado
        FROM ta_cta_tarjetas
       WHERE nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN no_data_found THEN
         v_activo := 'N';
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Al consultar Est.Cta:' || SQLERRM);
   END;
   IF v_estado = 'C' THEN
      v_activo := 'N';
   ELSE
      BEGIN
         SELECT 'S'
           INTO v_solicitado
           FROM ta_can_aut_tarjetas t
          WHERE t.fecha = pag_cal.fu_obt_fec_actual(5)
            AND t.nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            v_solicitado := 'N';
         WHEN too_many_rows THEN
            v_solicitado := 'S';
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al verificar cancelación de cuenta:' || SQLERRM);
      END;
      IF v_solicitado = 'S' THEN
         v_activo := 'N';
      ELSE
         FOR i IN c_tarjetas LOOP
            IF fut_val_blo_tarjetas(i.nro_tarjeta, pag_cal.fu_obt_fec_actual(5)) = 'S' THEN
               v_activo := 'N';
            ELSE
               v_activo := 'S';
               EXIT;
            END IF;
         END LOOP;
      END IF;
   END IF;
   RETURN v_activo;
END;
/

